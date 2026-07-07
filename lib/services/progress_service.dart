import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:code_shuffle/modals/modals.dart';

class ProgressService {
  static const _progressKey = 'puzzle_progress';
  static const _xpKey       = 'local_xp';

  final _sb = Supabase.instance.client;

  // ── Local storage ──────────────────────────────────────────────────────────

  Future<Map<String, PuzzleProgress>> loadLocalProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_progressKey);
    if (raw == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(raw);
    return decoded.map((k, v) => MapEntry(k, PuzzleProgress.fromJson(v)));
  }

  Future<void> saveLocalProgress(Map<String, PuzzleProgress> progress) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(progress.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_progressKey, encoded);
  }

  Future<int> loadLocalXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_xpKey) ?? 0;
  }

  Future<void> saveLocalXp(int xp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_xpKey, xp);
  }

  // ── Record puzzle completion ───────────────────────────────────────────────

  /// Returns the new total XP after recording this result.
  Future<int> recordCompletion({
    required String puzzleId,
    required String levelId,
    required int stars,
    required int elapsedSeconds,
    required int xpPerStar,
    required Map<String, PuzzleProgress> progress,
  }) async {
    final existing = progress[puzzleId];
    final isImprovement = existing == null || stars > existing.stars;

    // Update local progress
    if (existing == null) {
      progress[puzzleId] = PuzzleProgress(
        puzzleId: puzzleId,
        stars:    stars,
        bestTime: elapsedSeconds,
      );
    } else {
      if (stars > existing.stars) existing.stars = stars;
      if (existing.bestTime == null || elapsedSeconds < existing.bestTime!) {
        existing.bestTime = elapsedSeconds;
      }
    }
    await saveLocalProgress(progress);

    // Only grant XP on improvement
    int xpGained = 0;
    if (isImprovement) {
      xpGained = stars * xpPerStar;
      final currentXp = await loadLocalXp();
      final newXp = currentXp + xpGained;
      await saveLocalXp(newXp);
    }

    // Sync to Supabase if logged in
    final user = _sb.auth.currentUser;
    if (user != null) {
      try {
        await _sb.from('puzzle_progress').upsert({
          'user_id':   user.id,
          'puzzle_id': puzzleId,
          'level_id':  levelId,
          'stars':     progress[puzzleId]!.stars,
          'best_time': progress[puzzleId]!.bestTime,
          'completed': true,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,puzzle_id');

        if (isImprovement && xpGained > 0) {
          // Increment XP on profile
          await _sb.rpc('increment_xp', params: {
            'uid':    user.id,
            'amount': xpGained,
          });
        }
      } catch (_) {
        // Silently fail — offline first
      }
    }

    return xpGained;
  }

  // ── Supabase profile ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchProfile() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _sb
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return data;
    } catch (_) {
      return null;
    }
  }
}