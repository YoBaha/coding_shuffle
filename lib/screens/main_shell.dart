import 'dart:convert';
import 'package:code_shuffle/screens/review_sql_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'package:code_shuffle/modals/modals.dart';
import 'package:code_shuffle/services/progress_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'level_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MainShell — tab host with custom bottom nav
// ─────────────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _progressService = ProgressService();
  final _sb = Supabase.instance.client;

  // ── Shared state (lifted up so tabs stay in sync) ──────────────────────────
  List<PuzzleLevel> _levels = [];
  Map<String, PuzzleProgress> _progress = {};
  int _xp = 0;
  String? _username;
  bool _loading = true;

  int _tab = 0; // 0=home, 1=train(action), 2=profile, 3=settings

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final raw = await rootBundle.loadString('assets/sql_puzzles.json');
    final data = jsonDecode(raw);
    final levels =
        (data['levels'] as List).map((l) => PuzzleLevel.fromJson(l)).toList();

    final progress = await _progressService.loadLocalProgress();
    final xp = await _progressService.loadLocalXp();

    String? username;
    if (_sb.auth.currentUser != null) {
      try {
        final profile = await _progressService.fetchProfile();
        username = profile?['username'] as String?;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _levels = levels;
        _progress = progress;
        _xp = xp;
        _username = username;
        _loading = false;
      });
    }
  }

  void _onProgressUpdated(Map<String, PuzzleProgress> updated, int xpGained) {
    setState(() {
      _progress = updated;
      _xp += xpGained;
    });
    _progressService.saveLocalProgress(updated);
    _progressService.saveLocalXp(_xp);
  }

  // ── Train: show level picker sheet instead of navigating directly ──────────
  void _showTrainSheet() {
    if (_levels.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TrainSheet(
        levels: _levels,
        progress: _progress,
        onLevelSelected: (level) {
          Navigator.pop(context); // close sheet first
          _openLevel(level);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LevelScreen(
                level: level,
                progress: _progress,
                onProgressUpdated: _onProgressUpdated,
              ),
            ),
          );
        },
      ),
    );
  }
// ── Navigate to a level screen (used by Home cards and the Train sheet) ────
void _openLevel(PuzzleLevel level) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LevelScreen(
        level: level,
        progress: _progress,
        onProgressUpdated: _onProgressUpdated,
      ),
    ),
  );
}
  // ── Tab press handler ──────────────────────────────────────────────────────
  void _onTabTap(int index) {
    if (index == 1) {
      // Train is an action button, not a persistent tab
      _showTrainSheet();
      return;
    }
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: kBgDark,
        body: Center(child: CircularProgressIndicator(color: kPurpleLight)),
      );
    }

    // Map tab index → screen (train=1 is an action, skip it in IndexedStack)
    // Tab mapping: 0→home, 2→profile, 3→settings
    // IndexedStack uses: 0→home, 1→profile, 2→settings
    final stackIndex = _tab == 0 ? 0 : _tab == 2 ? 1 : 2;

    return Scaffold(
      backgroundColor: kBgDark,
      extendBody: true, // content goes under the nav bar cutout area
      body: IndexedStack(
        index: stackIndex,
        children: [
          // 0 — Home
HomeScreen(
  levels: _levels,
  progress: _progress,
  xp: _xp,
  username: _username,
  onProgressUpdated: _onProgressUpdated,
  onSynced: (u) => setState(() => _username = u),
  onSignedOut: () => setState(() => _username = null),
  onTrainingTap: _showTrainSheet,   // ← replaces onLevelTap
onReviewTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ReviewSqlScreen()),
  ),
),
          // 1 — Profile
          ProfileScreen(
            progress: _progress,
            xp: _xp,
            levels: _levels,
            username: _username,
            onSynced: (u) => setState(() => _username = u),
            onSignedOut: () => setState(() => _username = null),
          ),
          // 2 — Settings (placeholder)
          _SettingsPlaceholder(),
        ],
      ),
      bottomNavigationBar: _CSDBottomNav(
        currentIndex: _tab,
        onTap: _onTabTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Train bottom sheet — level picker
// ─────────────────────────────────────────────────────────────────────────────

class _TrainSheet extends StatelessWidget {
  final List<PuzzleLevel> levels;
  final Map<String, PuzzleProgress> progress;
  final void Function(PuzzleLevel) onLevelSelected;

  const _TrainSheet({
    required this.levels,
    required this.progress,
    required this.onLevelSelected,
  });

  int _completedFor(PuzzleLevel level) =>
      level.puzzles.where((p) => (progress[p.id]?.stars ?? 0) > 0).length;

  int _starsFor(PuzzleLevel level) =>
      level.puzzles.fold(0, (s, p) => s + (progress[p.id]?.stars ?? 0));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1530),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: kPurpleGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRAIN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Choose your difficulty',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Level cards
            ...levels.map((level) => _LevelPickerCard(
                  level: level,
                  completed: _completedFor(level),
                  stars: _starsFor(level),
                  onTap: () => onLevelSelected(level),
                )),
          ],
        ),
      ),
    );
  }
}

class _LevelPickerCard extends StatelessWidget {
  final PuzzleLevel level;
  final int completed;
  final int stars;
  final VoidCallback onTap;

  const _LevelPickerCard({
    required this.level,
    required this.completed,
    required this.stars,
    required this.onTap,
  });

  IconData get _icon {
    switch (level.id) {
      case 'beginner':
        return Icons.local_fire_department_rounded;
      case 'intermediate':
        return Icons.bolt_rounded;
      default:
        return Icons.military_tech_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxStars = level.puzzles.length * 3;
    final progress = level.puzzles.isNotEmpty ? completed / level.puzzles.length : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: kBgDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(.07)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              // Gradient accent bar
              Container(
                width: 4,
                height: 76,
                decoration:
                    BoxDecoration(gradient: levelGradient(level.id)),
              ),
              const SizedBox(width: 16),
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: levelGradient(level.id),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completed / ${level.puzzles.length} done · $stars/$maxStars ★',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
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
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.play_arrow_rounded,
                  color: kPurpleLight, size: 26),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: kBgGradient),
      child: const SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_rounded, size: 52, color: Colors.white12),
              SizedBox(height: 16),
              Text(
                'SETTINGS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: Colors.white24,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Coming soon',
                style: TextStyle(fontSize: 12, color: Colors.white24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom bottom nav bar — Marvel Snap–style with raised center arc
// ─────────────────────────────────────────────────────────────────────────────

class _CSDBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _CSDBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  static const double _navHeight = 68;
  static const double _arcRadius = 36; // half-width of center notch arc
  static const double _arcHeight = 22; // how high the arc rises

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _navHeight + bottomPadding,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // ── Painted bar background ──────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _NavBarPainter(
                arcRadius: _arcRadius + 16,
                arcHeight: _arcHeight,
                bottomPadding: bottomPadding,
              ),
            ),
          ),

          // ── Nav items row ───────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    active: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  // Left spacer for center button
                  const SizedBox(width: 72),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    active: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  _NavItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    active: currentIndex == 3,
                    onTap: () => onTap(3),
                  ),
                ],
              ),
            ),
          ),

          // ── Center raised TRAIN button ──────────────────────────────────
          Positioned(
            top: -(_arcHeight + 4),
            child: GestureDetector(
              onTap: () => onTap(1),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: kButtonGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kPurpleMid.withOpacity(.55),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: kPurpleLight.withOpacity(.2),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: kPurpleLight.withOpacity(.3), width: 1.5),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter — draws the nav bar shape with upward arc for center button
// ─────────────────────────────────────────────────────────────────────────────

class _NavBarPainter extends CustomPainter {
  final double arcRadius;
  final double arcHeight;
  final double bottomPadding;

  const _NavBarPainter({
    required this.arcRadius,
    required this.arcHeight,
    required this.bottomPadding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const topY = 0.0;

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E1838), Color(0xFF150F28)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = kPurpleMid.withOpacity(.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();

    // Start top-left
    path.moveTo(0, topY);

    // Line to where arc begins (left side of the notch)
    final arcLeft = cx - arcRadius;
    final arcRight = cx + arcRadius;

    path.lineTo(arcLeft - 12, topY);

    // Smooth cubic bezier up into the arc
    path.cubicTo(
      arcLeft - 4, topY,         // cp1
      arcLeft, topY - arcHeight, // cp2
      cx, topY - arcHeight,      // peak
    );
    path.cubicTo(
      arcRight, topY - arcHeight, // cp1
      arcRight + 4, topY,         // cp2
      arcRight + 12, topY,        // end
    );

    // Continue to right edge
    path.lineTo(size.width, topY);

    // Bottom edge (include system bottom padding)
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NavBarPainter old) =>
      old.arcRadius != arcRadius ||
      old.arcHeight != arcHeight ||
      old.bottomPadding != bottomPadding;
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual nav item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: active ? kPurpleMid.withOpacity(.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: active ? kPurpleLight : Colors.white38,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? kPurpleLight : Colors.white38,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}