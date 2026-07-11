// lib/screens/survival_difficulty_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/survival_service.dart';
import 'survival_game_screen.dart';

class SurvivalDifficultyScreen extends StatefulWidget {
  const SurvivalDifficultyScreen({super.key});

  @override
  State<SurvivalDifficultyScreen> createState() => _SurvivalDifficultyScreenState();
}

class _SurvivalDifficultyScreenState extends State<SurvivalDifficultyScreen>
    with TickerProviderStateMixin {

  late final AnimationController _ambientCtrl;
  late final AnimationController _entranceCtrl;

  SurvivalDifficulty? _loadingDiff;

  static const _cardData = [
    _DiffCardData(
      difficulty: SurvivalDifficulty.easy,
      title: 'EASY',
      subtitle: 'Beginner',
      description: 'SQL fundamentals — SELECT, WHERE, ORDER BY and more.',
      iconAsset: 'assets/images/easy_mode_icon.png',
      glowColor: Color(0xFF1E40AF),
      gradientColors: [Color(0xFF0F1F6E), Color(0xFF1532A8), Color(0xFF1D4ED8)],
      borderColor: Color(0xFF2563EB),
    ),
    _DiffCardData(
      difficulty: SurvivalDifficulty.medium,
      title: 'MEDIUM',
      subtitle: 'Intermediate',
      description: 'JOINs, GROUP BY, subqueries and aggregation.',
      iconAsset: 'assets/images/medium_mode_icon.png',
      glowColor: Color(0xFF14532D),
      gradientColors: [Color(0xFF052E16), Color(0xFF0F5A2E), Color(0xFF166534)],
      borderColor: Color(0xFF15803D),
    ),
    _DiffCardData(
      difficulty: SurvivalDifficulty.hard,
      title: 'HARD',
      subtitle: 'Advanced',
      description: 'Window functions, CTEs, correlated subqueries.',
      iconAsset: 'assets/images/hard_mode_icon.png',
      glowColor: Color(0xFF7F1D1D),
      gradientColors: [Color(0xFF450A0A), Color(0xFF7F1D1D), Color(0xFF991B1B)],
      borderColor: Color(0xFFB91C1C),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDifficulty(SurvivalDifficulty diff) async {
    if (_loadingDiff != null) return;
    setState(() => _loadingDiff = diff);

    final service = SurvivalService();
    final puzzles = await service.loadPuzzles(diff);
    final best    = await service.loadBest(diff);

    if (!mounted) return;
    setState(() => _loadingDiff = null);

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: SurvivalGameScreen(
            difficulty: diff,
            puzzles:    puzzles,
            personalBest: best,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: kBgGradient)),
          AnimatedBuilder(
            animation: _ambientCtrl,
            builder: (_, __) => Positioned(
              top: -60, left: -40, right: -40,
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.3),
                    radius: 0.9,
                    colors: [
                      kPurpleMid.withOpacity(0.18 + 0.08 * _ambientCtrl.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          _FloatingRunes(ctrl: _ambientCtrl),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                Expanded(child: _buildCards()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          // Wrap in Expanded so the title doesn't push past screen edge on small devices
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [kPurpleLight, kGoldLight],
                  ).createShader(b),
                  child: const Text(
                    '💀 SURVIVAL MODE',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Text(
                  'One mistake ends the run.',
                  style: TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    // SingleChildScrollView prevents the pill Row from overflowing on narrow screens
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: const [
            _StatPill(icon: '⚡', label: 'Infinite puzzles'),
            SizedBox(width: 8),
            _StatPill(icon: '🔥', label: 'Combo multiplier'),
            SizedBox(width: 8),
            _StatPill(icon: '🏆', label: 'XP rewards'),
          ],
        ),
      ),
    );
  }

  Widget _buildCards() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: _entranceCtrl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            children: [
              for (int i = 0; i < _cardData.length; i++) ...[
                Expanded(
                  child: _DifficultyCard(
                    data:       _cardData[i],
                    isLoading:  _loadingDiff == _cardData[i].difficulty,
                    isDisabled: _loadingDiff != null && _loadingDiff != _cardData[i].difficulty,
                    ambient:    _ambientCtrl,
                    onTap:      () => _selectDifficulty(_cardData[i].difficulty),
                  ),
                ),
                if (i < _cardData.length - 1) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Difficulty card ───────────────────────────────────────────────────────────

class _DiffCardData {
  final SurvivalDifficulty difficulty;
  final String title;
  final String subtitle;
  final String description;
  final String iconAsset;
  final Color glowColor;
  final List<Color> gradientColors;
  final Color borderColor;

  const _DiffCardData({
    required this.difficulty,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.iconAsset,
    required this.glowColor,
    required this.gradientColors,
    required this.borderColor,
  });
}

class _DifficultyCard extends StatefulWidget {
  final _DiffCardData data;
  final bool isLoading;
  final bool isDisabled;
  final AnimationController ambient;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.data,
    required this.isLoading,
    required this.isDisabled,
    required this.ambient,
    required this.onTap,
  });

  @override
  State<_DifficultyCard> createState() => _DifficultyCardState();
}

class _DifficultyCardState extends State<_DifficultyCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return AnimatedOpacity(
      opacity: widget.isDisabled ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: ()  => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedBuilder(
            animation: widget.ambient,
            builder: (_, __) {
              final t = widget.ambient.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      d.gradientColors[0],
                      d.gradientColors[1],
                      d.gradientColors[2].withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: d.borderColor.withOpacity(.45 + .15 * t), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: d.glowColor.withOpacity(.35 + .15 * t),
                      blurRadius: 22 + 8 * t,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Inner highlight
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white.withOpacity(.14), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    // Content — icon prominent on left, text on right
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Big icon — the first thing the eye catches
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: Image.asset(
                              d.iconAsset,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Text column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  d.title,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(.28),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    d.subtitle,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white70,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Flexible(
                                  child: Text(
                                    d.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(.80),
                                      height: 1.35,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Loading indicator only (no arrow)
                          if (widget.isLoading) ...[
                            const SizedBox(width: 12),
                            const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ],
      ),
    );
  }
}



// ── Floating background runes ─────────────────────────────────────────────────

class _FloatingRunes extends StatelessWidget {
  final AnimationController ctrl;
  const _FloatingRunes({required this.ctrl});

  static const _runes = ['SELECT', 'FROM', 'WHERE', 'JOIN', 'GROUP BY', 'ORDER BY', '{}', '<>', 'SQL'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        return Stack(
          children: List.generate(_runes.length, (i) {
            final offset = math.sin(ctrl.value * math.pi * 2 + i * 0.7) * 6;
            return Positioned(
              top:  80.0 + i * 88.0 + offset,
              left: i.isEven ? 8.0 : null,
              right: i.isEven ? null : 8.0,
              child: Text(
                _runes[i],
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(.045),
                  fontFamily: 'JetBrainsMono',
                  letterSpacing: 1,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}