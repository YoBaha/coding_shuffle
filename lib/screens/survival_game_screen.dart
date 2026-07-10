// lib/screens/survival_game_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../theme.dart';
import '../services/survival_service.dart';
import '../services/progress_service.dart';

// ── Difficulty theme data ──────────────────────────────────────────────────────

class _DiffTheme {
  final Color primary;
  final Color glow;
  final Color tokenBorder;
  final List<Color> bgAccent;
  final String moodLabel;

  const _DiffTheme({
    required this.primary,
    required this.glow,
    required this.tokenBorder,
    required this.bgAccent,
    required this.moodLabel,
  });

  static _DiffTheme of(SurvivalDifficulty d) {
    switch (d) {
      case SurvivalDifficulty.easy:
        return const _DiffTheme(
          primary: Color(0xFF3B82F6),
          glow: Color(0xFF60A5FA),
          tokenBorder: Color(0xFF3B82F6),
          bgAccent: [Color(0x221D4ED8), Color(0x003B82F6)],
          moodLabel: '💚 EASY',
        );
      case SurvivalDifficulty.medium:
        return const _DiffTheme(
          primary: Color(0xFF22C55E),
          glow: Color(0xFF4ADE80),
          tokenBorder: Color(0xFF22C55E),
          bgAccent: [Color(0x2215803D), Color(0x0022C55E)],
          moodLabel: '🟠 MEDIUM',
        );
      case SurvivalDifficulty.hard:
        return const _DiffTheme(
          primary: Color(0xFFEF4444),
          glow: Color(0xFFF87171),
          tokenBorder: Color(0xFFEF4444),
          bgAccent: [Color(0x337F1D1D), Color(0x00EF4444)],
          moodLabel: '💀 HARD',
        );
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SurvivalGameScreen extends StatefulWidget {
  final SurvivalDifficulty difficulty;
  final List<SurvivalPuzzle> puzzles;
  final SurvivalBest? personalBest;

  const SurvivalGameScreen({
    super.key,
    required this.difficulty,
    required this.puzzles,
    this.personalBest,
  });

  @override
  State<SurvivalGameScreen> createState() => _SurvivalGameScreenState();
}

class _SurvivalGameScreenState extends State<SurvivalGameScreen>
    with TickerProviderStateMixin {
  late SurvivalEngine _engine;
  late SurvivalPuzzle _currentPuzzle;
  late _DiffTheme _theme;

  List<String> _bank = [];
  List<String?> _slots = [];
  bool _submitted = false;
  bool _correct = false;
  bool _gameOver = false;

  int _score = 0;
  int _streak = 0;
  int _longestStreak = 0;
  int _solved = 0;
  int _comboMultiplier = 1;

  late Stopwatch _stopwatch;
  late Timer _ticker;
  int _elapsed = 0;
  int _puzzleStartTime = 0;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _resultCtrl;
  late Animation<double> _resultFade;
  late AnimationController _scorePopCtrl;
  late Animation<double> _scorePopScale;
  late AnimationController _correctFlashCtrl;

  int _totalXpEarned = 0;
  final _progressService = ProgressService();

  @override
  void initState() {
    super.initState();
    _theme = _DiffTheme.of(widget.difficulty);
    _engine = SurvivalEngine(widget.puzzles);
    _loadNextPuzzle();
    _initAnimations();
    _startTimer();
  }

  void _loadNextPuzzle() {
    _currentPuzzle = _engine.next();
    _bank = List<String>.from(_currentPuzzle.tokens)..shuffle();
    _slots = List<String?>.filled(_currentPuzzle.solution.length, null);
    _submitted = false;
    _correct = false;
    _puzzleStartTime = _elapsed;
    _comboMultiplier = 1;
  }

  void _initAnimations() {
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _resultFade = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);

    _scorePopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scorePopScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scorePopCtrl, curve: Curves.elasticOut),
    );

    _correctFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _startTimer() {
    _stopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_gameOver) {
        setState(() => _elapsed = _stopwatch.elapsed.inSeconds);
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _stopwatch.stop();
    _shakeCtrl.dispose();
    _resultCtrl.dispose();
    _scorePopCtrl.dispose();
    _correctFlashCtrl.dispose();
    super.dispose();
  }

  // ── Token interactions ─────────────────────────────────────────────────────

  void _placeToken(String token) {
    if (_submitted || _gameOver) return;
    final idx = _slots.indexOf(null);
    if (idx == -1) return;
    HapticFeedback.selectionClick();
    setState(() {
      _slots[idx] = token;
      _bank.remove(token);
    });
  }

  void _removeToken(int slotIndex) {
    if (_submitted || _gameOver) return;
    final token = _slots[slotIndex];
    if (token == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _bank.add(token);
      _slots[slotIndex] = null;
    });
  }

  void _dropOnSlot(int slotIndex, String token) {
    if (_submitted || _gameOver) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_slots[slotIndex] != null) {
        _bank.add(_slots[slotIndex]!);
      }
      _slots[slotIndex] = token;
      _bank.remove(token);
    });
  }

  // ── Validate ──────────────────────────────────────────────────────────────

  Future<void> _validate() async {
    final allFilled = _slots.every((s) => s != null);
    if (!allFilled) {
      _shakeCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
      return;
    }

    final placed = _slots.cast<String>();
    _correct = _listEquals(placed, _currentPuzzle.solution);

    if (_correct) {
      HapticFeedback.mediumImpact();
      _correctFlashCtrl.forward(from: 0);

      final solveTime = _elapsed - _puzzleStartTime;
      final points = SurvivalScoring.pointsFor(
        difficulty: widget.difficulty,
        solveSeconds: solveTime,
        currentStreak: _streak,
      );

      final actualCombo = SurvivalScoring.streakMultiplier(_streak + 1);

      setState(() {
        _score += points;
        _streak++;
        _solved++;
        if (_streak > _longestStreak) _longestStreak = _streak;
        _comboMultiplier = (actualCombo * 10).round();
      });

      _scorePopCtrl.forward(from: 0);

      final xpForPuzzle = (points / 50).floor().clamp(1, 100);
      _totalXpEarned += xpForPuzzle;

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && !_gameOver) {
          setState(() {
            _loadNextPuzzle();
            _submitted = false;
            _resultCtrl.reset();
            _scorePopCtrl.reset();
            _correctFlashCtrl.reset();
          });
        }
      });
    } else {
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0);

      _gameOver = true;
      _ticker.cancel();
      _stopwatch.stop();

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _resultCtrl.forward();
      });
    }

    setState(() => _submitted = true);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Game Over ──────────────────────────────────────────────────────────────

  Future<void> _endRun() async {
    final result = SurvivalRunResult(
      difficulty: widget.difficulty,
      score: _score,
      longestStreak: _longestStreak,
      solved: _solved,
      timeSec: _elapsed,
      xpEarned: _totalXpEarned,
      rank: SurvivalScoring.rankFor(_score),
    );

    final isNewBest = await SurvivalService().recordRun(result);

    if (mounted) {
      Navigator.pop(context, {'isNewBest': isNewBest});
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Difficulty-tinted background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0E0A1F),
                  _theme.bgAccent[0].withOpacity(.15),
                  const Color(0xFF0E0A1F),
                ],
              ),
            ),
          ),
          // Subtle top glow matching difficulty
          Positioned(
            top: -80, left: -60, right: -60,
            child: AnimatedBuilder(
              animation: _correctFlashCtrl,
              builder: (_, __) => Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _theme.primary.withOpacity(.08 + .12 * _correctFlashCtrl.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 6),
                _buildStatsBar(),
                const SizedBox(height: 10),
                // Answer zone — fixed, doesn't grow
                _buildAnswerZone(),
                const SizedBox(height: 10),
                // Token bank + button fill remaining space, token bank scrolls
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _buildTokenBank()),
                      const SizedBox(height: 10),
                      _buildActionButton(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_submitted && _gameOver) _buildGameOverOverlay(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: _gameOver ? null : () => _showQuitDialog(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon: replace with Image.asset('assets/icons/skull_icon.png', height: 16)
                Text(
                  '☠ SURVIVAL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: _theme.glow,
                  ),
                ),
                Text(
                  '${widget.difficulty.label} · $_solved solved',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          _buildTimer(),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    final color = _elapsed < 30
        ? Colors.white70
        : _elapsed < 60
            ? kGold
            : Colors.redAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _elapsed >= 60
              ? Colors.redAccent.withOpacity(.4)
              : Colors.white.withOpacity(.08),
        ),
        boxShadow: _elapsed >= 60
            ? [BoxShadow(color: Colors.red.withOpacity(.2), blurRadius: 12)]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Replace with: Image.asset('assets/icons/timer_icon.png', width: 14, height: 14)
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            _timerLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String get _timerLabel {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Stats Bar ──────────────────────────────────────────────────────────────

  Widget _buildStatsBar() {
    String comboDisplay = '${(_comboMultiplier / 10).toStringAsFixed(1)}x';
    if (_comboMultiplier == 10 || _comboMultiplier < 10) comboDisplay = '1.0x';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kBgCard.withOpacity(.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _theme.primary.withOpacity(.2)),
        boxShadow: [
          BoxShadow(
            color: _theme.glow.withOpacity(.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Replace icons below with Image.asset('assets/icons/star_icon.png', ...)
          _StatItem(icon: '⭐', label: 'Score', value: '$_score', color: kGold),
          _VertDivider(color: _theme.primary.withOpacity(.2)),
          _StatItem(icon: '🔥', label: 'Streak', value: '$_streak', color: Colors.orangeAccent),
          _VertDivider(color: _theme.primary.withOpacity(.2)),
          _StatItem(icon: '⚡', label: 'Combo', value: comboDisplay, color: kPurpleLight),
          _VertDivider(color: _theme.primary.withOpacity(.2)),
          _StatItem(icon: '📊', label: 'Solved', value: '$_solved', color: Colors.cyan),
        ],
      ),
    );
  }

  // ── Answer zone ────────────────────────────────────────────────────────────
  // Uses a ConstrainedBox so it never expands unboundedly on Hard mode

  Widget _buildAnswerZone() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        final shake = _shakeAnim.value == 0
            ? 0.0
            : ((_shakeAnim.value * 8) % 2 == 0 ? 6.0 : -6.0) * (1 - _shakeAnim.value);
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: AnimatedBuilder(
        animation: _correctFlashCtrl,
        builder: (_, child) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kBgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _submitted
                  ? (_correct
                      ? kGreen.withOpacity(.6 + .2 * _correctFlashCtrl.value)
                      : Colors.redAccent.withOpacity(.6))
                  : _theme.primary.withOpacity(.2 + .1 * _correctFlashCtrl.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _submitted
                    ? (_correct ? kGreen : Colors.red).withOpacity(.12 + .1 * _correctFlashCtrl.value)
                    : _theme.glow.withOpacity(.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Puzzle title row
            Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: _theme.primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPuzzle.title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _theme.primary.withOpacity(.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _theme.primary.withOpacity(.3)),
                  ),
                  child: Text(
                    _currentPuzzle.category,
                    style: TextStyle(
                      fontSize: 9,
                      color: _theme.primary,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── SQL Forge bar label ───────────────────────────────────────
            Row(
              children: [
                // Replace with Image.asset('assets/icons/sword_icon.png', width: 12, height: 12)
                Icon(Icons.auto_fix_high_rounded, size: 12, color: _theme.glow),
                const SizedBox(width: 6),
                Text(
                  'FORGE YOUR QUERY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _theme.glow,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Slot chips — wrapped, clipped inside a max-height box
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: List.generate(_slots.length, (i) => _buildSlot(i)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(int index) {
    final token = _slots[index];
    final isEmpty = token == null;

    return DragTarget<_TokenDrag>(
      onWillAcceptWithDetails: (details) => !_submitted && !_gameOver,
      onAcceptWithDetails: (details) {
        final drag = details.data;
        if (drag.fromSlot != null) {
          setState(() {
            final tmp = _slots[index];
            _slots[index] = _slots[drag.fromSlot!];
            _slots[drag.fromSlot!] = tmp;
          });
        } else {
          _dropOnSlot(index, drag.token);
        }
      },
      builder: (context, candidates, rejected) {
        final isHovered = candidates.isNotEmpty;
        return GestureDetector(
          onTap: isEmpty ? null : () => _removeToken(index),
          child: Draggable<_TokenDrag>(
            data: token != null ? _TokenDrag(token: token, fromSlot: index) : null,
            feedback: token != null ? _tokenChip(token, dragging: true) : const SizedBox(),
            childWhenDragging: _slotPlaceholder(isEmpty: true, hovered: false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minWidth: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                gradient: isEmpty
                    ? null
                    : (_submitted
                        ? (_correct
                            ? LinearGradient(colors: [kGreen.withOpacity(.3), kGreen.withOpacity(.15)])
                            : LinearGradient(colors: [Colors.red.withOpacity(.3), Colors.red.withOpacity(.15)]))
                        : const LinearGradient(colors: [Color(0xFF2D2050), Color(0xFF1E163A)])),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHovered
                      ? _theme.primary
                      : isEmpty
                          ? Colors.white12
                          : (_submitted
                              ? (_correct ? kGreen.withOpacity(.6) : Colors.redAccent.withOpacity(.6))
                              : _theme.tokenBorder.withOpacity(.35)),
                  width: isHovered ? 1.5 : 1,
                ),
                boxShadow: isHovered
                    ? [BoxShadow(color: _theme.primary.withOpacity(.3), blurRadius: 8)]
                    : [],
              ),
              child: isEmpty
                  ? Text('  ?  ',
                      style: TextStyle(fontSize: 13, color: Colors.white24, fontWeight: FontWeight.w500))
                  : Text(
                      token,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _tokenTextColor(token),
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _slotPlaceholder({required bool isEmpty, required bool hovered}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _theme.primary.withOpacity(.5)),
      ),
      child: const Text('     ', style: TextStyle(fontSize: 13)),
    );
  }

  // ── Token bank ────────────────────────────────────────────────────────────
  // Now uses SingleChildScrollView — the Expanded wrapper makes it fill space
  // without overflowing. Hard mode with 30+ tokens just scrolls.

  Widget _buildTokenBank() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: kBgCard.withOpacity(.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _theme.primary.withOpacity(.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Replace with Image.asset('assets/icons/rune_icon.png', width: 12, height: 12)
              Icon(Icons.blur_on_rounded, size: 12, color: _theme.primary),
              const SizedBox(width: 6),
              Text(
                'SQL RUNES',    // ← renamed from TOKENS
                style: TextStyle(
                  fontSize: 9,
                  color: _theme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              if (_bank.isNotEmpty)
                Text(
                  '${_bank.length} remaining',
                  style: const TextStyle(fontSize: 9, color: Colors.white24),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _bank.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '⚔ All runes placed!',
                      style: TextStyle(
                        fontSize: 13,
                        color: kGreen.withOpacity(.8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              : Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _bank.map((token) => _buildBankToken(token)).toList(),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildBankToken(String token) {
    return Draggable<_TokenDrag>(
      data: _TokenDrag(token: token, fromSlot: null),
      feedback: Material(
        color: Colors.transparent,
        child: _tokenChip(token, dragging: true),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _tokenChip(token)),
      child: GestureDetector(
        onTap: () => _placeToken(token),
        child: _tokenChip(token),
      ),
    );
  }

  Widget _tokenChip(String token, {bool dragging = false}) {
    final textColor = _tokenTextColor(token);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dragging
              ? [kPurpleMid, kPurpleDark]
              : [const Color(0xFF2A1F4E), const Color(0xFF1A1232)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dragging
              ? textColor.withOpacity(.8)
              : textColor.withOpacity(.25),
          width: dragging ? 1.5 : 1,
        ),
        boxShadow: dragging
            ? [BoxShadow(color: textColor.withOpacity(.4), blurRadius: 16, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text(
        token,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color _tokenTextColor(String token) {
    const keywords = {
      'SELECT', 'FROM', 'WHERE', 'ORDER BY', 'GROUP BY', 'HAVING',
      'LIMIT', 'JOIN', 'INNER JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'ON',
      'AS', 'AND', 'OR', 'NOT', 'IN', 'LIKE', 'BETWEEN', 'IS', 'NULL',
      'ASC', 'DESC', 'DISTINCT', 'COUNT(*)', 'SUM', 'AVG', 'MAX', 'MIN',
      'WITH', 'CTE', 'OVER', 'PARTITION BY', 'WINDOW', 'RANK', 'DENSE_RANK',
      'ROW_NUMBER', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
    };
    const operators = {'=', '!=', '>', '<', '>=', '<=', '@>', '->>', '->'};

    final upper = token.toUpperCase().replaceAll(RegExp(r'[(),]'), '').trim();
    if (keywords.contains(upper)) return kCyan;
    if (operators.contains(token.trim())) return kGold;
    if (token.startsWith("'") || token.startsWith('"')) return kGreen;
    if (int.tryParse(token.replaceAll(')', '')) != null) return kGold;
    if (RegExp(r'^[A-Z]+\(').hasMatch(token)) return kCyan;
    if (token.startsWith('(')) return kPurpleLight;
    // JSONB / path operators get accent color
    if (token.contains('::') || token.contains('->') || token.contains('@')) return Colors.orangeAccent;
    return Colors.white;
  }

  // ── Action button ─────────────────────────────────────────────────────────

  Widget _buildActionButton() {
    final allFilled = _slots.every((s) => s != null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GestureDetector(
        onTap: (_submitted || _gameOver) ? null : _validate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            gradient: allFilled
                ? LinearGradient(
                    colors: [_theme.primary, _theme.glow],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: allFilled ? null : kBgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: allFilled ? Colors.transparent : Colors.white12,
            ),
            boxShadow: allFilled
                ? [BoxShadow(color: _theme.primary.withOpacity(.5), blurRadius: 20, offset: const Offset(0, 8))]
                : [],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Replace with Image.asset('assets/icons/check_icon.png', width: 18, height: 18)
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: allFilled ? Colors.white : Colors.white24,
              ),
              const SizedBox(width: 10),
              Text(
                'SUBMIT ANSWER',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: allFilled ? Colors.white : Colors.white24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Game Over Overlay ─────────────────────────────────────────────────────

  Widget _buildGameOverOverlay() {
    return FadeTransition(
      opacity: _resultFade,
      child: Container(
        color: Colors.black.withOpacity(.88),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGameOverCard(),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _endRun,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: kGoldGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: kGold.withOpacity(.4), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'SEE RESULTS',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverCard() {
    final rank = SurvivalScoring.rankFor(_score);
    final rankColor = rank == 'S'
        ? kGold
        : rank == 'A'
            ? kPurpleLight
            : Colors.white;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.redAccent.withOpacity(.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(.2), blurRadius: 40, offset: const Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Game Over icon — replace with Image.asset('assets/icons/skull_dead.png', width: 72, height: 72)
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.redAccent.withOpacity(.3), Colors.red.withOpacity(.1)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent.withOpacity(.5)),
                ),
                child: const Icon(Icons.close_rounded, size: 36, color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              const Text(
                'GAME OVER',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.redAccent),
              ),
              const SizedBox(height: 6),
              const Text(
                'One mistake ends the run',
                style: TextStyle(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white12),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ResultStat(label: 'Score',       value: '$_score',          color: kGold),
                  _ResultStat(label: 'Solved',      value: '$_solved',         color: Colors.cyan),
                  _ResultStat(label: 'Best Streak', value: '$_longestStreak',  color: Colors.orangeAccent),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RANK',
                      style: TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w700, letterSpacing: 2),
                    ),
                    Text(
                      rank,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: rankColor,
                        shadows: [Shadow(color: rankColor.withOpacity(.4), blurRadius: 12)],
                      ),
                    ),
                    Text(
                      'XP: +$_totalXpEarned',
                      style: const TextStyle(fontSize: 14, color: kGold, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (widget.personalBest != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPurpleMid.withOpacity(.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPurpleMid.withOpacity(.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Replace with Image.asset('assets/icons/trophy_icon.png', width: 16, height: 16)
                      const Icon(Icons.emoji_events_rounded, color: kGold, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Personal Best: ${widget.personalBest!.score} pts',
                          style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Quit dialog ────────────────────────────────────────────────────────────

  void _showQuitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kBgCard,
        title: const Text('Quit Survival?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text('Your run progress will be lost.',
            style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('QUIT', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  final Color color;
  const _VertDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: color);
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Drag payload ──────────────────────────────────────────────────────────────

class _TokenDrag {
  final String token;
  final int? fromSlot;
  const _TokenDrag({required this.token, this.fromSlot});
}