// lib/services/survival_service.dart
//
// Handles:
//  • Loading & shuffling survival puzzle JSON files
//  • The infinite shuffle-and-recycle engine
//  • Local-only session state (no DB writes during run)
//  • Single write to Supabase when the run ends
//  • Personal-best tracking via SharedPreferences (offline-first)

import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Difficulty ────────────────────────────────────────────────────────────────

enum SurvivalDifficulty { easy, medium, hard }

extension SurvivalDifficultyExt on SurvivalDifficulty {
  String get name {
    switch (this) {
      case SurvivalDifficulty.easy:   return 'easy';
      case SurvivalDifficulty.medium: return 'medium';
      case SurvivalDifficulty.hard:   return 'hard';
    }
  }

  String get label {
    switch (this) {
      case SurvivalDifficulty.easy:   return 'EASY';
      case SurvivalDifficulty.medium: return 'MEDIUM';
      case SurvivalDifficulty.hard:   return 'HARD';
    }
  }

  String get assetPath {
    switch (this) {
      case SurvivalDifficulty.easy:   return 'assets/survival_puzzles_easy.json';
      case SurvivalDifficulty.medium: return 'assets/survival_puzzles_medium.json';
      case SurvivalDifficulty.hard:   return 'assets/survival_puzzles_hard.json';
    }
  }

  /// Base points per correct answer
  int get basePoints {
    switch (this) {
      case SurvivalDifficulty.easy:   return 100;
      case SurvivalDifficulty.medium: return 200;
      case SurvivalDifficulty.hard:   return 350;
    }
  }

  /// XP multiplier applied to final score conversion
  double get xpMultiplier {
    switch (this) {
      case SurvivalDifficulty.easy:   return 1.0;
      case SurvivalDifficulty.medium: return 1.5;
      case SurvivalDifficulty.hard:   return 2.0;
    }
  }

  String get prefsKey => 'survival_best_$name';
}

// ── Puzzle model (survival-specific, lighter than Campaign puzzle) ────────────

class SurvivalPuzzle {
  final String id;
  final String title;
  final List<String> tokens;
  final List<String> solution;
  final String category;

  const SurvivalPuzzle({
    required this.id,
    required this.title,
    required this.tokens,
    required this.solution,
    required this.category,
  });

  factory SurvivalPuzzle.fromJson(Map<String, dynamic> j) => SurvivalPuzzle(
    id:       j['id'] as String,
    title:    j['title'] as String,
    tokens:   List<String>.from(j['tokens']),
    solution: List<String>.from(j['solution']),
    category: j['category'] as String? ?? '',
  );
}

// ── Personal best (stored locally) ───────────────────────────────────────────

class SurvivalBest {
  final int score;
  final int streak;
  final int solved;
  final int timeSec;

  const SurvivalBest({
    required this.score,
    required this.streak,
    required this.solved,
    required this.timeSec,
  });

  Map<String, dynamic> toJson() => {
    'score':   score,
    'streak':  streak,
    'solved':  solved,
    'timeSec': timeSec,
  };

  factory SurvivalBest.fromJson(Map<String, dynamic> j) => SurvivalBest(
    score:   j['score']   as int,
    streak:  j['streak']  as int,
    solved:  j['solved']  as int,
    timeSec: j['timeSec'] as int,
  );

  SurvivalBest mergeWith(SurvivalRunResult run) => SurvivalBest(
    score:   max(score,   run.score),
    streak:  max(streak,  run.longestStreak),
    solved:  max(solved,  run.solved),
    timeSec: max(timeSec, run.timeSec),
  );
}

// ── Run result (passed to service at end of run) ──────────────────────────────

class SurvivalRunResult {
  final SurvivalDifficulty difficulty;
  final int score;
  final int longestStreak;
  final int solved;
  final int timeSec;
  final int xpEarned;
  final String rank; // S / A / B / C / D

  const SurvivalRunResult({
    required this.difficulty,
    required this.score,
    required this.longestStreak,
    required this.solved,
    required this.timeSec,
    required this.xpEarned,
    required this.rank,
  });
}

// ── Scoring helpers ───────────────────────────────────────────────────────────

class SurvivalScoring {
  /// Speed multiplier: 1.0x–2.0x based on solve time vs 30s window
  static double speedMultiplier(int solveSeconds) {
    // Full 2× if solved in ≤3s, scales linearly down to 1× at 30s+
    if (solveSeconds <= 3)  return 2.0;
    if (solveSeconds >= 30) return 1.0;
    return 1.0 + (27 - (solveSeconds - 3)) / 27.0;
  }

  /// Streak multiplier: 1.0x at streak 0, caps at 5.0x
  static double streakMultiplier(int streak) {
    // Every 5 correct answers add 0.4×, cap at 5.0×
    return min(5.0, 1.0 + (streak ~/ 5) * 0.4);
  }

  /// Points for one correct answer
  static int pointsFor({
    required SurvivalDifficulty difficulty,
    required int solveSeconds,
    required int currentStreak,
  }) {
    final base   = difficulty.basePoints;
    final speed  = speedMultiplier(solveSeconds);
    final streak = streakMultiplier(currentStreak);
    return (base * speed * streak).round();
  }

  /// Convert final score + stats into XP
  static int xpFor(SurvivalRunResult result) {
    // Base: 1 XP per 50 score points, + 2 XP per puzzle, + 1 XP per streak point
    final base = (result.score / 50).floor()
               + result.solved * 2
               + result.longestStreak;
    return (base * result.difficulty.xpMultiplier).round().clamp(1, 9999);
  }

  /// Rank from score
  static String rankFor(int score) {
    if (score >= 20000) return 'S';
    if (score >= 10000) return 'A';
    if (score >= 5000)  return 'B';
    if (score >= 2000)  return 'C';
    return 'D';
  }
}

// ── Infinite puzzle engine ────────────────────────────────────────────────────

class SurvivalEngine {
  final List<SurvivalPuzzle> _master;
  final _rng = Random();

  List<SurvivalPuzzle> _deck = [];
  int _cursor = 0;
  String? _lastPuzzleId;

  SurvivalEngine(List<SurvivalPuzzle> puzzles)
    : _master = List.from(puzzles) {
    _shuffle();
  }

  void _shuffle() {
    _deck = List.from(_master)..shuffle(_rng);

    // Prevent the first card of a new cycle being the same as the last played
    if (_lastPuzzleId != null && _deck.isNotEmpty && _deck.first.id == _lastPuzzleId) {
      final swap = _rng.nextInt(_deck.length - 1) + 1;
      final tmp = _deck[0];
      _deck[0] = _deck[swap];
      _deck[swap] = tmp;
    }
    _cursor = 0;
  }

  /// Returns the next puzzle, reshuffling the deck when exhausted.
  SurvivalPuzzle next() {
    if (_cursor >= _deck.length) _shuffle();
    final p = _deck[_cursor++];
    _lastPuzzleId = p.id;
    return p;
  }
}

// ── SurvivalService (public API) ──────────────────────────────────────────────

class SurvivalService {
  final _sb = Supabase.instance.client;

  // ── Load puzzles from JSON asset ─────────────────────────────────────────

  Future<List<SurvivalPuzzle>> loadPuzzles(SurvivalDifficulty diff) async {
    final raw  = await rootBundle.loadString(diff.assetPath);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['puzzles'] as List;
    return list.map((j) => SurvivalPuzzle.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ── Local personal best ───────────────────────────────────────────────────

  Future<SurvivalBest?> loadBest(SurvivalDifficulty diff) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(diff.prefsKey);
    if (raw == null) return null;
    return SurvivalBest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _saveBest(SurvivalDifficulty diff, SurvivalBest best) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(diff.prefsKey, jsonEncode(best.toJson()));
  }

  // ── Record completed run (ONE write) ─────────────────────────────────────
  //
  // Returns true if this run set a new personal best.

  Future<bool> recordRun(SurvivalRunResult result) async {
    // 1. Update local best
    final prev    = await loadBest(result.difficulty);
    final newBest = prev == null
        ? SurvivalBest(
            score:   result.score,
            streak:  result.longestStreak,
            solved:  result.solved,
            timeSec: result.timeSec,
          )
        : prev.mergeWith(result);
    await _saveBest(result.difficulty, newBest);
    final isNewBest = prev == null || result.score > prev.score;

    // 2. Also update local total XP (offline-first)
    final prefs    = await SharedPreferences.getInstance();
    final localXp  = prefs.getInt('local_xp') ?? 0;
    await prefs.setInt('local_xp', localXp + result.xpEarned);

    // 3. Single Supabase write if logged in
    final user = _sb.auth.currentUser;
    if (user != null) {
      try {
        await _sb.rpc('record_survival_run', params: {
          'p_uid':        user.id,
          'p_difficulty': result.difficulty.name,
          'p_score':      result.score,
          'p_streak':     result.longestStreak,
          'p_solved':     result.solved,
          'p_time_sec':   result.timeSec,
          'p_xp_earned':  result.xpEarned,
        });
      } catch (_) {
        // Offline — local data already saved, sync on next open
      }
    }

    return isNewBest;
  }
}