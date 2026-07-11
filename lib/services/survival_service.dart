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
      case SurvivalDifficulty.medium: return 'assets/survival_puzzles_medium1.json';
      case SurvivalDifficulty.hard:   return 'assets/survival_puzzles_hard1.json';
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

  /// Whether this difficulty uses chunk-based gameplay
  bool get usesChunks => this == SurvivalDifficulty.medium || this == SurvivalDifficulty.hard;
}

// ── Chunk model ───────────────────────────────────────────────────────────────

class SurvivalChunk {
  final String id;
  final String label;
  final int rangeStart; // inclusive index into solution[]
  final int rangeEnd;   // inclusive index into solution[]
  final int complexity; // 1–5

  const SurvivalChunk({
    required this.id,
    required this.label,
    required this.rangeStart,
    required this.rangeEnd,
    required this.complexity,
  });

  factory SurvivalChunk.fromJson(Map<String, dynamic> j) => SurvivalChunk(
    id:         j['id']         as String,
    label:      j['label']      as String,
    rangeStart: (j['range'] as List)[0] as int,
    rangeEnd:   (j['range'] as List)[1] as int,
    complexity: j['complexity'] as int? ?? 1,
  );

  int get tokenCount => rangeEnd - rangeStart + 1;
}

// ── Puzzle model (survival-specific, lighter than Campaign puzzle) ────────────

class SurvivalPuzzle {
  final String id;
  final String title;
  final List<String> tokens;
  final List<String> solution;
  final String category;
  /// Non-null only for medium/hard puzzles that carry chunk metadata.
  final List<SurvivalChunk>? chunks;

  const SurvivalPuzzle({
    required this.id,
    required this.title,
    required this.tokens,
    required this.solution,
    required this.category,
    this.chunks,
  });

  factory SurvivalPuzzle.fromJson(Map<String, dynamic> j) {
    List<SurvivalChunk>? chunks;
    if (j['chunks'] != null) {
      chunks = (j['chunks'] as List)
          .map((c) => SurvivalChunk.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    return SurvivalPuzzle(
      id:       j['id']       as String,
      title:    j['title']    as String,
      tokens:   List<String>.from(j['tokens']),
      solution: List<String>.from(j['solution']),
      category: j['category'] as String? ?? '',
      chunks:   chunks,
    );
  }

  /// Returns the solution tokens that belong to a given chunk.
  List<String> tokensForChunk(SurvivalChunk chunk) =>
      solution.sublist(chunk.rangeStart, chunk.rangeEnd + 1);
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
    if (solveSeconds <= 3)  return 2.0;
    if (solveSeconds >= 30) return 1.0;
    return 1.0 + (27 - (solveSeconds - 3)) / 27.0;
  }

  /// Streak multiplier: 1.0x at streak 0, caps at 5.0x
  static double streakMultiplier(int streak) {
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
    if (_lastPuzzleId != null && _deck.isNotEmpty && _deck.first.id == _lastPuzzleId) {
      final swap = _rng.nextInt(_deck.length - 1) + 1;
      final tmp  = _deck[0];
      _deck[0]   = _deck[swap];
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

  Future<List<SurvivalPuzzle>> loadPuzzles(SurvivalDifficulty diff) async {
    final raw  = await rootBundle.loadString(diff.assetPath);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['puzzles'] as List;
    return list.map((j) => SurvivalPuzzle.fromJson(j as Map<String, dynamic>)).toList();
  }

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

  Future<bool> recordRun(SurvivalRunResult result) async {
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

    final prefs   = await SharedPreferences.getInstance();
    final localXp = prefs.getInt('local_xp') ?? 0;
    await prefs.setInt('local_xp', localXp + result.xpEarned);

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