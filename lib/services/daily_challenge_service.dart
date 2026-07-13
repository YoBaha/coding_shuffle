// lib/services/daily_challenge_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// A single daily-challenge puzzle (mirrors the JSON structure).
class DailyPuzzle {
  final int day;
  final String difficulty;
  final String title;
  final List<String> tokens;
  final List<String> solution;
  final String explanation;
  final String category;

  const DailyPuzzle({
    required this.day,
    required this.difficulty,
    required this.title,
    required this.tokens,
    required this.solution,
    required this.explanation,
    required this.category,
  });

  factory DailyPuzzle.fromJson(Map<String, dynamic> j) => DailyPuzzle(
        day: j['day'] as int,
        difficulty: (j['difficulty'] as String?) ?? 'Unknown',
        title: (j['title'] as String?) ?? 'Daily Challenge',
        tokens: List<String>.from(j['tokens'] as List),
        solution: List<String>.from(j['solution'] as List),
        explanation: (j['explanation'] as String?) ?? '',
        category: (j['category'] as String?) ?? '',
      );
}

class DailyChallengeService {
  static const _completedKey = 'daily_challenge_completed_date';
  static const _lastLoginCheckKey = 'last_login_check_date';
  
  final _sb = Supabase.instance.client;

  // ── Load today's puzzle ──────────────────────────────────────────────────

  /// Loads the JSON, picks a puzzle based on the day-of-year (cycled),
  /// ignores the `date` field entirely.
  Future<DailyPuzzle> loadTodaysPuzzle() async {
    final raw = await rootBundle.loadString('assets/daily_chall_puzzles.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final puzzles = (data['puzzles'] as List)
        .map((e) => DailyPuzzle.fromJson(e as Map<String, dynamic>))
        .toList();

    // Use day-of-year (1-based) cycled over however many puzzles exist.
    final now = DateTime.now();
    final dayOfYear = _dayOfYear(now); // 1..365
    final index = (dayOfYear - 1) % puzzles.length;
    return puzzles[index];
  }

  // ── Completion tracking ───────────────────────────────────────────────────

  /// Returns the date string ('yyyy-MM-dd') when the challenge was last
  /// completed, or null if never completed today.
  Future<String?> loadCompletedDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_completedKey);
  }

  /// Marks today's challenge as done.
  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_completedKey, _todayString());
  }

  /// True if the user already completed today's challenge.
  Future<bool> isCompletedToday() async {
    final stored = await loadCompletedDate();
    return stored == _todayString();
  }

  // ── Login streak tracking ──────────────────────────────────────────────────

  /// Update login streak in Supabase (only if logged in)
  Future<void> updateLoginStreak() async {
    final user = _sb.auth.currentUser;
    if (user == null) return;
    
    try {
      await _sb.rpc('update_login_streak', params: {'p_uid': user.id});
    } catch (e) {
      // Silent fail — we'll retry next time
      print('Failed to update login streak: $e');
    }
  }

  /// Check and update login streak if today hasn't been recorded yet
  /// Call this when the app starts or user logs in
  Future<void> checkAndUpdateLoginStreak() async {
    final user = _sb.auth.currentUser;
    if (user == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(_lastLoginCheckKey);
    final today = _todayString();
    
    if (lastCheck != today) {
      await updateLoginStreak();
      await prefs.setString(_lastLoginCheckKey, today);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _dayOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1;
  }
}