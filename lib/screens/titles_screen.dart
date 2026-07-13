// lib/screens/titles_screen.dart
//
// Full-screen titles browser:
//  • Shows all titles grouped by rarity
//  • Locked titles appear dimmed with a lock icon
//  • Tap an unlocked title to equip/unequip
//  • Active equipped title is highlighted

import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/titles_service.dart';
import '../services/survival_service.dart';
import 'package:code_shuffle/modals/modals.dart';

class TitlesScreen extends StatefulWidget {
  final Set<String> unlockedIds;
  final String? equippedId;
  final void Function(String? titleId) onEquip;

  const TitlesScreen({
    super.key,
    required this.unlockedIds,
    required this.equippedId,
    required this.onEquip,
  });

  @override
  State<TitlesScreen> createState() => _TitlesScreenState();
}

class _TitlesScreenState extends State<TitlesScreen> {
  final _service = TitlesService();
  List<GameTitle> _all = [];
  String? _equippedId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _equippedId = widget.equippedId;
    _loadTitles();
  }

  Future<void> _loadTitles() async {
    final titles = await _service.loadAllTitles();
    if (mounted) setState(() { _all = titles; _loading = false; });
  }

  Future<void> _toggleEquip(GameTitle title) async {
    final newId = _equippedId == title.id ? null : title.id;
    setState(() => _equippedId = newId);
    await _service.equipTitle(newId);
    widget.onEquip(newId);
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final unlockedCount = widget.unlockedIds.length;
    final total = _all.length;
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
                const Text(
                  'TITLES',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$unlockedCount / $total unlocked',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          // Progress pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kPurpleMid.withOpacity(.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kPurpleMid.withOpacity(.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech_rounded, color: kGold, size: 14),
                const SizedBox(width: 6),
                Text(
                  '$unlockedCount / $total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kGold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    // Sort: unlocked first, then by rarity (epic → common)
    final rarityOrder = {
      TitleRarity.epic: 0,
      TitleRarity.rare: 1,
      TitleRarity.uncommon: 2,
      TitleRarity.common: 3,
    };
    final sorted = [..._all]..sort((a, b) {
        final aUnlocked = widget.unlockedIds.contains(a.id) ? 0 : 1;
        final bUnlocked = widget.unlockedIds.contains(b.id) ? 0 : 1;
        if (aUnlocked != bUnlocked) return aUnlocked.compareTo(bUnlocked);
        return rarityOrder[a.rarity]!.compareTo(rarityOrder[b.rarity]!);
      });

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: sorted.length,
      itemBuilder: (_, i) => _TitleCard(
        title: sorted[i],
        isUnlocked: widget.unlockedIds.contains(sorted[i].id),
        isEquipped: _equippedId == sorted[i].id,
        onTap: widget.unlockedIds.contains(sorted[i].id)
            ? () => _toggleEquip(sorted[i])
            : null,
      ),
    );
  }
}

// ── TitleCard ─────────────────────────────────────────────────────────────────

class _TitleCard extends StatelessWidget {
  final GameTitle title;
  final bool isUnlocked;
  final bool isEquipped;
  final VoidCallback? onTap;

  const _TitleCard({
    required this.title,
    required this.isUnlocked,
    required this.isEquipped,
    this.onTap,
  });

  Color get _rarityColor {
    switch (title.rarity) {
      case TitleRarity.common:   return Colors.white54;
      case TitleRarity.uncommon: return const Color(0xFF22C55E);
      case TitleRarity.rare:     return const Color(0xFF3B82F6);
      case TitleRarity.epic:     return const Color(0xFFA855F7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEquipped ? _rarityColor.withOpacity(.1) : kBgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEquipped
                ? _rarityColor.withOpacity(.55)
                : isUnlocked
                    ? _rarityColor.withOpacity(.2)
                    : Colors.white.withOpacity(.05),
            width: isEquipped ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Rarity label
            Text(
              title.rarity.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: isUnlocked ? _rarityColor : Colors.white.withOpacity(.18),
              ),
            ),
            // Title name
            Text(
              title.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isUnlocked ? Colors.white : Colors.white30,
                height: 1.2,
              ),
            ),
            // Description
            Text(
              title.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isUnlocked ? Colors.white38 : Colors.white.withOpacity(.15),
                height: 1.4,
              ),
            ),
            // Status tag
            if (isUnlocked)
              Text(
                isEquipped ? '✓ EQUIPPED' : 'TAP TO EQUIP',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: isEquipped ? _rarityColor : Colors.white24,
                ),
              )
            else
              Text(
                'LOCKED',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Colors.white.withOpacity(.18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}