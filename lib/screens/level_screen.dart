import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:code_shuffle/modals/modals.dart';
import 'game_screen.dart';

class LevelScreen extends StatefulWidget {
  final PuzzleLevel level;
  final Map<String, PuzzleProgress> progress;
  final void Function(Map<String, PuzzleProgress> updatedProgress, int xpGained) onProgressUpdated;

  const LevelScreen({
    super.key,
    required this.level,
    required this.progress,
    required this.onProgressUpdated,
  });

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  late Map<String, PuzzleProgress> _progress;

  @override
  void initState() {
    super.initState();
    _progress = Map.from(widget.progress);
  }

  Future<void> _openPuzzle(Puzzle puzzle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          puzzle:   puzzle,
          level:    widget.level,
          progress: _progress,
          onCompleted: (updatedProgress, xpGained) {
            setState(() => _progress = updatedProgress);
            widget.onProgressUpdated(updatedProgress, xpGained);
          },
        ),
      ),
    );
  }

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
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: widget.level.puzzles.length,
                  itemBuilder: (_, i) => _buildPuzzleTile(widget.level.puzzles[i], i),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
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
                  widget.level.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '${widget.level.puzzles.length} puzzles · ${widget.level.xpPerStar} XP per star',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleTile(Puzzle puzzle, int index) {
    final prog  = _progress[puzzle.id];
    final stars = prog?.stars ?? 0;
    final done  = stars > 0;

    return GestureDetector(
      onTap: () => _openPuzzle(puzzle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: done
                ? kGold.withOpacity(.3)
                : Colors.white.withOpacity(.06),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(gradient: levelGradient(widget.level.id)),
              ),
              const SizedBox(width: 16),
              // Number
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: done ? levelGradient(widget.level.id) : null,
                  color: done ? null : Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: done ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      puzzle.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (prog?.bestTime != null)
                      Text(
                        'Best: ${prog!.bestTime}s',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                  ],
                ),
              ),
              // Stars
              Row(
                children: List.generate(3, (i) => Icon(
                  i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i < stars ? kGold : Colors.white24,
                  size: 18,
                )),
              ),
              const SizedBox(width: 12),
              Icon(
                done
                    ? Icons.replay_rounded
                    : Icons.play_arrow_rounded,
                color: done ? Colors.white38 : kPurpleLight,
                size: 22,
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}