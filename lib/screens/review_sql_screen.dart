import 'package:flutter/material.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SQL Review Screen — zero-to-hero guide derived from the puzzle curriculum
// ─────────────────────────────────────────────────────────────────────────────

class ReviewSqlScreen extends StatefulWidget {
  const ReviewSqlScreen({super.key});

  @override
  State<ReviewSqlScreen> createState() => _ReviewSqlScreenState();
}

class _ReviewSqlScreenState extends State<ReviewSqlScreen>
    with TickerProviderStateMixin {
  late AnimationController _ambientCtrl;
  int _selectedSection = 0;

  static const _sections = [
    _SqlSection(
      id: 'what',
      icon: 'assets/images/brain_icon.png',
      title: 'What is SQL?',
      color: Color(0xFF9B6DFF),
      lessons: [
        _Lesson(
          title: 'SQL in plain English',
          body:
              'SQL (Structured Query Language) is how you talk to a database. '
              'Think of a database as a collection of spreadsheets called *tables*. '
              'SQL lets you ask questions like "show me all users" or '
              '"how many orders were placed today?" — and the database answers you.',
          example: null,
          tip: 'Every puzzle in this app is a real SQL question. '
              'Once you learn the patterns here, you\'ll be ready to play.',
        ),
        _Lesson(
          title: 'A table looks like this',
          body:
              'Imagine a table called `users`. It has rows (one per user) '
              'and columns (name, email, role …). SQL queries work on these tables.',
          example: _TableExample(
            tableName: 'users',
            columns: ['id', 'name', 'email', 'role'],
            rows: [
              ['1', 'Alice', 'alice@mail.com', 'admin'],
              ['2', 'Bob', 'bob@mail.com', 'user'],
              ['3', 'Carol', 'carol@mail.com', 'user'],
            ],
          ),
          tip: null,
        ),
      ],
    ),
    _SqlSection(
      id: 'select',
      icon: 'assets/images/sql_book_icon.png',
      title: 'SELECT & FROM',
      color: Color(0xFF4DA6FF),
      lessons: [
        _Lesson(
          title: 'Get all rows',
          body:
              '`SELECT *` means "give me every column". '
              '`FROM users` says which table to look at. '
              'Together they fetch every row in the table.',
          example: _CodeExample(
            sql: 'SELECT * FROM users',
            result: 'Returns every column of every user row.',
          ),
          tip: '* is called a wildcard — it means "everything".',
        ),
        _Lesson(
          title: 'Get a specific column',
          body:
              'Replace `*` with a column name to get only that column. '
              'This is useful when tables have dozens of columns and you only need one.',
          example: _CodeExample(
            sql: 'SELECT username FROM users',
            result: 'Returns only the username column.',
          ),
          tip: null,
        ),
        _Lesson(
          title: 'Get multiple columns',
          body:
              'List column names separated by commas to pick exactly what you need.',
          example: _CodeExample(
            sql: 'SELECT name, email FROM customers',
            result: 'Returns only name and email columns.',
          ),
          tip: 'Order matters — columns appear in the order you write them.',
        ),
        _Lesson(
          title: 'Rename a column with AS',
          body:
              '`AS` lets you give a column a friendlier name in the result. '
              'The original table is unchanged — this only affects what you see.',
          example: _CodeExample(
            sql: 'SELECT price AS cost FROM products',
            result: 'price column appears as "cost" in the output.',
          ),
          tip: null,
        ),
      ],
    ),
    _SqlSection(
      id: 'where',
      icon: 'assets/images/lightning_icon.png',
      title: 'WHERE — Filtering',
      color: Color(0xFF3DFF8F),
      lessons: [
        _Lesson(
          title: 'Filter rows with WHERE',
          body:
              '`WHERE` adds a condition. Only rows where the condition is TRUE '
              'are returned. Everything else is ignored.',
          example: _CodeExample(
            sql: "SELECT * FROM products WHERE price > 100",
            result: 'Only products costing more than 100.',
          ),
          tip: 'Common operators: > < >= <= = !=',
        ),
        _Lesson(
          title: 'Exact text match',
          body:
              'For text (strings) use single quotes around the value. '
              '`=` checks for an exact match.',
          example: _CodeExample(
            sql: "SELECT * FROM users WHERE role = 'admin'",
            result: 'Only rows where role is exactly "admin".',
          ),
          tip: 'Always use single quotes for text values, not double quotes.',
        ),
        _Lesson(
          title: 'Not equal: !=',
          body:
              '`!=` means "is not equal to". '
              'Useful for excluding a category.',
          example: _CodeExample(
            sql: "SELECT * FROM users WHERE status != 'inactive'",
            result: 'Every user who is NOT inactive.',
          ),
          tip: null,
        ),
        _Lesson(
          title: 'Combine conditions: AND / OR',
          body:
              '`AND` means both conditions must be true. '
              '`OR` means at least one must be true.',
          example: _CodeExample(
            sql: "SELECT * FROM orders\nWHERE status = 'shipped'\nAND total > 200",
            result: 'Shipped orders worth more than 200.',
          ),
          tip: 'AND is stricter than OR — it filters more rows out.',
        ),
        _Lesson(
          title: 'Pattern matching with LIKE',
          body:
              '`LIKE` with `%` lets you match partial strings. '
              '`%` is a wildcard meaning "any characters here".',
          example: _CodeExample(
            sql: "SELECT * FROM users\nWHERE email LIKE '%@gmail.com'",
            result: 'All users with a Gmail address.',
          ),
          tip: '% at the start means "anything before". % at the end means "anything after".',
        ),
      ],
    ),
    _SqlSection(
      id: 'sort',
      icon: 'assets/images/stats_icon.png',
      title: 'ORDER BY & LIMIT',
      color: Color(0xFFFFD060),
      lessons: [
        _Lesson(
          title: 'Sort results',
          body:
              '`ORDER BY` sorts your results by a column. '
              '`ASC` = lowest to highest (default). `DESC` = highest to lowest.',
          example: _CodeExample(
            sql: 'SELECT * FROM products ORDER BY price ASC',
            result: 'Products from cheapest to most expensive.',
          ),
          tip: 'You can ORDER BY any column, even one you didn\'t SELECT.',
        ),
        _Lesson(
          title: 'Limit the number of rows',
          body:
              '`LIMIT` cuts the result to N rows. Combine with ORDER BY to get "top N" results.',
          example: _CodeExample(
            sql: 'SELECT * FROM products\nORDER BY price DESC\nLIMIT 5',
            result: 'The 5 most expensive products.',
          ),
          tip: 'This is the most common pattern for leaderboards, top lists, etc.',
        ),
      ],
    ),
    _SqlSection(
      id: 'aggregate',
      icon: 'assets/images/star_icon.png',
      title: 'Aggregate Functions',
      color: Color(0xFFFF6B6B),
      lessons: [
        _Lesson(
          title: 'COUNT — how many rows?',
          body:
              '`COUNT(*)` counts every row. It\'s a function — the parentheses are required.',
          example: _CodeExample(
            sql: 'SELECT COUNT(*) FROM orders',
            result: 'A single number: the total number of orders.',
          ),
          tip: 'COUNT(*) counts rows including NULLs. COUNT(column) skips NULLs.',
        ),
        _Lesson(
          title: 'SUM, AVG — totals & averages',
          body:
              '`SUM` adds up all values in a column. `AVG` calculates the average.',
          example: _CodeExample(
            sql: "SELECT SUM(total) FROM orders\nWHERE status = 'completed'\n\nSELECT AVG(score) AS average_score\nFROM quiz_results",
            result: 'Total revenue from completed orders. / Mean score.',
          ),
          tip: 'These are called aggregate functions — they collapse many rows into one value.',
        ),
        _Lesson(
          title: 'GROUP BY — aggregate per category',
          body:
              '`GROUP BY` splits the table into groups and runs the aggregate '
              'function on each group separately.',
          example: _CodeExample(
            sql: 'SELECT category, COUNT(*)\nFROM products\nGROUP BY category',
            result: 'One row per category, showing how many products are in it.',
          ),
          tip: 'Every column in SELECT that is NOT an aggregate must appear in GROUP BY.',
        ),
        _Lesson(
          title: 'HAVING — filter groups',
          body:
              '`WHERE` filters individual rows before grouping. '
              '`HAVING` filters groups after `GROUP BY` runs. '
              'It can use aggregate functions; `WHERE` cannot.',
          example: _CodeExample(
            sql: 'SELECT category, COUNT(*)\nFROM products\nGROUP BY category\nHAVING COUNT(*) > 5',
            result: 'Only categories with more than 5 products.',
          ),
          tip: 'Rule of thumb: use WHERE before GROUP BY, HAVING after.',
        ),
      ],
    ),
    _SqlSection(
      id: 'joins',
      icon: 'assets/images/chain_icon.png',
      title: 'JOINs',
      color: Color(0xFFFF9F43),
      lessons: [
        _Lesson(
          title: 'Why do we JOIN?',
          body:
              'Data is often split across multiple tables. '
              'A `users` table and an `orders` table might be linked by a shared `user_id`. '
              '`JOIN` stitches them together into one result.',
          example: null,
          tip: 'The column linking two tables is called a foreign key.',
        ),
        _Lesson(
          title: 'INNER JOIN — only matching rows',
          body:
              '`INNER JOIN` returns rows where both tables have a matching value. '
              'If a user has no orders, they won\'t appear.',
          example: _CodeExample(
            sql: 'SELECT users.name, orders.total\nFROM users\nINNER JOIN orders\nON users.id = orders.user_id',
            result: 'Name + order total, only for users who have at least one order.',
          ),
          tip: 'ON specifies which columns link the two tables.',
        ),
        _Lesson(
          title: 'LEFT JOIN — keep all left rows',
          body:
              '`LEFT JOIN` keeps every row from the first (left) table. '
              'If there\'s no match on the right, those columns come back as NULL.',
          example: _CodeExample(
            sql: 'SELECT users.name, orders.total\nFROM users\nLEFT JOIN orders\nON users.id = orders.user_id',
            result: 'All users — even those with no orders (total will be NULL).',
          ),
          tip: 'Use LEFT JOIN when you want "all X, and their Y if they have one".',
        ),
        _Lesson(
          title: 'Table aliases',
          body:
              'Long table names get tedious. Use `AS` (or just a space) to give them short aliases.',
          example: _CodeExample(
            sql: 'SELECT u.name, o.total\nFROM users u\nJOIN orders o ON u.id = o.user_id\nWHERE o.total > 500',
            result: 'Same as INNER JOIN but written with short aliases u and o.',
          ),
          tip: null,
        ),
      ],
    ),
    _SqlSection(
      id: 'subquery',
      icon: 'assets/images/rune_icon.png',
      title: 'Subqueries',
      color: Color(0xFFE056FD),
      lessons: [
        _Lesson(
          title: 'A query inside a query',
          body:
              'A subquery is a full SQL query nested inside parentheses '
              'inside another query. The inner query runs first, '
              'then its result is used by the outer query.',
          example: _CodeExample(
            sql: 'SELECT * FROM products\nWHERE price > (\n  SELECT AVG(price) FROM products\n)',
            result: 'Products that cost more than the average price.',
          ),
          tip: 'The inner query (AVG) runs first, returns a number, then the outer query filters with it.',
        ),
        _Lesson(
          title: 'IN with a subquery',
          body:
              '`IN` checks whether a value is in a list. '
              'The list can be generated by a subquery.',
          example: _CodeExample(
            sql: "SELECT name FROM users\nWHERE id IN (\n  SELECT user_id FROM orders\n  WHERE total > 500\n)",
            result: 'Names of users who placed at least one large order.',
          ),
          tip: 'Think of IN as "is this value in the list that the subquery returns?".',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = _sections[_selectedSection];

    return Scaffold(
      backgroundColor: kBgDark,
      body: Stack(
        children: [
          // Background
          Container(decoration: const BoxDecoration(gradient: kBgGradient)),
          CustomPaint(painter: _GridPainterReview(), size: Size.infinite),
          AnimatedBuilder(
            animation: _ambientCtrl,
            builder: (_, __) {
              final t = _ambientCtrl.value;
              return Positioned(
                top: -60, left: -40, right: -40,
                child: Container(
                  height: 320,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: 0.8,
                      colors: [
                        section.color.withOpacity(.15 + .07 * t),
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
                _buildHeader(context),
                _buildSectionTabs(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _buildLessons(section, key: ValueKey(section.id)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(.08)),
              ),
              child: Image.asset('assets/images/rune_icon.png', width: 16, height: 16),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF9B6DFF), Color(0xFFFFD060)],
                ).createShader(b),
                child: const Text(
                  'SQL REVIEW',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
                ),
              ),
              const Text('From zero to query', style: TextStyle(fontSize: 11, color: Colors.white38)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF9B6DFF).withOpacity(.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF9B6DFF).withOpacity(.3)),
            ),
            child: Text(
              '${_selectedSection + 1}/${_sections.length}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9B6DFF)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section tab pills ──────────────────────────────────────────────────────

  Widget _buildSectionTabs() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _sections.length,
        itemBuilder: (_, i) {
          final s = _sections[i];
          final active = i == _selectedSection;
          return GestureDetector(
            onTap: () => setState(() => _selectedSection = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? s.color.withOpacity(.2) : Colors.white.withOpacity(.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? s.color.withOpacity(.6) : Colors.white.withOpacity(.07),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(s.icon, width: 16, height: 16),
                  const SizedBox(width: 5),
                  Text(
                    s.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      color: active ? s.color : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Lessons list ───────────────────────────────────────────────────────────

  Widget _buildLessons(_SqlSection section, {required Key key}) {
    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      physics: const BouncingScrollPhysics(),
      children: [
        // Section intro badge
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [section.color.withOpacity(.18), section.color.withOpacity(.06)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: section.color.withOpacity(.3)),
          ),
          child: Row(
            children: [
              Image.asset(section.icon, width: 40, height: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: section.color, letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${section.lessons.length} lessons',
                      style: TextStyle(fontSize: 11, color: section.color.withOpacity(.6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...section.lessons.asMap().entries.map((e) => _buildLessonCard(e.key + 1, e.value, section.color)),
      ],
    );
  }

  Widget _buildLessonCard(int num, _Lesson lesson, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top accent strip
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withOpacity(.2)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lesson number + title
                  Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '$num',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lesson.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Body text — handle *italic* and `code` inline
                  _RichBody(text: lesson.body),
                  // Code example
                  if (lesson.example != null) ...[
                    const SizedBox(height: 12),
                    if (lesson.example is _CodeExample)
                      _buildCodeExample(lesson.example as _CodeExample, accent)
                    else if (lesson.example is _TableExample)
                      _buildTableExample(lesson.example as _TableExample),
                  ],
                  // Tip
                  if (lesson.tip != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: kGold.withOpacity(.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kGold.withOpacity(.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lesson.tip!,
                              style: TextStyle(fontSize: 11, color: kGold.withOpacity(.9), height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeExample(_CodeExample ex, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // SQL block
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0A1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withOpacity(.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('SQL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: accent, letterSpacing: 1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SqlHighlight(sql: ex.sql),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Result label
        Row(
          children: [
            Image.asset('assets/images/check_icon.png', width: 12, height: 12),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ex.result,
                style: const TextStyle(fontSize: 11, color: Colors.white38, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTableExample(_TableExample ex) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              ex.tableName,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 1.5),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: ex.columns.map((c) => Expanded(
                child: Text(c, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF9B6DFF))),
              )).toList(),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ...ex.rows.map((row) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              children: row.map((cell) => Expanded(
                child: Text(cell, style: const TextStyle(fontSize: 10, color: Colors.white60)),
              )).toList(),
            ),
          )),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SQL syntax highlighter (simple keyword colouring)
// ─────────────────────────────────────────────────────────────────────────────

class _SqlHighlight extends StatelessWidget {
  final String sql;
  const _SqlHighlight({required this.sql});

  static const _keywords = {
    'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'NOT', 'IN', 'LIKE',
    'ORDER', 'BY', 'ASC', 'DESC', 'LIMIT', 'GROUP', 'HAVING',
    'JOIN', 'INNER', 'LEFT', 'RIGHT', 'OUTER', 'ON', 'AS',
    'COUNT', 'SUM', 'AVG', 'MIN', 'MAX', 'DISTINCT',
    'INSERT', 'UPDATE', 'DELETE', 'CREATE', 'DROP', 'TABLE',
  };

  @override
  Widget build(BuildContext context) {
    final lines = sql.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final spans = <TextSpan>[];
        // tokenise on whitespace but preserve spacing
        final words = line.split(RegExp(r'(?<=\s)|(?=\s)'));
        for (final word in words) {
          final trimmed = word.trim().toUpperCase();
          Color color;
          if (_keywords.contains(trimmed)) {
            color = const Color(0xFF9B6DFF); // purple for keywords
          } else if (word.trim().startsWith("'") || word.trim().endsWith("'")) {
            color = const Color(0xFF3DFF8F); // green for strings
          } else if (RegExp(r'^\d+$').hasMatch(word.trim())) {
            color = const Color(0xFFFFD060); // gold for numbers
          } else if (word.trim().startsWith('(') || word.trim().startsWith(')')) {
            color = const Color(0xFFFF9F43); // orange for parens
          } else {
            color = Colors.white70;
          }
          spans.add(TextSpan(
            text: word,
            style: TextStyle(
              color: color,
              fontFamily: 'monospace',
              fontSize: 12.5,
              fontWeight: _keywords.contains(trimmed) ? FontWeight.w700 : FontWeight.w400,
            ),
          ));
        }
        return RichText(text: TextSpan(children: spans));
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rich body text — renders `code` and *italic* inline markers
// ─────────────────────────────────────────────────────────────────────────────

class _RichBody extends StatelessWidget {
  final String text;
  const _RichBody({required this.text});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'`([^`]+)`|\*([^*]+)\*');
    int last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, m.start),
          style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.6),
        ));
      }
      if (m.group(1) != null) {
        // backtick = code style
        spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(
            fontSize: 12.5, color: Color(0xFF9B6DFF),
            fontFamily: 'monospace', fontWeight: FontWeight.w700,
            height: 1.6,
          ),
        ));
      } else {
        // asterisk = italic
        spans.add(TextSpan(
          text: m.group(2),
          style: const TextStyle(
            fontSize: 13, color: Colors.white,
            fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, height: 1.6,
          ),
        ));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last),
        style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.6),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _SqlSection {
  final String id;
  final String icon;
  final String title;
  final Color color;
  final List<_Lesson> lessons;
  const _SqlSection({
    required this.id, required this.icon, required this.title,
    required this.color, required this.lessons,
  });
}

class _Lesson {
  final String title;
  final String body;
  final dynamic example; // _CodeExample | _TableExample | null
  final String? tip;
  const _Lesson({required this.title, required this.body, required this.example, this.tip});
}

class _CodeExample {
  final String sql;
  final String result;
  const _CodeExample({required this.sql, required this.result});
}

class _TableExample {
  final String tableName;
  final List<String> columns;
  final List<List<String>> rows;
  const _TableExample({required this.tableName, required this.columns, required this.rows});
}

// ─────────────────────────────────────────────────────────────────────────────
// Background grid
// ─────────────────────────────────────────────────────────────────────────────

class _GridPainterReview extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.018)
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
  bool shouldRepaint(_GridPainterReview _) => false;
}