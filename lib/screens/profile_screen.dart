// lib/screens/profile_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'package:code_shuffle/modals/modals.dart';
import 'package:code_shuffle/services/progress_service.dart';
import 'package:code_shuffle/services/survival_service.dart';
import 'sync_modal.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, PuzzleProgress> progress;
  final int xp;
  final List<PuzzleLevel> levels;
  final String? username;
  final void Function(String username) onSynced;
  final VoidCallback onSignedOut;

  const ProfileScreen({
    super.key,
    required this.progress,
    required this.xp,
    required this.levels,
    required this.username,
    required this.onSynced,
    required this.onSignedOut,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _sb = Supabase.instance.client;
  final _survivalService = SurvivalService();
  
  Map<SurvivalDifficulty, SurvivalBest?> _survivalBests = {};
  bool _loadingSurvival = true;

  late AnimationController _entranceCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _xpBarCtrl;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _xpAnim;

  bool get _isGuest => _sb.auth.currentUser == null;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _xpBarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _xpAnim = CurvedAnimation(parent: _xpBarCtrl, curve: Curves.easeOutCubic);

    _entranceCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _xpBarCtrl.forward();
    });
    
    // Load survival stats
    _loadSurvivalBests();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _xpBarCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSurvivalBests() async {
    setState(() => _loadingSurvival = true);
    final result = <SurvivalDifficulty, SurvivalBest?>{};
    for (final diff in SurvivalDifficulty.values) {
      final best = await _survivalService.loadBest(diff);
      result[diff] = best;
    }
    if (mounted) {
      setState(() {
        _survivalBests = result;
        _loadingSurvival = false;
      });
    }
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  int get _level => (widget.xp / 100).floor() + 1;
  double get _xpProgress => (widget.xp % 100) / 100.0;
  int get _xpToNextLevel => _level * 100 - widget.xp % 100;

  int get _totalPuzzles =>
      widget.levels.fold(0, (s, l) => s + l.puzzles.length);
  int get _completedPuzzles =>
      widget.progress.values.where((p) => p.stars > 0).length;
  int get _totalStars =>
      widget.progress.values.fold(0, (s, p) => s + p.stars);
  int get _maxStars => _totalPuzzles * 3;
  int get _perfectPuzzles =>
      widget.progress.values.where((p) => p.stars == 3).length;

  int? get _bestTime {
    final times = widget.progress.values
        .where((p) => p.bestTime != null)
        .map((p) => p.bestTime!)
        .toList();
    if (times.isEmpty) return null;
    return times.reduce((a, b) => a < b ? a : b);
  }

  String _formatTime(int s) =>
      s < 60 ? '${s}s' : '${s ~/ 60}m ${s % 60}s';

  int _completedFor(PuzzleLevel l) =>
      l.puzzles.where((p) => (widget.progress[p.id]?.stars ?? 0) > 0).length;
  int _starsFor(PuzzleLevel l) =>
      l.puzzles.fold(0, (s, p) => s + (widget.progress[p.id]?.stars ?? 0));

  // ── Actions ────────────────────────────────────────────────────────────────

  void _openSync() {
    showSyncModal(
      context,
      progress: widget.progress,
      xp: widget.xp,
      onSynced: (u) { widget.onSynced(u); setState(() {}); },
    );
  }

  Future<void> _signOut() async {
    await _sb.auth.signOut();
    widget.onSignedOut();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Deep background
        Container(decoration: const BoxDecoration(gradient: kBgGradient)),
        // Radial ambient glow behind avatar area
        Positioned(
          top: -60,
          left: -60,
          right: -60,
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 0.9,
                colors: [
                  kPurpleMid.withOpacity(.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Content
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildTopBar()),
                  SliverToBoxAdapter(child: _buildHeroSection()),
                  SliverToBoxAdapter(child: _buildStatsSection()),
                  SliverToBoxAdapter(child: _buildSurvivalStatsSection()),
                  SliverToBoxAdapter(child: _buildLevelSection()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      child: _isGuest ? _buildGuestCta() : _buildSignOutButton(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          // "PROFILE" eyebrow label with accent line
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: kPurpleGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'PROFILE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          // Rank badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: kGold.withOpacity(.4)),
              borderRadius: BorderRadius.circular(20),
              color: kGold.withOpacity(.08),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech_rounded, color: kGold, size: 14),
                const SizedBox(width: 4),
                Text(
                  'RANK ${_completedPuzzles > 15 ? "S" : _completedPuzzles > 8 ? "A" : _completedPuzzles > 3 ? "B" : "C"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kGold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero section ───────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Pulsing hexagon avatar
          _buildHexAvatar(),
          const SizedBox(width: 20),
          // Name + XP info
          Expanded(child: _buildPlayerInfo()),
        ],
      ),
    );
  }

  Widget _buildHexAvatar() {
    final initials = _isGuest
        ? '?'
        : (widget.username?.isNotEmpty == true
            ? widget.username![0].toUpperCase()
            : 'P');

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kPurpleMid.withOpacity(.5 * _pulseAnim.value),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
            // Hex clip shape
            ClipPath(
              clipper: _HexClipper(),
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(gradient: kPurpleGradient),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Level badge at bottom-right
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  gradient: kGoldGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: kGold.withOpacity(.5), blurRadius: 8),
                  ],
                ),
                child: Text(
                  'L$_level',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlayerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isGuest ? 'Guest Player' : (widget.username ?? 'Player'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        if (_isGuest)
          const Text(
            'Playing offline',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          )
        else
          Text(
            '${widget.xp} XP total',
            style: const TextStyle(
              fontSize: 12,
              color: kPurpleLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 14),

        // XP bar — game-style energy bar
        _buildXpBar(),
      ],
    );
  }

  Widget _buildXpBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LEVEL $_level',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white54,
                letterSpacing: 2,
              ),
            ),
            Text(
              '${widget.xp % 100}/100 XP',
              style: const TextStyle(
                fontSize: 10,
                color: kGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Segmented energy bar
        AnimatedBuilder(
          animation: _xpAnim,
          builder: (_, __) {
            final fill = _xpProgress * _xpAnim.value;
            return Stack(
              children: [
                // Track
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white.withOpacity(.08)),
                  ),
                ),
                // Fill
                FractionallySizedBox(
                  widthFactor: fill.clamp(0.0, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kGold, kGoldLight, kGold],
                      ),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: kGold.withOpacity(.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          '$_xpToNextLevel XP to level ${_level + 1}',
          style: const TextStyle(fontSize: 10, color: Colors.white24),
        ),
      ],
    );
  }

  // ── Stats section ──────────────────────────────────────────────────────────

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('STATISTICS'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatPanel(
                  value: '$_completedPuzzles/$_totalPuzzles',
                  label: 'Puzzles',
                  icon: Icons.check_circle_outline_rounded,
                  accentColor: kGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPanel(
                  value: '$_totalStars/$_maxStars',
                  label: 'Stars',
                  icon: Icons.star_rounded,
                  accentColor: kGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatPanel(
                  value: '$_perfectPuzzles',
                  label: 'Perfect',
                  icon: Icons.emoji_events_rounded,
                  accentColor: kPurpleLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPanel(
                  value: _bestTime != null ? _formatTime(_bestTime!) : '—',
                  label: 'Best Time',
                  icon: Icons.timer_rounded,
                  accentColor: kCyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Survival Stats section ──────────────────────────────────────────────────

  Widget _buildSurvivalStatsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('SURVIVAL BEST SCORES'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kBgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(.05)),
            ),
            child: _loadingSurvival
                ? const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Column(
                    children: SurvivalDifficulty.values.map((diff) {
                      final best = _survivalBests[diff];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _diffColor(diff).withOpacity(.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                diff.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _diffColor(diff),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: best != null
                                  ? Row(
                                      children: [
                                        Text(
                                          '${best.score} pts',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(.05),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '🔥${best.streak}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white38,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(.05),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${best.solved}✓',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white38,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTime(best.timeSec),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      '—',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white24,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Color _diffColor(SurvivalDifficulty diff) {
    switch (diff) {
      case SurvivalDifficulty.easy:
        return const Color(0xFF3B82F6);
      case SurvivalDifficulty.medium:
        return const Color(0xFF22C55E);
      case SurvivalDifficulty.hard:
        return const Color(0xFFEF4444);
    }
  }

  // ── Level breakdown ────────────────────────────────────────────────────────

  Widget _buildLevelSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('MISSIONS'),
          const SizedBox(height: 12),
          ...widget.levels.map((l) => _buildMissionRow(l)),
        ],
      ),
    );
  }

  Widget _buildMissionRow(PuzzleLevel level) {
    final completed = _completedFor(level);
    final total = level.puzzles.length;
    final stars = _starsFor(level);
    final maxStars = total * 3;
    final ratio = total > 0 ? completed / total : 0.0;

    final Color accent = level.id == 'beginner'
        ? kGreen
        : level.id == 'intermediate'
            ? kBlue
            : kAdvPurple;

    final IconData icon = level.id == 'beginner'
        ? Icons.local_fire_department_rounded
        : level.id == 'intermediate'
            ? Icons.bolt_rounded
            : Icons.military_tech_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(.15)),
      ),
      child: Row(
        children: [
          // Icon in colored circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: levelGradient(level.id),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          // Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      level.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: kGold, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          '$stars/$maxStars',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$completed/$total',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white38),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.06),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: levelGradient(level.id),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Guest CTA ──────────────────────────────────────────────────────────────

  Widget _buildGuestCta() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPurpleDark.withOpacity(.6), kPurpleMid.withOpacity(.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPurpleMid.withOpacity(.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_outlined, color: kPurpleLight, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Save your progress',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a free account to sync XP & stars across devices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.5),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _openSync,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                gradient: kButtonGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: kPurpleMid.withOpacity(.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'SYNC & CREATE ACCOUNT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Widget _buildSignOutButton() {
    return GestureDetector(
      onTap: _signOut,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(.2)),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'SIGN OUT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Row(
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: kPurpleGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white38,
              letterSpacing: 3,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hex clipper — gives the avatar a hexagonal shape
// ─────────────────────────────────────────────────────────────────────────────

class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(cx, cy);

    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_HexClipper _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatPanel — replaces _StatCard, no fixed aspect ratio overflow
// ─────────────────────────────────────────────────────────────────────────────

class _StatPanel extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color accentColor;

  const _StatPanel({
    required this.value,
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: accentColor.withOpacity(.7),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}