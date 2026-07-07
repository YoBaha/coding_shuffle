import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'package:code_shuffle/modals/modals.dart';
import 'package:code_shuffle/services/progress_service.dart';
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
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;
  final _progressService = ProgressService();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  bool get _isGuest => _sb.auth.currentUser == null;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Computed stats ─────────────────────────────────────────────────────────

  int get _level => (widget.xp / 100).floor() + 1;
  double get _xpProgress => (widget.xp % 100) / 100.0;
  int get _xpToNextLevel => _level * 100 - widget.xp % 100;

  int get _totalPuzzles =>
      widget.levels.fold(0, (s, l) => s + l.puzzles.length);

  int get _completedPuzzles => widget.progress.values
      .where((p) => p.stars > 0)
      .length;

  int get _totalStars => widget.progress.values
      .fold(0, (s, p) => s + p.stars);

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

  String _formatTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  // ── Per-level stats ────────────────────────────────────────────────────────

  int _completedFor(PuzzleLevel level) => level.puzzles
      .where((p) => (widget.progress[p.id]?.stars ?? 0) > 0)
      .length;

  int _starsFor(PuzzleLevel level) => level.puzzles
      .fold(0, (s, p) => s + (widget.progress[p.id]?.stars ?? 0));

  // ── Actions ────────────────────────────────────────────────────────────────

  void _openSync() {
    showSyncModal(
      context,
      progress: widget.progress,
      xp: widget.xp,
      onSynced: (username) {
        widget.onSynced(username);
        setState(() {});
      },
    );
  }

  Future<void> _signOut() async {
    await _sb.auth.signOut();
    widget.onSignedOut();
    if (mounted) Navigator.of(context).pop();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBgGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      _buildHeroCard(),
                      const SizedBox(height: 20),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      _buildLevelBreakdown(),
                      const SizedBox(height: 20),
                      if (_isGuest) _buildGuestCta(),
                      if (!_isGuest) _buildSignOutButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'PROFILE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero card: avatar + level + XP bar ────────────────────────────────────

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: kPurpleMid.withOpacity(.15),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              _buildAvatar(),
              const SizedBox(width: 20),
              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isGuest
                          ? 'Guest Player'
                          : (widget.username ?? 'Player'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: kGoldGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'LEVEL $_level',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isGuest)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.07),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Text(
                              'GUEST',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white38,
                                letterSpacing: 1,
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

          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 20),

          // XP progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.xp} XP',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kGold,
                ),
              ),
              Text(
                '$_xpToNextLevel XP to level ${_level + 1}',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _xpProgress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(kGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final initials = _isGuest
        ? '?'
        : (widget.username?.isNotEmpty == true
            ? widget.username![0].toUpperCase()
            : '?');
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: kPurpleGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: kPurpleMid.withOpacity(.5), blurRadius: 16),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Stats 2×2 grid ────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('STATISTICS'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline_rounded,
                iconColor: kGreen,
                value: '$_completedPuzzles / $_totalPuzzles',
                label: 'Completed',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.star_rounded,
                iconColor: kGold,
                value: '$_totalStars / $_maxStars',
                label: 'Stars',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.workspace_premium_rounded,
                iconColor: kPurpleLight,
                value: '$_perfectPuzzles',
                label: '3-Star Clears',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.timer_outlined,
                iconColor: kCyan,
                value: _bestTime != null ? _formatTime(_bestTime!) : '—',
                label: 'Best Time',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Per-level breakdown ────────────────────────────────────────────────────

  Widget _buildLevelBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('PROGRESS BY LEVEL'),
        const SizedBox(height: 12),
        ...widget.levels.map((level) => _buildLevelRow(level)),
      ],
    );
  }

  Widget _buildLevelRow(PuzzleLevel level) {
    final completed = _completedFor(level);
    final total     = level.puzzles.length;
    final stars     = _starsFor(level);
    final maxStars  = total * 3;
    final progress  = total > 0 ? completed / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Coloured dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  gradient: levelGradient(level.id),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  level.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              // Stars
              Row(
                children: [
                  Icon(Icons.star_rounded, color: kGold, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$stars / $maxStars',
                    style: const TextStyle(
                      fontSize: 12,
                      color: kGold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Text(
                '$completed/$total',
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                level.id == 'beginner'
                    ? kGreen
                    : level.id == 'intermediate'
                        ? kBlue
                        : kAdvPurple,
              ),
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
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a free account to back up your XP\nand stars across devices.',
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
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
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white38,
        letterSpacing: 2.5,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}