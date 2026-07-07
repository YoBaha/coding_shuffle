import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../theme.dart';
import 'package:code_shuffle/modals/modals.dart';
import 'package:code_shuffle/services/progress_service.dart';

class GameScreen extends StatefulWidget {
  final Puzzle puzzle;
  final PuzzleLevel level;
  final Map<String, PuzzleProgress> progress;
  final void Function(Map<String, PuzzleProgress> updatedProgress, int xpGained)
      onCompleted;

  const GameScreen({
    super.key,
    required this.puzzle,
    required this.level,
    required this.progress,
    required this.onCompleted,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  final _progressService = ProgressService();

  // ── State ──────────────────────────────────────────────────────────────────
  late List<String> _bank;      // tokens still in the bank (bottom)
  late List<String?> _slots;    // tokens placed in the answer row (nullable = empty)
  bool _submitted = false;
  bool _correct = false;
  int _stars = 0;
  int _xpGained = 0;
  bool _hintVisible = false;

  // ── Timer ──────────────────────────────────────────────────────────────────
  late Stopwatch _stopwatch;
  late Timer _ticker;
  int _elapsed = 0; // seconds displayed

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _resultCtrl;
  late Animation<double> _resultFade;
  late AnimationController _starCtrl;
  late Animation<double> _starScale;

  @override
  void initState() {
    super.initState();
    _initPuzzle();
    _initAnimations();
    _startTimer();
  }

  void _initPuzzle() {
    // Shuffle the bank tokens
    _bank = List<String>.from(widget.puzzle.tokens)..shuffle();
    _slots = List<String?>.filled(widget.puzzle.solution.length, null);
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

    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _starScale = CurvedAnimation(parent: _starCtrl, curve: Curves.elasticOut);
  }

  void _startTimer() {
    _stopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_submitted) {
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
    _starCtrl.dispose();
    super.dispose();
  }

  // ── Token interactions ─────────────────────────────────────────────────────

  /// Tap a bank token → place it in the first empty slot
  void _placeToken(String token) {
    if (_submitted) return;
    final idx = _slots.indexOf(null);
    if (idx == -1) return;
    HapticFeedback.selectionClick();
    setState(() {
      _slots[idx] = token;
      _bank.remove(token);
    });
  }

  /// Tap a placed slot token → return it to the bank
  void _removeToken(int slotIndex) {
    if (_submitted) return;
    final token = _slots[slotIndex];
    if (token == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _bank.add(token);
      _slots[slotIndex] = null;
    });
  }

  // ── Drag from bank to a specific slot ─────────────────────────────────────
  void _dropOnSlot(int slotIndex, String token) {
    if (_submitted) return;
    HapticFeedback.selectionClick();
    setState(() {
      // If slot already has a token, send it back to bank
      if (_slots[slotIndex] != null) {
        _bank.add(_slots[slotIndex]!);
      }
      _slots[slotIndex] = token;
      _bank.remove(token);
    });
  }

  // ── Reorder placed tokens by drag ─────────────────────────────────────────
  void _reorderSlots(int oldIndex, int newIndex) {
    if (_submitted) return;
    setState(() {
      final item = _slots.removeAt(oldIndex);
      _slots.insert(newIndex, item);
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

    _ticker.cancel();
    _stopwatch.stop();
    _elapsed = _stopwatch.elapsed.inSeconds;

    final placed = _slots.cast<String>();
    _correct = _listEquals(placed, widget.puzzle.solution);
    _stars = _correct
        ? widget.puzzle.starsCriteria.starsForTime(_elapsed)
        : 0;

    if (!_correct) {
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0);
    } else {
      HapticFeedback.mediumImpact();
    }

    // Record progress and get XP
    if (_correct) {
      final updatedProgress = Map<String, PuzzleProgress>.from(widget.progress);
      _xpGained = await _progressService.recordCompletion(
        puzzleId: widget.puzzle.id,
        levelId: widget.level.id,
        stars: _stars,
        elapsedSeconds: _elapsed,
        xpPerStar: widget.level.xpPerStar,
        progress: updatedProgress,
      );
      widget.onCompleted(updatedProgress, _xpGained);
    }

    setState(() => _submitted = true);
    _resultCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _starCtrl.forward();
    });
  }

  void _reset() {
    _shakeCtrl.reset();
    _resultCtrl.reset();
    _starCtrl.reset();
    setState(() {
      _submitted = false;
      _correct = false;
      _stars = 0;
      _xpGained = 0;
      _hintVisible = false;
      _elapsed = 0;
      _initPuzzle();
    });
    _startTimer();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Timer display ─────────────────────────────────────────────────────────
  String get _timerLabel {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBgGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildAnswerZone(),
                  const SizedBox(height: 8),
                  _buildHintRow(),
                  const Spacer(),
                  _buildTokenBank(),
                  const SizedBox(height: 12),
                  _buildActionButton(),
                  const SizedBox(height: 20),
                ],
              ),
              // Result overlay
              if (_submitted) _buildResultOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.puzzle.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  widget.level.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: _levelColor(),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kBgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: _timerColor()),
                const SizedBox(width: 6),
                Text(
                  _timerLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _timerColor(),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _levelColor() {
    switch (widget.level.id) {
      case 'beginner':     return kGreen;
      case 'intermediate': return kBlue;
      default:             return kAdvPurple;
    }
  }

  Color _timerColor() {
    if (_elapsed < 30) return Colors.white70;
    if (_elapsed < 60) return kGold;
    return Colors.redAccent;
  }

  // ── Answer zone (slots) ───────────────────────────────────────────────────
  Widget _buildAnswerZone() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        final shake = _shakeAnim.value == 0
            ? 0.0
            : ((_shakeAnim.value * 8) % 2 == 0 ? 6.0 : -6.0) *
                (1 - _shakeAnim.value);
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _submitted
                ? (_correct
                    ? kGreen.withOpacity(.5)
                    : Colors.redAccent.withOpacity(.5))
                : kPurpleMid.withOpacity(.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _submitted
                  ? (_correct ? kGreen : Colors.red).withOpacity(.15)
                  : Colors.black.withOpacity(.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: kPurpleLight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'YOUR QUERY',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_slots.length, (i) {
                return _buildSlot(i);
              }),
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
      onWillAcceptWithDetails: (details) => !_submitted,
      onAcceptWithDetails: (details) {
        final drag = details.data;
        if (drag.fromSlot != null) {
          // Swap two slots
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isEmpty
                    ? null
                    : (_submitted
                        ? (_correct
                            ? LinearGradient(colors: [
                                kGreen.withOpacity(.3),
                                kGreen.withOpacity(.15)
                              ])
                            : LinearGradient(colors: [
                                Colors.red.withOpacity(.3),
                                Colors.red.withOpacity(.15)
                              ]))
                        : const LinearGradient(
                            colors: [Color(0xFF2D2050), Color(0xFF1E163A)],
                          )),
                color: isEmpty ? null : null,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHovered
                      ? kPurpleLight
                      : isEmpty
                          ? Colors.white12
                          : (_submitted
                              ? (_correct
                                  ? kGreen.withOpacity(.6)
                                  : Colors.redAccent.withOpacity(.6))
                              : kPurpleMid.withOpacity(.4)),
                  width: isHovered ? 1.5 : 1,
                ),
              ),
              child: isEmpty
                  ? Text(
                      '  ?  ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white24,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : Text(
                      token,
                      style: TextStyle(
                        fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPurpleLight.withOpacity(.5)),
      ),
      child: const Text('     ', style: TextStyle(fontSize: 14)),
    );
  }

  // ── Hint ──────────────────────────────────────────────────────────────────
  Widget _buildHintRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _hintVisible = !_hintVisible),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 14,
                  color: kGold.withOpacity(.7),
                ),
                const SizedBox(width: 6),
                Text(
                  _hintVisible ? 'Hide hint' : 'Show hint',
                  style: TextStyle(
                    fontSize: 12,
                    color: kGold.withOpacity(.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: _hintVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kGold.withOpacity(.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGold.withOpacity(.2)),
                      ),
                      child: Text(
                        widget.puzzle.hint,
                        style: TextStyle(
                          fontSize: 13,
                          color: kGold.withOpacity(.9),
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Token bank ────────────────────────────────────────────────────────────
  Widget _buildTokenBank() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBgCard.withOpacity(.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOKENS',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white38,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          _bank.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'All tokens placed ↑',
                      style: TextStyle(
                        fontSize: 13,
                        color: kGreen.withOpacity(.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _bank.map((token) => _buildBankToken(token)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildBankToken(String token) {
    return Draggable<_TokenDrag>(
      data: _TokenDrag(token: token, fromSlot: null),
      feedback: _tokenChip(token, dragging: true),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _tokenChip(token),
      ),
      child: GestureDetector(
        onTap: () => _placeToken(token),
        child: _tokenChip(token),
      ),
    );
  }

  Widget _tokenChip(String token, {bool dragging = false}) {
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dragging
                ? [kPurpleMid, kPurpleDark]
                : [const Color(0xFF2A1F4E), const Color(0xFF1E163A)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: dragging
                ? kPurpleLight
                : kPurpleMid.withOpacity(.5),
          ),
          boxShadow: dragging
              ? [
                  BoxShadow(
                    color: kPurpleMid.withOpacity(.6),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Text(
          token,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _tokenTextColor(token),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  /// Colour-code token type (SQL keywords vs identifiers vs operators vs values)
  Color _tokenTextColor(String token) {
    const keywords = {
      'SELECT', 'FROM', 'WHERE', 'ORDER BY', 'GROUP BY', 'HAVING',
      'LIMIT', 'JOIN', 'INNER JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'ON',
      'AS', 'AND', 'OR', 'NOT', 'IN', 'LIKE', 'BETWEEN', 'IS', 'NULL',
      'ASC', 'DESC', 'DISTINCT', 'COUNT(*)', 'SUM', 'AVG', 'MAX', 'MIN',
    };
    const operators = {'=', '!=', '>', '<', '>=', '<='};

    final upper = token.toUpperCase().replaceAll(RegExp(r'[(),]'), '').trim();
    if (keywords.contains(upper)) return kCyan;
    if (operators.contains(token.trim())) return kGold;
    if (token.startsWith("'") || token.startsWith('"')) return kGreen;
    if (int.tryParse(token.replaceAll(')', '')) != null) return kGold;
    // Aggregate functions like COUNT(*), SUM(total), AVG(score)
    if (RegExp(r'^[A-Z]+\(').hasMatch(token)) return kCyan;
    // Subquery openers like (SELECT
    if (token.startsWith('(')) return kPurpleLight;
    return Colors.white;
  }

  // ── Action button ─────────────────────────────────────────────────────────
  Widget _buildActionButton() {
    final allFilled = _slots.every((s) => s != null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _submitted ? null : _validate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: allFilled ? kButtonGradient : null,
            color: allFilled ? null : kBgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: allFilled
                  ? Colors.transparent
                  : Colors.white12,
            ),
            boxShadow: allFilled
                ? [
                    BoxShadow(
                      color: kPurpleMid.withOpacity(.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: allFilled ? Colors.white : Colors.white24,
              ),
              const SizedBox(width: 10),
              Text(
                'CHECK ANSWER',
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

  // ── Result overlay ────────────────────────────────────────────────────────
  Widget _buildResultOverlay() {
    return FadeTransition(
      opacity: _resultFade,
      child: Container(
        color: Colors.black.withOpacity(.75),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildResultCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _correct
              ? kGreen.withOpacity(.4)
              : Colors.redAccent.withOpacity(.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_correct ? kGreen : Colors.red).withOpacity(.2),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            // Top accent
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: _correct
                    ? LinearGradient(colors: [kGreen, kGreen.withOpacity(.3)])
                    : LinearGradient(
                        colors: [Colors.redAccent, Colors.red.withOpacity(.3)]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                children: [
                  // Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: _correct
                          ? LinearGradient(
                              colors: [kGreen.withOpacity(.3), kGreen.withOpacity(.1)])
                          : LinearGradient(colors: [
                              Colors.redAccent.withOpacity(.3),
                              Colors.red.withOpacity(.1)
                            ]),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _correct
                            ? kGreen.withOpacity(.5)
                            : Colors.redAccent.withOpacity(.5),
                      ),
                    ),
                    child: Icon(
                      _correct
                          ? Icons.check_rounded
                          : Icons.close_rounded,
                      size: 36,
                      color: _correct ? kGreen : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    _correct ? 'CORRECT!' : 'NOT QUITE',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: _correct ? kGreen : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _correct
                        ? 'Solved in $_elapsed seconds'
                        : 'Keep practising — you\'ve got this',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),

                  // Stars
                  if (_correct) ...[
                    const SizedBox(height: 24),
                    ScaleTransition(
                      scale: _starScale,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              i < _stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: i < _stars ? kGold : Colors.white24,
                              size: 40,
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // XP gained badge
                    if (_xpGained > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: kGoldGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+$_xpGained XP',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),

                  // Correct solution (on wrong answer)
                  if (!_correct) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'CORRECT ANSWER',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.puzzle.solution
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: kBgDark,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: kGreen.withOpacity(.3)),
                                  ),
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _tokenTextColor(t),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Explanation
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'EXPLANATION',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.puzzle.explanation,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Buttons
                  Row(
                    children: [
                      // Try again / retry
                      Expanded(
                        child: GestureDetector(
                          onTap: _reset,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.07),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: Colors.white.withOpacity(.1)),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.replay_rounded,
                                    size: 16, color: Colors.white60),
                                const SizedBox(width: 8),
                                const Text(
                                  'TRY AGAIN',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white60,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Next / back
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: kButtonGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: kPurpleMid.withOpacity(.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _correct ? 'NEXT' : 'BACK',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 16),
                              ],
                            ),
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
      ),
    );
  }
}

// ── Drag payload ──────────────────────────────────────────────────────────────
class _TokenDrag {
  final String token;
  final int? fromSlot; // null if dragged from bank

  const _TokenDrag({required this.token, this.fromSlot});
}