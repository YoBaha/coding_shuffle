class StarsCriteria {
  final int three, two, one;
  const StarsCriteria({required this.three, required this.two, required this.one});
  factory StarsCriteria.fromJson(Map<String, dynamic> j) => StarsCriteria(
        three: int.parse(j['3'].toString()),
        two:   int.parse(j['2'].toString()),
        one:   int.parse(j['1'].toString()),
      );
  int starsForTime(int seconds) {
    if (seconds <= three) return 3;
    if (seconds <= two)   return 2;
    if (seconds <= one)   return 1;
    return 1; // always at least 1 on completion
  }
}
class Puzzle {
  final String id;
  final int order;
  final String title;
  final List<String> tokens;
  final List<String> solution;
  final String explanation;
  final String hint;
  final StarsCriteria starsCriteria;
  const Puzzle({
    required this.id,
    required this.order,
    required this.title,
    required this.tokens,
    required this.solution,
    required this.explanation,
    required this.hint,
    required this.starsCriteria,
  });
  factory Puzzle.fromJson(Map<String, dynamic> j) => Puzzle(
        id:           j['id'] as String,
        order:        j['order'] as int,
        title:        j['title'] as String,
        tokens:       List<String>.from(j['tokens']),
        solution:     List<String>.from(j['solution']),
        explanation:  j['explanation'] as String,
        hint:         j['hint'] as String,
        starsCriteria: StarsCriteria.fromJson(j['stars_criteria']),
      );
}
class PuzzleLevel {
  final String id;
  final String label;
  final String color;
  final int xpPerStar;
  final List<Puzzle> puzzles;
  const PuzzleLevel({
    required this.id,
    required this.label,
    required this.color,
    required this.xpPerStar,
    required this.puzzles,
  });
  factory PuzzleLevel.fromJson(Map<String, dynamic> j) => PuzzleLevel(
        id:        j['id'] as String,
        label:     j['label'] as String,
        color:     j['color'] as String,
        xpPerStar: j['xp_per_star'] as int,
        puzzles:   (j['puzzles'] as List).map((p) => Puzzle.fromJson(p)).toList(),
      );
}
// Local progress (saved via SharedPreferences)
class PuzzleProgress {
  final String puzzleId;
  int stars;
  int? bestTime; // seconds
  PuzzleProgress({required this.puzzleId, this.stars = 0, this.bestTime});
  Map<String, dynamic> toJson() => {
        'puzzleId': puzzleId,
        'stars': stars,
        'bestTime': bestTime,
      };
  factory PuzzleProgress.fromJson(Map<String, dynamic> j) => PuzzleProgress(
        puzzleId: j['puzzleId'] as String,
        stars:    j['stars'] as int,
        bestTime: j['bestTime'] as int?,
      );
}