import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'package:code_shuffle/modals/modals.dart';
import 'level_screen.dart';
import 'sync_modal.dart';
import 'package:code_shuffle/services/progress_service.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _progressService = ProgressService();
  final _sb = Supabase.instance.client;

  List<PuzzleLevel> _levels = [];
  Map<String, PuzzleProgress> _progress = {};
  int _xp = 0;
  String? _username; // null = guest
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Load puzzle definitions from bundled JSON
    final raw = await rootBundle.loadString('assets/sql_puzzles.json');
    final data = jsonDecode(raw);
    final levels = (data['levels'] as List)
        .map((l) => PuzzleLevel.fromJson(l))
        .toList();

    // Always load local progress first (offline-first)
    final progress = await _progressService.loadLocalProgress();
    final xp       = await _progressService.loadLocalXp();

    // If already signed in, try to get username silently
    String? username;
    if (_sb.auth.currentUser != null) {
      try {
        final profile = await _progressService.fetchProfile();
        username = profile?['username'] as String?;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _levels   = levels;
        _progress = progress;
        _xp       = xp;
        _username = username;
        _loading  = false;
      });
    }
  }

  // ── Computed helpers ───────────────────────────────────────────────────────

  bool get _isGuest => _sb.auth.currentUser == null;

  int get _level => (_xp / 100).floor() + 1;
  double get _xpProgress => (_xp % 100) / 100.0;

  int _totalStarsFor(PuzzleLevel level) =>
      level.puzzles.fold(0, (sum, p) => sum + (_progress[p.id]?.stars ?? 0));

  int _maxStarsFor(PuzzleLevel level) => level.puzzles.length * 3;

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _openLevel(PuzzleLevel level) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LevelScreen(
          level:    level,
          progress: _progress,
          onProgressUpdated: (updatedProgress, xpGained) {
            setState(() {
              _progress = updatedProgress;
              _xp      += xpGained;
            });
            _progressService.saveLocalProgress(updatedProgress);
            _progressService.saveLocalXp(_xp);
          },
        ),
      ),
    );
  }

  // ── Auth actions ───────────────────────────────────────────────────────────

  void _openSyncModal() {
    showSyncModal(
      context,
      progress: _progress,
      xp: _xp,
      onSynced: (username) {
        setState(() => _username = username);
      },
    );
  }

  Future<void> _signOut() async {
    await _sb.auth.signOut();
    setState(() => _username = null);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPurpleLight)),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildXpBar(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16, left: 4),
                      child: Text(
                        'SQL CHALLENGES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                    ..._levels.map((level) => _buildLevelCard(level)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // App title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => kPurpleGradient.createShader(b),
                  child: const Text(
                    'CODING SHUFFLE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
                ShaderMask(
                  shaderCallback: (b) => kGoldGradient.createShader(b),
                  child: const Text(
                    'DUEL',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right side: guest sync button  OR  username + sign out
          if (_isGuest)
            _buildSyncButton()
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_username != null)
                  Text(
                    _username!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kPurpleLight,
                    ),
                  ),
                GestureDetector(
                  onTap: _signOut,
                  child: const Text(
                    'Sign out',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ),
              ],
            ),

          const SizedBox(width: 8),

          // Level badge
GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProfileScreen(
        progress: _progress,
        xp: _xp,
        levels: _levels,
        username: _username,
        onSynced: (username) => setState(() => _username = username),
        onSignedOut: () => setState(() => _username = null),
      ),
    ),
  ),
  child: Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      gradient: kGoldGradient,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: kGold.withOpacity(.5), blurRadius: 12),
      ],
    ),
    child: Center(
      child: Text('L$_level', style: const TextStyle(
        fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black,
      )),
    ),
  ),
),
          
        ],
      ),
    );
  }

  Widget _buildSyncButton() {
    return GestureDetector(
      onTap: _openSyncModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: kPurpleMid.withOpacity(.6)),
          borderRadius: BorderRadius.circular(20),
          color: kPurpleMid.withOpacity(.12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.cloud_upload_outlined, color: kPurpleLight, size: 16),
            SizedBox(width: 6),
            Text(
              'Sync',
              style: TextStyle(
                color: kPurpleLight,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXpBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_xp XP',
                style: const TextStyle(
                  fontSize: 12,
                  color: kGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_level * 100} XP to level ${_level + 1}',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _xpProgress,
              minHeight: 6,
              backgroundColor: kBgCard,
              valueColor: const AlwaysStoppedAnimation<Color>(kGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(PuzzleLevel level) {
    final totalStars = _totalStarsFor(level);
    final maxStars   = _maxStarsFor(level);
    final completed  = level.puzzles
        .where((p) => (_progress[p.id]?.stars ?? 0) > 0)
        .length;

    return GestureDetector(
      onTap: () => _openLevel(level),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Gradient top bar
              Container(
                height: 4,
                decoration: BoxDecoration(gradient: levelGradient(level.id)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Level icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: levelGradient(level.id),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        level.id == 'beginner'
                            ? Icons.local_fire_department_rounded
                            : level.id == 'intermediate'
                                ? Icons.bolt_rounded
                                : Icons.military_tech_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$completed / ${level.puzzles.length} completed',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 8),
// Star progress
Wrap(
  spacing: 2,
  runSpacing: 2,
  children: List.generate(maxStars, (i) {
    return Icon(
      i < totalStars
          ? Icons.star_rounded
          : Icons.star_outline_rounded,
      color: i < totalStars ? kGold : Colors.white24,
      size: 14,
    );
  }),
),
                        ],
                      ),
                    ),
                    // XP badge
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: kGoldGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+${level.xpPerStar} XP/★',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white38,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Progress bar
              Container(
                height: 3,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white12,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: maxStars > 0 ? totalStars / maxStars : 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: levelGradient(level.id),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}