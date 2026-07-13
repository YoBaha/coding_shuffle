// lib/screens/sql_stream_screen.dart
//
// SQL Stream — vertical falling-lanes arcade mode.
// 4 lanes. Tokens fall top→bottom. Tap correct token to fill next query blank.
// No overlaps: each lane uses a reserved slot grid. No repeats in one game.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Assets
// ─────────────────────────────────────────────────────────────────────────────

class _A {
  static const starIcon       = 'assets/images/star_icon.png';
  static const fireIcon       = 'assets/images/fire_icon.png';
  static const runeIcon       = 'assets/images/rune_icon.png';
  static const lightningIcon  = 'assets/images/lightning_icon.png';
  static const checkIcon      = 'assets/images/check_icon.png';
  static const statsIcon      = 'assets/images/stats_icon.png';
  static const skullIcon      = 'assets/images/skull_icon.png';
  static const chainIcon      = 'assets/images/chain_icon.png';
  static const hpFull         = 'assets/images/full_hp_bar.png';
  static const hpHalf         = 'assets/images/half_hp_bar.png';
  static const hpLastHit      = 'assets/images/heart_last_hit_bar.png';
  static const streamBg       = 'assets/images/stream_bg.png';
  static const errorSound     = 'assets/music/error_sound.mp3';
  static const placementSound = 'assets/music/placement_sound.mp3';
  static const successSound   = 'assets/music/sucess_sound.mp3';
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _StreamPuzzle {
  final String id;
  final String title;
  final List<String> solution;

  const _StreamPuzzle({
    required this.id,
    required this.title,
    required this.solution,
  });

  factory _StreamPuzzle.fromJson(Map<String, dynamic> j) => _StreamPuzzle(
    id:       j['id']    as String,
    title:    j['title'] as String,
    solution: List<String>.from(j['solution'] as List),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Falling token instance
// ─────────────────────────────────────────────────────────────────────────────

class _FallingToken {
  final String token;
  final int    lane;
  final bool   isTarget;
  final int    id;
  double       progress; // 0.0 (top) → 1.0 (bottom exit)

  _FallingToken({
    required this.token,
    required this.lane,
    required this.isTarget,
    required this.id,
    this.progress = 0.0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Token colour
// ─────────────────────────────────────────────────────────────────────────────

Color _tokenColor(String token) {
  final t = token.toUpperCase();
  if (['SELECT', 'SELECT DISTINCT'].contains(t))       return const Color(0xFF22D3EE);
  if (['FROM', 'JOIN', 'LEFT JOIN', 'RIGHT JOIN',
       'INNER JOIN', 'FULL OUTER JOIN'].any(t.startsWith))
                                                        return const Color(0xFF4ADE80);
  if (['WHERE', 'HAVING'].contains(t))                 return const Color(0xFFFBBF24);
  if (['GROUP BY', 'ORDER BY'].contains(t))            return const Color(0xFFA78BFA);
  if (['AND', 'OR', 'NOT'].contains(t))                return const Color(0xFFF97316);
  if (['LIMIT', 'OFFSET'].contains(t))                 return const Color(0xFFF472B6);
  if (t.startsWith('COUNT') || t.startsWith('SUM') ||
      t.startsWith('AVG')   || t.startsWith('MAX') ||
      t.startsWith('MIN'))                             return const Color(0xFFFF6B6B);
  return Colors.white;
}

// ─────────────────────────────────────────────────────────────────────────────
// SFX
// ─────────────────────────────────────────────────────────────────────────────

class _Sfx {
  final AudioPlayer _hit  = AudioPlayer();
  final AudioPlayer _miss = AudioPlayer();
  final AudioPlayer _done = AudioPlayer();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _hit.setAsset(_A.placementSound);
      await _miss.setAsset(_A.errorSound);
      await _done.setAsset(_A.successSound);
      _ready = true;
    } catch (_) {}
  }

  Future<void> hit()  async { try { await _hit.seek(Duration.zero);  _hit.play();  } catch (_){} }
  Future<void> miss() async { try { await _miss.seek(Duration.zero); _miss.play(); } catch (_){} }
  Future<void> done() async { try { await _done.seek(Duration.zero); _done.play(); } catch (_){} }

  void dispose() { _hit.dispose(); _miss.dispose(); _done.dispose(); }
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const int    _kLanes        = 4;
// Minimum progress gap between two tokens in the same lane — prevents overlap.
// At 0.28 and a token height ~10% of screen, tokens never touch.
const double _kLaneGap      = 0.28;
const double _kFallStart    = 0.003;  // progress/tick at game start
const double _kFallMax      = 0.011;  // never faster
const double _kFallStep     = 0.0004; // added per query completed

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class SqlStreamScreen extends StatefulWidget {
  /// Called when the run ends with the XP earned this session.
  final void Function(int xpGained)? onXpGained;

  const SqlStreamScreen({super.key, this.onXpGained});

  @override
  State<SqlStreamScreen> createState() => _SqlStreamScreenState();
}

class _SqlStreamScreenState extends State<SqlStreamScreen>
    with TickerProviderStateMixin {

  // ── Loading ──────────────────────────────────────────────────────────────────
  bool _loading = true;
  List<_StreamPuzzle> _allPuzzles = [];

  // ── Game state ───────────────────────────────────────────────────────────────
  bool _gameOver    = false;
  bool _gameStarted = false;
  int  _lives       = 3;
  int  _score       = 0;
  int  _streak      = 0;
  int  _bestStreak  = 0;
  int  _queriesDone = 0;

  // ── FIX 2: Puzzle queue — shuffled indices, drained without repeating ────────
  List<int> _puzzleQueue = [];
  int       _puzzleQueueIdx = 0;

  // ── Puzzle state ─────────────────────────────────────────────────────────────
  late _StreamPuzzle _puzzle;
  int          _nextSlot = 0;
  List<String?> _caught  = [];
  List<String>  _decoyPool = [];

  // ── Falling tokens ───────────────────────────────────────────────────────────
  final List<_FallingToken> _tokens = [];
  int _tokenIdCtr = 0;

  // FIX 1: per-lane head progress — track the topmost (lowest progress) token
  // in each lane so we never spawn closer than _kLaneGap.
  final List<double> _laneHead = List.filled(_kLanes, -1.0);

  // Whether the target is currently on screen
  bool _targetOnScreen = false;

  // Query-complete celebration overlay on the card
  bool _queryComplete = false;

  // Hint highlight: only shown after a delay per slot
  bool   _hintVisible = false;
  Timer? _hintTimer;

  // ── Speed ────────────────────────────────────────────────────────────────────
  double _fallSpeed = _kFallStart;

  // ── Game loop ────────────────────────────────────────────────────────────────
  late Ticker  _ticker;
  Duration     _lastTick = Duration.zero;

  // ── Animations ───────────────────────────────────────────────────────────────
  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;
  late AnimationController _flashCtrl;
  late Animation<double>   _flashAnim;
  late AnimationController _pulseCtrl;

  // ── Burst ────────────────────────────────────────────────────────────────────
  bool   _showBurst = false;
  Offset _burstPos  = Offset.zero;

  final _sfx = _Sfx();
  final _rng = Random();

  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _sfx.init();

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0,   end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end:  10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  10.0, end:  -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  -6.0, end:   6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:   6.0, end:   0.0), weight: 1),
    ]).animate(_shakeCtrl);

    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _flashAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut),
    );

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);

    _ticker = createTicker(_onTick)..start();
    _loadPuzzles();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shakeCtrl.dispose();
    _flashCtrl.dispose();
    _pulseCtrl.dispose();
    _sfx.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Tick
  // ─────────────────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (!_gameStarted || _gameOver || _loading) return;

    final dt = _lastTick == Duration.zero
        ? 0.0
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    setState(() {
      final delta = _fallSpeed * dt * 60;

      // Advance tokens
      for (final t in _tokens) {
        t.progress += delta;
      }

      // Remove exited tokens and mark target gone
      _tokens.removeWhere((t) {
        if (t.progress >= 1.0) {
          if (t.isTarget) _targetOnScreen = false;
          return true;
        }
        return false;
      });

      // Recompute lane heads (lowest progress = just spawned = closest to top)
      for (int l = 0; l < _kLanes; l++) {
        double minP = double.infinity;
        for (final t in _tokens) {
          if (t.lane == l && t.progress < minP) minP = t.progress;
        }
        _laneHead[l] = minP == double.infinity ? -1.0 : minP;
      }

      _maybeSpawn();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Hint timer — reveals the "next slot" highlight after a delay
  // ─────────────────────────────────────────────────────────────────────────────

  void _startHintTimer() {
    _hintTimer?.cancel();
    _hintVisible = false;
    _hintTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _hintVisible = true);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FIX 1 — Overlap-free spawning
  // ─────────────────────────────────────────────────────────────────────────────

  void _maybeSpawn() {
    // Find lanes that have room at the top (head token has already fallen
    // at least _kLaneGap, or lane is empty).
    final openLanes = <int>[];
    for (int l = 0; l < _kLanes; l++) {
      final head = _laneHead[l];
      if (head < 0 || head >= _kLaneGap) openLanes.add(l);
    }
    if (openLanes.isEmpty) return;

    // Shuffle open lanes so we don't always favour lane 0
    openLanes.shuffle(_rng);

    // Decide what to spawn in the first open lane
    final lane = openLanes.first;

    // If target is not on screen, spawn it now
    if (!_targetOnScreen) {
      _spawnToken(lane, isTarget: true);
      return;
    }

    // Otherwise spawn a decoy in a random open lane
    if (openLanes.length >= 1) {
      _spawnToken(openLanes[_rng.nextInt(openLanes.length)], isTarget: false);
    }
  }

  void _spawnToken(int lane, {required bool isTarget}) {
    final String text;
    if (isTarget) {
      text = _puzzle.solution[_nextSlot];
      _targetOnScreen = true;
    } else {
      final target = _puzzle.solution[_nextSlot];
      final choices = _decoyPool.where((d) => d != target).toList();
      if (choices.isEmpty) return;
      text = choices[_rng.nextInt(choices.length)];
    }

    _tokens.add(_FallingToken(
      token:    text,
      lane:     lane,
      isTarget: isTarget,
      id:       _tokenIdCtr++,
      progress: 0.0,
    ));
    _laneHead[lane] = 0.0;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Data
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _loadPuzzles() async {
    try {
      final raw  = await rootBundle.loadString('assets/survival_puzzles_easy.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = (data['puzzles'] as List)
          .map((j) => _StreamPuzzle.fromJson(j as Map<String, dynamic>))
          .toList();
      setState(() {
        _allPuzzles = list;
        _loading    = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Game flow
  // ─────────────────────────────────────────────────────────────────────────────

  void _startGame() {
    // FIX 2: build a fresh shuffled queue of all puzzle indices
    final indices = List<int>.generate(_allPuzzles.length, (i) => i)..shuffle(_rng);
    setState(() {
      _gameStarted    = true;
      _gameOver       = false;
      _lives          = 3;
      _score          = 0;
      _streak         = 0;
      _bestStreak     = 0;
      _queriesDone    = 0;
      _fallSpeed      = _kFallStart;
      _puzzleQueue    = indices;
      _puzzleQueueIdx = 0;
      _tokens.clear();
      _lastTick       = Duration.zero;
      _laneHead.fillRange(0, _kLanes, -1.0);
    });
    _lastXpEarned = 0;
    _loadNextPuzzle();
  }

  void _loadNextPuzzle() {
    // FIX 2: pull next from queue, wrap only when all used
    if (_puzzleQueueIdx >= _puzzleQueue.length) {
      _puzzleQueue.shuffle(_rng);
      _puzzleQueueIdx = 0;
    }
    final puzzle = _allPuzzles[_puzzleQueue[_puzzleQueueIdx++]];

    // Decoy pool: other puzzles' tokens
    final pool = <String>[];
    for (final p in _allPuzzles) {
      if (p.id != puzzle.id) pool.addAll(p.solution);
    }
    pool.shuffle(_rng);

    setState(() {
      _puzzle          = puzzle;
      _nextSlot        = 0;
      _caught          = List.filled(puzzle.solution.length, null);
      _decoyPool       = pool;
      _tokens.clear();
      _targetOnScreen  = false;
      _laneHead.fillRange(0, _kLanes, -1.0);
    });
    _startHintTimer();
  }

  // FIX 5: skip current query
  void _skipQuery() {
    if (_gameOver || !_gameStarted) return;
    _sfx.miss(); // audible feedback that skip was used
    setState(() {
      _streak = 0; // reset streak as a small penalty
    });
    _loadNextPuzzle();
  }

  void _onTapToken(_FallingToken token, Offset globalPos) {
    if (_gameOver || !_gameStarted) return;
    if (_nextSlot >= _puzzle.solution.length) return; // transitioning to next puzzle

    final expected = _puzzle.solution[_nextSlot];

    if (token.token == expected) {
      HapticFeedback.lightImpact();
      _sfx.hit();

      final newStreak = _streak + 1;
      final bonus     = newStreak >= 5 ? (newStreak ~/ 5) * 50 : 0;

      setState(() {
        _caught[_nextSlot] = token.token;
        _nextSlot++;
        _hintVisible   = false;
        _streak        = newStreak;
        _bestStreak    = max(_bestStreak, newStreak);
        _score        += 100 + bonus;
        _tokens.remove(token);
        _targetOnScreen = false;
        _showBurst     = true;
        _burstPos      = globalPos;
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _showBurst = false);
      });

      if (_nextSlot < _puzzle.solution.length) _startHintTimer();

      if (_nextSlot >= _puzzle.solution.length) {
        _onQueryComplete();
      }
    } else {
      HapticFeedback.heavyImpact();
      _sfx.miss();
      _shakeCtrl.forward(from: 0);
      _flashCtrl.forward(from: 0).then((_) => _flashCtrl.reverse());

      setState(() {
        _lives--;
        _streak = 0;
        _tokens.remove(token);
      });

      if (_lives <= 0) _endGame();
    }
  }

  void _onQueryComplete() {
    _sfx.done();
    setState(() {
      _queriesDone++;
      _score      += 200;
      _fallSpeed   = min(_kFallMax, _fallSpeed + _kFallStep);
      _queryComplete = true;
    });
    // Show the "QUERY COMPLETE" card overlay for 900 ms, then load next puzzle
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _gameOver) return;
      setState(() => _queryComplete = false);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_gameOver) _loadNextPuzzle();
      });
    });
  }

  void _endGame() {
    setState(() => _gameOver = true);
    _saveStreamXp();
  }

  /// Converts the run score → XP, persists locally, syncs to Supabase,
  /// then notifies the parent shell so the HUD updates immediately.
  Future<void> _saveStreamXp() async {
    // XP formula: score / 40 + queriesDone * 3 + bestStreak, clamped 1–999
    final xpEarned = ((_score / 40).floor() + _queriesDone * 3 + _bestStreak)
        .clamp(1, 999);

    // ── Local ──
    final prefs = await SharedPreferences.getInstance();
    final currentXp = prefs.getInt('local_xp') ?? 0;
    await prefs.setInt('local_xp', currentXp + xpEarned);

    // ── Supabase (fire-and-forget) ──
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.rpc('increment_xp', params: {
          'uid':    user.id,
          'amount': xpEarned,
        });
      } catch (_) { /* offline — local already saved */ }
    }

    // ── Notify shell ──
    if (mounted) widget.onXpGained?.call(xpEarned);
    _lastXpEarned = xpEarned;
  }

  int _lastXpEarned = 0;

  // FIX 3: correct HP bar order
  String get _hpAsset {
    if (_lives >= 3) return _A.hpFull;
    if (_lives == 2) return _A.hpHalf;
    if (_lives == 1) return _A.hpLastHit;
    return _A.hpLastHit; // 0 lives → game over triggers before this renders
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0B1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF34D399))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1A),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(_A.streamBg, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(.55))),

          AnimatedBuilder(
            animation: _flashAnim,
            builder: (_, __) => Opacity(
              opacity: _flashAnim.value * 0.30,
              child: Container(color: Colors.red),
            ),
          ),

          SafeArea(
            child: _gameOver
                ? _buildGameOver()
                : !_gameStarted
                    ? _buildStartScreen()
                    : _buildGame(),
          ),

          if (_showBurst)
            Positioned(
              left: _burstPos.dx - 30,
              top:  _burstPos.dy - 30,
              child: IgnorePointer(child: _BurstWidget(color: const Color(0xFF34D399))),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Start screen
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildStartScreen() {
    return Column(
      children: [
        _buildTopBar(showStats: false),
        const Spacer(),
        Column(
          children: [
            Image.asset(_A.runeIcon, width: 64, height: 64),
            const SizedBox(height: 16),
            const Text('SQL STREAM', style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w900,
              letterSpacing: 4, color: Colors.white,
            )),
            const SizedBox(height: 8),
            Text(
              'Catch the right tokens.\nBuild the query. Beat the stream.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(.6), height: 1.6),
            ),
            const SizedBox(height: 28),
            _buildHowToPlay(),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: _startGame,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF34D399)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF34D399).withOpacity(.45),
                    blurRadius: 24, offset: const Offset(0, 8),
                  )],
                ),
                child: const Text('START STREAM', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900,
                  letterSpacing: 2, color: Colors.white,
                )),
              ),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildHowToPlay() {
    const steps = [
      ('💧', 'Tokens fall in 4 lanes from the top'),
      ('👆', 'Tap the correct token for the next blank'),
      ('❌', 'Wrong tap = lose a life (3 lives total)'),
      ('⏭️', 'Use SKIP if you want the next query'),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Column(
        children: steps.map((s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Text(s.$1, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(s.$2,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(.7)))),
          ]),
        )).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Main game
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildGame() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shakeAnim.value, 0), child: child),
      child: Column(
        children: [
          _buildTopBar(showStats: true),
          const SizedBox(height: 4),
          Center(child: Image.asset(_hpAsset, height: 54, fit: BoxFit.contain)),
          const SizedBox(height: 4),
          _buildQueryDisplay(),
          const SizedBox(height: 6),
          // FIX 5: Skip button below query
          _buildSkipButton(),
          const SizedBox(height: 4),
          Expanded(child: _buildLanes()),
        ],
      ),
    );
  }

  // ─── Top bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar({required bool showStats}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Image.asset(_A.runeIcon, width: 22, height: 22),
          const SizedBox(width: 6),
          const Text('SQL STREAM', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w900,
            color: Colors.white, letterSpacing: 1.5,
          )),
          const Spacer(),
          if (showStats) ...[
            Flexible(
              child: _StatChip(icon: _A.starIcon, value: '$_score', color: const Color(0xFFFFD700)),
            ),
            const SizedBox(width: 8),
            _StatChip(icon: _A.fireIcon, value: '$_streak', color: const Color(0xFFF97316)),
          ],
        ],
      ),
    );
  }

  // ─── FIX 5: Skip button ───────────────────────────────────────────────────────

  Widget _buildSkipButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: GestureDetector(
          onTap: _skipQuery,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⏭️', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text('SKIP', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(.55), letterSpacing: 1,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Query display ────────────────────────────────────────────────────────────

  Widget _buildQueryDisplay() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Stack(
        children: [
          // ── Main card ──────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _queryComplete
                  ? const Color(0xFF052E16).withOpacity(.9)
                  : const Color(0xFF0D0B1A).withOpacity(.75),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _queryComplete
                    ? const Color(0xFF34D399).withOpacity(.9)
                    : const Color(0xFF34D399).withOpacity(.25 + .15 * _pulseCtrl.value),
                width: _queryComplete ? 2 : 1.5,
              ),
              boxShadow: _queryComplete
                  ? [BoxShadow(color: const Color(0xFF34D399).withOpacity(.35), blurRadius: 18, spreadRadius: 2)]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Image.asset(_A.lightningIcon, width: 14, height: 14),
                  const SizedBox(width: 5),
                  Expanded(child: Text(
                    _puzzle.title.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(.45), letterSpacing: 1.2),
                  )),
                  Text('Q${_queriesDone}', style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF34D399),
                  )),
                ]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: List.generate(_puzzle.solution.length, (i) {
                    final caught   = _caught[i];
                    final isNext   = i == _nextSlot;
                    final isDone   = caught != null;
                    final showHint = isNext && _hintVisible;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDone
                            ? _tokenColor(caught!).withOpacity(.12)
                            : showHint
                                ? const Color(0xFF34D399).withOpacity(.08 + .06 * _pulseCtrl.value)
                                : Colors.white.withOpacity(.04),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: isDone
                              ? _tokenColor(caught!).withOpacity(.5)
                              : showHint
                                  ? const Color(0xFF34D399).withOpacity(.5 + .3 * _pulseCtrl.value)
                                  : Colors.white.withOpacity(.1),
                          width: showHint ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        isDone ? caught! : '?',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: isDone ? _tokenColor(caught!) : Colors.white24,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // ── "QUERY COMPLETE" overlay ──────────────────────────────────
          if (_queryComplete)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _queryComplete ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF052E16).withOpacity(.88),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(_A.checkIcon, width: 28, height: 28),
                      const SizedBox(height: 6),
                      const Text(
                        'QUERY COMPLETE',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900,
                          color: Color(0xFF34D399), letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+200 pts',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: const Color(0xFF34D399).withOpacity(.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Lanes ────────────────────────────────────────────────────────────────────

  Widget _buildLanes() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final laneW  = constraints.maxWidth / _kLanes;
      final height = constraints.maxHeight;

      return Stack(
        children: [
          // Lane dividers
          ...List.generate(_kLanes - 1, (i) => Positioned(
            left: laneW * (i + 1), top: 0, bottom: 0,
            child: Container(width: 1, color: Colors.white.withOpacity(.04)),
          )),

          // Falling tokens
          ..._tokens.map((ft) {
            final cx     = laneW * ft.lane + laneW / 2;
            final top    = ft.progress * height;
            // Clamp nextSlot — during the 700ms gap between query complete and
            // loadNextPuzzle the slot index may equal solution.length.
            final safeSlot = _nextSlot.clamp(0, _puzzle.solution.length - 1);
            return Positioned(
              key: ValueKey(ft.id),
              left:  cx - laneW * 0.43,
              top:   top,
              width: laneW * 0.86,
              child: GestureDetector(
                onTapDown: (d) => _onTapToken(ft, d.globalPosition),
                child: _FallingTokenWidget(
                  token:     ft.token,
                  isNext:    _hintVisible && ft.token == _puzzle.solution[safeSlot],
                  pulseCtrl: _pulseCtrl,
                ),
              ),
            );
          }),

          // Bottom danger line
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.red.withOpacity(.3),
                Colors.transparent,
              ])),
            ),
          ),
        ],
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FIX 4: Game over with custom icon stat rows
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildGameOver() {
    final rank = _score >= 6000 ? 'S'
               : _score >= 3500 ? 'A'
               : _score >= 1800 ? 'B'
               : _score >= 600  ? 'C'
               : 'D';

    final rankColor = const {
      'S': Color(0xFFFFD700),
      'A': Color(0xFF7C3AED),
      'B': Color(0xFF22D3EE),
      'C': Color(0xFF4ADE80),
      'D': Color(0xFF9CA3AF),
    }[rank]!;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const SizedBox(height: 36),
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: rankColor, width: 3),
              color: rankColor.withOpacity(.1),
            ),
            child: Center(child: Text(rank, style: TextStyle(
              fontSize: 48, fontWeight: FontWeight.w900, color: rankColor,
            ))),
          ),
          const SizedBox(height: 14),
          const Text('STREAM ENDED', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900,
            color: Colors.white, letterSpacing: 3,
          )),
          const SizedBox(height: 4),
          Text('The flow overwhelmed you.',
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(.45))),
          const SizedBox(height: 24),

          // Stats card with custom icons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(.08)),
            ),
            child: Column(children: [
              _iconStatRow(_A.starIcon,      'Score',        '$_score',           const Color(0xFFFFD700)),
              _divider(),
              _iconStatRow(_A.checkIcon,     'Queries done', '$_queriesDone',     const Color(0xFF4ADE80)),
              _divider(),
              _iconStatRow(_A.fireIcon,      'Best streak',  '$_bestStreak',      const Color(0xFFF97316)),
              _divider(),
              _iconStatRow(_A.chainIcon,     'Lives left',   '$_lives / 3',       const Color(0xFFEC4899)),
              _divider(),
              _iconStatRow(_A.lightningIcon, 'XP earned',    '+$_lastXpEarned',   const Color(0xFFA78BFA)),
            ]),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: _startGame,
            child: Container(
              width: double.infinity, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF34D399)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF34D399).withOpacity(.4),
                  blurRadius: 20, offset: const Offset(0, 6),
                )],
              ),
              alignment: Alignment.center,
              child: const Text('🔄  PLAY AGAIN', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900,
                letterSpacing: 2, color: Colors.white,
              )),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity, height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(.1)),
              ),
              alignment: Alignment.center,
              child: Text('BACK TO MENU', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(.6), letterSpacing: 1.5,
              )),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _iconStatRow(String iconPath, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: iconColor.withOpacity(.25)),
          ),
          child: Image.asset(iconPath, fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(.65))),
        const Spacer(),
        Text(value, style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
        )),
      ]),
    );
  }

  Widget _divider() => Divider(color: Colors.white.withOpacity(.06), height: 1);

  // ─────────────────────────────────────────────────────────────────────────────
  // Start screen
  // ─────────────────────────────────────────────────────────────────────────────

}

// ─────────────────────────────────────────────────────────────────────────────
// Falling token widget
// ─────────────────────────────────────────────────────────────────────────────

class _FallingTokenWidget extends StatelessWidget {
  final String token;
  final bool   isNext;
  final AnimationController pulseCtrl;

  const _FallingTokenWidget({
    required this.token,
    required this.isNext,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = _tokenColor(token);
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, __) {
        final glow = isNext ? (0.4 + 0.4 * pulseCtrl.value) : 0.22;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(isNext ? .18 : .07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(glow),
              width: isNext ? 2.0 : 1.2,
            ),
            boxShadow: [BoxShadow(
              color: color.withOpacity(isNext ? .35 * pulseCtrl.value : .08),
              blurRadius: isNext ? 14 : 4,
            )],
          ),
          child: Center(child: Text(
            token,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color.withOpacity(isNext ? 1.0 : 0.72),
              letterSpacing: 0.2,
            ),
          )),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String icon;
  final String value;
  final Color  color;
  const _StatChip({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Image.asset(icon, width: 14, height: 14),
      const SizedBox(width: 4),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 72),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Burst animation
// ─────────────────────────────────────────────────────────────────────────────

class _BurstWidget extends StatefulWidget {
  final Color color;
  const _BurstWidget({required this.color});
  @override State<_BurstWidget> createState() => _BurstWidgetState();
}

class _BurstWidgetState extends State<_BurstWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  late Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
      ..forward();
    _scale   = Tween<double>(begin: 0.3, end: 2.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.9, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Opacity(
      opacity: _opacity.value,
      child: Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.color, width: 2),
            color: widget.color.withOpacity(.15),
          ),
        ),
      ),
    ),
  );
}