import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../theme.dart';
import 'package:code_shuffle/services/daily_challenge_service.dart';

/// Full-screen game for the daily challenge.
/// No timer, no hints, no stars — just solve it.
/// Shows an intro dialog on first open, locks after completion.
class DailyGameScreen extends StatefulWidget {
  final DailyPuzzle puzzle;

  /// Called when the user successfully completes the challenge.
  final VoidCallback onCompleted;

  const DailyGameScreen({
    super.key,
    required this.puzzle,
    required this.onCompleted,
  });

  @override
  State<DailyGameScreen> createState() => _DailyGameScreenState();
}

class _DailyGameScreenState extends State<DailyGameScreen>
    with TickerProviderStateMixin {
  // ── Puzzle state ────────────────────────────────────────────────────────────
  late List<String> _bank;
  late List<String?> _slots;
  bool _submitted = false;
  bool _correct = false;

  // ── Animations ──────────────────────────────────────────────────────────────
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _resultCtrl;
  late Animation<double> _resultFade;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _initPuzzle();
    _initAnimations();
    // Show intro popup after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIntroDialog());
  }

  void _initPuzzle() {
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

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _resultCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Intro dialog ─────────────────────────────────────────────────────────────

  void _showIntroDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1530),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kBlue.withOpacity(.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: kBlue.withOpacity(.25),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Calendar icon glow
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kBlue.withOpacity(.15),
                  border: Border.all(color: kBlue.withOpacity(.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: kBlue.withOpacity(.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/calendar_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'DAILY CHALLENGE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Description with bold difficulty note
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white60,
                    height: 1.65,
                  ),
                  children: [
                    TextSpan(
                      text:
                          'Every day brings a new SQL puzzle with ',
                    ),
                    TextSpan(
                      text: 'varied difficulty — from Easy to Extremely Hard.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text:
                          '\n\nDon\'t get discouraged if you find it overwhelming or hard — keep practising to get there!',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // No hints / no timer note
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.05),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withOpacity(.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.info_outline_rounded,
                        size: 13, color: Colors.white38),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'No hints · No timer · One shot per day',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: kBlue.withOpacity(.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'LET\'S GO!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
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

  // ── Token interactions ───────────────────────────────────────────────────────

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

  void _dropOnSlot(int slotIndex, String token) {
    if (_submitted) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_slots[slotIndex] != null) _bank.add(_slots[slotIndex]!);
      _slots[slotIndex] = token;
      _bank.remove(token);
    });
  }

  void _reorderSlots(int oldIndex, int newIndex) {
    if (_submitted) return;
    setState(() {
      final item = _slots.removeAt(oldIndex);
      _slots.insert(newIndex, item);
    });
  }

  // ── Validate ────────────────────────────────────────────────────────────────

  Future<void> _validate() async {
    final allFilled = _slots.every((s) => s != null);
    if (!allFilled) {
      _shakeCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
      return;
    }

    final placed = _slots.cast<String>();
    _correct = _listEquals(placed, widget.puzzle.solution);

    if (!_correct) {
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0);
      setState(() => _submitted = true);
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _submitted = true);
      // Notify parent so it can mark completion + update button state.
      widget.onCompleted();
    }

    _resultCtrl.forward();
  }

  void _reset() {
    _shakeCtrl.reset();
    _resultCtrl.reset();
    setState(() {
      _submitted = false;
      _correct = false;
      _initPuzzle();
    });
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Token colour (same palette as GameScreen) ────────────────────────────────

  Color _tokenTextColor(String t) {
    const keywords = {
      'SELECT', 'FROM', 'WHERE', 'JOIN', 'ON', 'GROUP', 'BY', 'ORDER',
      'HAVING', 'WITH', 'AS', 'AND', 'OR', 'NOT', 'IN', 'BETWEEN', 'LIKE',
      'IS', 'NULL', 'INNER', 'LEFT', 'RIGHT', 'FULL', 'OUTER', 'CROSS',
      'UNION', 'ALL', 'DISTINCT', 'LIMIT', 'OFFSET', 'INSERT', 'INTO',
      'VALUES', 'UPDATE', 'SET', 'DELETE', 'CREATE', 'TABLE', 'DROP',
      'ALTER', 'INDEX', 'EXISTS', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
      'OVER', 'PARTITION', 'RANGE', 'ROWS', 'UNBOUNDED', 'PRECEDING',
      'FOLLOWING', 'CURRENT', 'ROW', 'RECURSIVE',
    };
    const functions = {
      'COUNT(*)', 'SUM(', 'AVG(', 'MAX(', 'MIN(', 'COALESCE(', 'NULLIF(',
      'CAST(', 'CONCAT(', 'LENGTH(', 'LOWER(', 'UPPER(', 'TRIM(',
      'EXTRACT(', 'DATE(', 'NOW()', 'CURRENT_DATE', 'CURRENT_TIMESTAMP',
      'ROW_NUMBER()', 'RANK()', 'DENSE_RANK()', 'LAG(', 'LEAD(',
      'FIRST_VALUE(', 'LAST_VALUE(', 'STRING_AGG(', 'ARRAY_AGG(',
    };
    final up = t.toUpperCase();
    if (keywords.contains(up)) return kCyan;
    if (functions.any((f) => up.startsWith(f.toUpperCase()))) return kGold;
    if (t.startsWith("'") && t.endsWith("'")) return const Color(0xFF86EFAC);
    if (RegExp(r'^\d+$').hasMatch(t)) return const Color(0xFFFCA5A5);
    return Colors.white;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _submitted ? _buildResultPanel() : _buildPuzzleBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final diffColor = _difficultyColor(widget.puzzle.difficulty);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white70, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          // Calendar icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBlue.withOpacity(.18),
              border: Border.all(color: kBlue.withOpacity(.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset('assets/images/calendar_icon.png',
                  fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAILY CHALLENGE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Colors.white38,
                  ),
                ),
                Text(
                  widget.puzzle.title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Difficulty badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: diffColor.withOpacity(.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: diffColor.withOpacity(.4)),
            ),
            child: Text(
              widget.puzzle.difficulty.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: diffColor,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _difficultyColor(String d) {
    switch (d.toLowerCase()) {
      case 'easy':
        return kGreen;
      case 'medium':
        return kBlue;
      case 'hard':
        return kAdvPurple;
      case 'extremely hard':
        return const Color(0xFFFF4D4D);
      default:
        return Colors.white54;
    }
  }

  // ── Puzzle body ──────────────────────────────────────────────────────────────

  Widget _buildPuzzleBody() {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Category chip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.05),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: Colors.white.withOpacity(.08)),
              ),
              child: Text(
                widget.puzzle.category,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white38,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // ── Answer slots ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) {
              final dx = _shakeAnim.value *
                  8 *
                  (0.5 - (_shakeCtrl.value % 0.25) / 0.25).sign;
              return Transform.translate(
                  offset: Offset(dx, 0), child: child);
            },
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 56),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(.1)),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(_slots.length, (i) {
                  final token = _slots[i];
                  return DragTarget<_TokenDrag>(
                    onAcceptWithDetails: (details) =>
                        _dropOnSlot(i, details.data.token),
                    builder: (_, candidates, __) {
                      final isHovered = candidates.isNotEmpty;
                      return GestureDetector(
                        onTap: () => _removeToken(i),
                        child: Draggable<_TokenDrag>(
                          data: _TokenDrag(token: token ?? '', fromSlot: i),
                          feedback: token != null
                              ? _buildTokenChip(token,
                                  isDragging: true)
                              : const SizedBox.shrink(),
                          childWhenDragging:
                              _buildSlotEmpty(highlighted: true),
                          child: token != null
                              ? _buildTokenChip(token)
                              : _buildSlotEmpty(highlighted: isHovered),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ── Token bank ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bank.map((token) {
                  return Draggable<_TokenDrag>(
                    data: _TokenDrag(token: token),
                    feedback:
                        _buildTokenChip(token, isDragging: true),
                    childWhenDragging:
                        _buildTokenChip(token, faded: true),
                    child: GestureDetector(
                      onTap: () => _placeToken(token),
                      child: _buildTokenChip(token),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        // ── Submit button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: GestureDetector(
            onTap: _validate,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: kBlue.withOpacity(.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'SUBMIT',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenChip(String token,
      {bool isDragging = false, bool faded = false}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: faded ? 0.3 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isDragging
                ? kBgCard.withOpacity(.9)
                : kBgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDragging
                  ? kBlue.withOpacity(.6)
                  : kPurpleMid.withOpacity(.35),
            ),
            boxShadow: isDragging
                ? [
                    BoxShadow(
                      color: kBlue.withOpacity(.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Text(
            token,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _tokenTextColor(token),
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotEmpty({bool highlighted = false}) {
    return Container(
      width: 48,
      height: 32,
      decoration: BoxDecoration(
        color: highlighted
            ? kBlue.withOpacity(.12)
            : Colors.white.withOpacity(.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted
              ? kBlue.withOpacity(.5)
              : Colors.white.withOpacity(.12),
          style: BorderStyle.solid,
        ),
      ),
    );
  }

  // ── Result panel ─────────────────────────────────────────────────────────────

  Widget _buildResultPanel() {
    return FadeTransition(
      opacity: _resultFade,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          children: [
            // Result icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_correct ? kGreen : const Color(0xFFEF4444))
                    .withOpacity(.15),
                border: Border.all(
                  color: (_correct ? kGreen : const Color(0xFFEF4444))
                      .withOpacity(.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_correct ? kGreen : const Color(0xFFEF4444))
                        .withOpacity(.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _correct
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: _correct ? kGreen : const Color(0xFFEF4444),
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _correct ? 'Challenge Complete! 🎉' : 'Not Quite...',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _correct
                  ? 'See you tomorrow for the next one!'
                  : 'Keep practising — you\'ve got this!',
              style: const TextStyle(fontSize: 13, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),

            // Solution hidden on wrong — only shown 1h before midnight
            if (!_correct) ...[
              _buildSolutionBlock(),
              const SizedBox(height: 16),
            ],

            // Explanation
            _sectionLabel('EXPLANATION'),
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

            // Back button — always shown (one shot per day, no retry on wrong)
            _backButton(),
          ],
        ),
      ),
    );
  }

  /// Shows the correct answer only in the final hour of the day (23:00–00:00).
  /// Before that, shows a countdown telling the user when it unlocks.
  Widget _buildSolutionBlock() {
    final now = DateTime.now();
    final unlockHour = 23; // solution visible after 23:00
    final solutionUnlocked = now.hour >= unlockHour;

    if (_correct) return const SizedBox.shrink(); // never needed on correct

    if (!solutionUnlocked) {
      // Show a locked hint with countdown
      final unlockTime = DateTime(now.year, now.month, now.day, unlockHour);
      final remaining = unlockTime.difference(now);
      final hh = remaining.inHours.toString().padLeft(2, '0');
      final mm = (remaining.inMinutes % 60).toString().padLeft(2, '0');
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_clock_rounded, size: 18, color: Colors.white38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Solution unlocks at 23:00',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Available in ${hh}h ${mm}m — keep practising until then!',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // After 23:00 — show the full solution
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('CORRECT ANSWER'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.04),
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
                        border: Border.all(color: kGreen.withOpacity(.3)),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _tokenTextColor(t),
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white38,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      );

  Widget _backButton() => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: kBlue.withOpacity(.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BACK TO HOME',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.home_rounded, size: 16),
            ],
          ),
        ),
      );
}

// ── Drag payload ──────────────────────────────────────────────────────────────
class _TokenDrag {
  final String token;
  final int? fromSlot;
  const _TokenDrag({required this.token, this.fromSlot});
}