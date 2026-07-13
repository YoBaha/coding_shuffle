// lib/services/titles_service.dart
//
// Handles:
//  • Loading titles definitions from JSON asset
//  • Evaluating which titles the player has unlocked
//  • Persisting equipped title locally (SharedPreferences)
//  • Syncing equipped title to Supabase profiles table
//  • Tracking per-counter stats (survival runs, daily challenges, ads watched)

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:code_shuffle/services/survival_service.dart';
import 'package:code_shuffle/modals/modals.dart';

// ── Rarity ───────────────────────────────────────────────────────────────────

enum TitleRarity { common, uncommon, rare, epic }

extension TitleRarityExt on TitleRarity {
  static TitleRarity fromString(String s) {
    switch (s) {
      case 'uncommon': return TitleRarity.uncommon;
      case 'rare':     return TitleRarity.rare;
      case 'epic':     return TitleRarity.epic;
      default:         return TitleRarity.common;
    }
  }

  String get label {
    switch (this) {
      case TitleRarity.common:   return 'COMMON';
      case TitleRarity.uncommon: return 'UNCOMMON';
      case TitleRarity.rare:     return 'RARE';
      case TitleRarity.epic:     return 'EPIC';
    }
  }
}

// ── Title model ───────────────────────────────────────────────────────────────

class GameTitle {
  final String id;
  final String label;
  final String emoji;
  final String description;
  final TitleRarity rarity;
  final String conditionType;
  final int conditionValue;

  const GameTitle({
    required this.id,
    required this.label,
    required this.emoji,
    required this.description,
    required this.rarity,
    required this.conditionType,
    required this.conditionValue,
  });

  factory GameTitle.fromJson(Map<String, dynamic> j) => GameTitle(
    id:             j['id']              as String,
    label:          j['label']           as String,
    emoji:          j['emoji']           as String,
    description:    j['description']     as String,
    rarity:         TitleRarityExt.fromString(j['rarity'] as String? ?? 'common'),
    conditionType:  (j['condition'] as Map)['type']  as String,
    conditionValue: (j['condition'] as Map)['value'] as int,
  );

  /// Display text shown next to username e.g. "⚔️ First Blood"
  String get displayText => '$emoji $label';
}

// ── Player stats snapshot (passed in for evaluation) ─────────────────────────

class PlayerStats {
  final int totalXp;
  final int puzzlesCompleted;
  final int perfectPuzzles;
  final int? bestTimeSec;           // null = never solved any
  final Map<SurvivalDifficulty, SurvivalBest?> survivalBests;
  final int survivalRunsTotal;      // tracked separately in prefs
  final int dailyChallengesTotal;   // tracked separately in prefs
  final int adsWatched;             // tracked separately in prefs

  const PlayerStats({
    required this.totalXp,
    required this.puzzlesCompleted,
    required this.perfectPuzzles,
    required this.bestTimeSec,
    required this.survivalBests,
    required this.survivalRunsTotal,
    required this.dailyChallengesTotal,
    required this.adsWatched,
  });

  int get survivalBestStreak =>
      survivalBests.values.fold(0, (best, b) => b != null && b.streak > best ? b.streak : best);

  int get survivalBestScore =>
      survivalBests.values.fold(0, (best, b) => b != null && b.score > best ? b.score : best);
}

// ── TitlesService ─────────────────────────────────────────────────────────────

class TitlesService {
  static const _equippedKey        = 'equipped_title_id';
  static const _survivalRunsKey    = 'titles_survival_runs';
  static const _dailyChallengesKey = 'titles_daily_challenges';
  static const _adsWatchedKey      = 'titles_ads_watched';

  final _sb = Supabase.instance.client;

  List<GameTitle>? _cache;

  // ── Load definitions ──────────────────────────────────────────────────────

  Future<List<GameTitle>> loadAllTitles() async {
    if (_cache != null) return _cache!;
    final raw  = await rootBundle.loadString('assets/titles.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _cache     = (data['titles'] as List)
        .map((j) => GameTitle.fromJson(j as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  // ── Evaluation ────────────────────────────────────────────────────────────

  /// Returns IDs of all titles the player has currently unlocked.
  Future<Set<String>> getUnlockedIds(PlayerStats stats) async {
    final titles = await loadAllTitles();
    return titles
        .where((t) => _isUnlocked(t, stats))
        .map((t) => t.id)
        .toSet();
  }

  bool _isUnlocked(GameTitle t, PlayerStats s) {
    switch (t.conditionType) {
      case 'puzzles_completed':
        return s.puzzlesCompleted >= t.conditionValue;
      case 'perfect_puzzles':
        return s.perfectPuzzles >= t.conditionValue;
      case 'survival_runs':
        return s.survivalRunsTotal >= t.conditionValue;
      case 'survival_best_streak':
        return s.survivalBestStreak >= t.conditionValue;
      case 'survival_best_score':
        return s.survivalBestScore >= t.conditionValue;
      case 'daily_challenges':
        return s.dailyChallengesTotal >= t.conditionValue;
      case 'ads_watched':
        return s.adsWatched >= t.conditionValue;
      case 'total_xp':
        return s.totalXp >= t.conditionValue;
      case 'best_time_under':
        return s.bestTimeSec != null && s.bestTimeSec! <= t.conditionValue;
      default:
        return false;
    }
  }

  /// Check if a run/event just unlocked new titles. Returns newly unlocked ones.
  Future<List<GameTitle>> checkForNewUnlocks({
    required PlayerStats oldStats,
    required PlayerStats newStats,
  }) async {
    final titles    = await loadAllTitles();
    final wasLocked = titles.where((t) => !_isUnlocked(t, oldStats)).toSet();
    return wasLocked.where((t) => _isUnlocked(t, newStats)).toList();
  }

  // ── Equipped title ────────────────────────────────────────────────────────

  Future<String?> loadEquippedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_equippedKey);
  }

  /// Saves locally and syncs to Supabase if logged in.
  Future<void> equipTitle(String? titleId) async {
    final prefs = await SharedPreferences.getInstance();
    if (titleId == null) {
      await prefs.remove(_equippedKey);
    } else {
      await prefs.setString(_equippedKey, titleId);
    }

    // Sync to Supabase
    final user = _sb.auth.currentUser;
    if (user != null) {
      try {
        await _sb
            .from('profiles')
            .update({'equipped_title': titleId})
            .eq('id', user.id);
      } catch (_) {
        // Offline — will be in sync next time
      }
    }
  }

  // ── Counter tracking ──────────────────────────────────────────────────────

  Future<int> getSurvivalRunsTotal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_survivalRunsKey) ?? 0;
  }

  Future<void> incrementSurvivalRuns() async {
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getInt(_survivalRunsKey) ?? 0;
    await prefs.setInt(_survivalRunsKey, current + 1);
  }

  Future<int> getDailyChallengesTotal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyChallengesKey) ?? 0;
  }

  Future<void> incrementDailyChallenges() async {
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getInt(_dailyChallengesKey) ?? 0;
    await prefs.setInt(_dailyChallengesKey, current + 1);
  }

  Future<int> getAdsWatched() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_adsWatchedKey) ?? 0;
  }

  Future<void> incrementAdsWatched() async {
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getInt(_adsWatchedKey) ?? 0;
    await prefs.setInt(_adsWatchedKey, current + 1);
  }

  // ── Convenience: build PlayerStats from all local sources ────────────────

  Future<PlayerStats> buildStats({
    required int totalXp,
    required Map<String, PuzzleProgress> progress,
    required Map<SurvivalDifficulty, SurvivalBest?> survivalBests,
  }) async {
    final puzzlesCompleted = progress.values.where((p) => p.stars > 0).length;
    final perfectPuzzles   = progress.values.where((p) => p.stars == 3).length;
    final bestTimeSec      = progress.values
        .where((p) => p.bestTime != null)
        .map((p) => p.bestTime!)
        .fold<int?>(null, (best, t) => best == null || t < best ? t : best);

    return PlayerStats(
      totalXp:             totalXp,
      puzzlesCompleted:    puzzlesCompleted,
      perfectPuzzles:      perfectPuzzles,
      bestTimeSec:         bestTimeSec,
      survivalBests:       survivalBests,
      survivalRunsTotal:   await getSurvivalRunsTotal(),
      dailyChallengesTotal: await getDailyChallengesTotal(),
      adsWatched:          await getAdsWatched(),
    );
  }
}