import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'package:code_shuffle/modals/modals.dart';
import 'sync_modal.dart';

class HomeScreen extends StatefulWidget {
  final List<PuzzleLevel> levels;
  final Map<String, PuzzleProgress> progress;
  final int xp;
  final String? username;
  final void Function(Map<String, PuzzleProgress> updated, int xpGained) onProgressUpdated;
  final void Function(String username) onSynced;
  final VoidCallback onSignedOut;
  final VoidCallback onTrainingTap;
  final VoidCallback? onSurvivalTap;
  final VoidCallback onReviewTap;

  const HomeScreen({
    super.key,
    required this.levels,
    required this.progress,
    required this.xp,
    required this.username,
    required this.onProgressUpdated,
    required this.onSynced,
    required this.onSignedOut,
    required this.onTrainingTap,
    this.onSurvivalTap,
    required this.onReviewTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  late AnimationController _ambientCtrl;
  late AnimationController _entranceCtrl;
  late Animation<double> _heroAnim;
  late Animation<double> _playAnim;

  bool get _isGuest => _sb.auth.currentUser == null;
  int get _level => (widget.xp / 100).floor() + 1;
  double get _xpProgress => (widget.xp % 100) / 100.0;

  int get _totalStars => widget.levels.fold(
      0, (s, l) => s + l.puzzles.fold(0, (ss, p) => ss + (widget.progress[p.id]?.stars ?? 0)));
  int get _maxStars => widget.levels.fold(0, (s, l) => s + l.puzzles.length * 3);
  int get _totalCompleted => widget.levels.fold(
      0, (s, l) => s + l.puzzles.where((p) => (widget.progress[p.id]?.stars ?? 0) > 0).length);
  int get _totalPuzzles => widget.levels.fold(0, (s, l) => s + l.puzzles.length);

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _heroAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    );
    _playAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _openSyncModal() {
    showSyncModal(context, progress: widget.progress, xp: widget.xp, onSynced: widget.onSynced);
  }

  void _onSurvivalTap() {
    if (widget.onSurvivalTap != null) {
      widget.onSurvivalTap!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Survival mode is coming soon 👀'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.grey.shade900,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(decoration: const BoxDecoration(gradient: kBgGradient)),
        CustomPaint(painter: _GridPainter(), size: Size.infinite),
        // Breathing radial glow
        AnimatedBuilder(
          animation: _ambientCtrl,
          builder: (_, __) {
            final t = _ambientCtrl.value;
            return Positioned(
              top: -80, left: -40, right: -40,
              child: Container(
                height: 480,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.2),
                    radius: 0.85,
                    colors: [
                      kPurpleMid.withOpacity(0.20 + 0.10 * t),
                      kPurpleDark.withOpacity(0.10 + 0.04 * t),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        SafeArea(
          child: Column(
            children: [
              _buildHUD(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildLogoHero(),
                    const SizedBox(height: 10),
                    _buildStatsStrip(),
                    const SizedBox(height: 28),
                    _buildModeButtons(),
                    const SizedBox(height: 14),
                    _buildReviewButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── HUD bar ────────────────────────────────────────────────────────────────

  Widget _buildHUD() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          _HudPill(icon: Icons.bolt_rounded, iconColor: kGold, label: '${widget.xp} XP'),
          const Spacer(),
          if (_isGuest)
            GestureDetector(
              onTap: _openSyncModal,
              child: _HudPill(icon: Icons.cloud_upload_outlined, iconColor: kPurpleLight, label: 'Sync'),
            )
          else ...[
            _HudPill(icon: Icons.person_rounded, iconColor: kPurpleLight, label: widget.username ?? 'Player'),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onSignedOut,
              child: const Text('Sign out', style: TextStyle(fontSize: 10, color: Colors.white24)),
            ),
          ],
          const SizedBox(width: 10),
          _LevelBadge(level: _level, xpProgress: _xpProgress),
        ],
      ),
    );
  }

  // ── Logo hero ──────────────────────────────────────────────────────────────

  Widget _buildLogoHero() {
    return AnimatedBuilder(
      animation: Listenable.merge([_ambientCtrl, _heroAnim]),
      builder: (_, __) {
        final t = _ambientCtrl.value;
        return Opacity(
          opacity: _heroAnim.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _heroAnim.value)),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: kPurpleMid.withOpacity(.4 + .15 * t), blurRadius: 60 + 18 * t, spreadRadius: 6),
                      BoxShadow(color: kGold.withOpacity(.14 + .08 * t), blurRadius: 36, spreadRadius: 3),
                    ],
                  ),
                  child: Image.asset('assets/icon_no_bg.png', width: 190, height: 190, fit: BoxFit.contain),
                ),
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: [kPurpleLight, kGoldLight, kPurpleLight],
                    stops: [0.0, .45 + .3 * t, 1.0],
                  ).createShader(b),
                  child: const Text(
                    'CODING SHUFFLE DUEL',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 3.5, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 3),
                Text('Master SQL. Beat the clock.',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(.3), letterSpacing: 1)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Aggregated stats strip ─────────────────────────────────────────────────

  Widget _buildStatsStrip() {
    final ratio = _maxStars > 0 ? _totalStars / _maxStars : 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: Row(
        children: [
          _MiniStat(label: 'PUZZLES', value: '$_totalCompleted/$_totalPuzzles', color: kPurpleLight),
          const SizedBox(width: 26),
          _MiniStat(label: 'STARS', value: '$_totalStars/$_maxStars', color: kGold),
          const Spacer(),
          SizedBox(
            width: 42, height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 3.5,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(kGold),
                ),
                Text('${(ratio * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Two side-by-side mode buttons ─────────────────────────────────────────

  Widget _buildModeButtons() {
    return AnimatedBuilder(
      animation: Listenable.merge([_ambientCtrl, _playAnim]),
      builder: (_, __) {
        final t = _ambientCtrl.value;
        return Transform.scale(
          scale: _playAnim.value.clamp(0.0, 1.0),
          child: Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'TRAINING',
                  icon: Icons.fitness_center_rounded,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFD060), Color(0xFFE6960A), Color(0xFFB36A00)],
                  ),
                  glowColor: kGold,
                  glowIntensity: t,
                  onTap: widget.onTrainingTap,
                  enabled: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ModeButton(
                  label: 'SURVIVAL',
                  icon: Icons.sports_kabaddi_rounded,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3DFF8F), Color(0xFF0CBF5E), Color(0xFF087A3B)],
                  ),
                  glowColor: const Color(0xFF0CBF5E),
                  glowIntensity: t,
                  badge: 'SOON',
                  onTap: _onSurvivalTap,
                  enabled: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Review SQL button (purple) ────────────────────────────────────────────

  Widget _buildReviewButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_ambientCtrl, _playAnim]),
      builder: (_, __) {
        final t = _ambientCtrl.value;
        return Transform.scale(
          scale: _playAnim.value.clamp(0.0, 1.0),
          child: GestureDetector(
            onTap: widget.onReviewTap,
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF7B2FFF),
                    const Color(0xFF9B6DFF),
                    const Color(0xFF7B2FFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF9B6DFF).withOpacity(.5), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2FFF).withOpacity(.38 + .15 * t),
                    blurRadius: 20 + 8 * t,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'REVIEW SQL STATEMENTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} // ← end of _HomeScreenState

// ─────────────────────────────────────────────────────────────────────────────
// Mode button widget — square with rounded corners, gradient fill
// ─────────────────────────────────────────────────────────────────────────────

class _ModeButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final Color glowColor;
  final double glowIntensity;
  final VoidCallback onTap;
  final bool enabled;
  final String? badge;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.glowIntensity,
    required this.onTap,
    required this.enabled,
    this.badge,
  });

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.72,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(.22), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withOpacity(.45 + .2 * widget.glowIntensity),
                  blurRadius: 24 + 10 * widget.glowIntensity,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: widget.glowColor.withOpacity(.15),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Soft inner highlight top
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withOpacity(.18), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // Content
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                            shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                          ),
                        ),
                        if (widget.badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.35),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              widget.badge!,
                              style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                // Lock overlay for disabled
                if (!widget.enabled)
                  Positioned(
                    top: 10, right: 10,
                    child: Icon(Icons.lock_rounded, size: 16, color: Colors.white.withOpacity(.5)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HudPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  const _HudPill({required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: iconColor)),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int level;
  final double xpProgress;
  const _LevelBadge({required this.level, required this.xpProgress});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 44, height: 44,
          child: CircularProgressIndicator(
            value: xpProgress,
            strokeWidth: 3,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(kGold),
          ),
        ),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            gradient: kGoldGradient,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: kGold.withOpacity(.4), blurRadius: 10)],
          ),
          child: Center(
            child: Text('L$level', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black)),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color.withOpacity(.6), letterSpacing: 1.5)),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.022)
      ..strokeWidth = 0.5;
    const spacing = 44.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}