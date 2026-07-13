// lib/widgets/title_unlock_overlay.dart
//
// Animated overlay shown when the player earns a new title.
// Usage:
//   TitleUnlockOverlay.show(context, titles: [title1, title2]);

import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/titles_service.dart';

class TitleUnlockOverlay extends StatefulWidget {
  final List<GameTitle> titles;
  final VoidCallback onDismiss;

  const TitleUnlockOverlay({
    super.key,
    required this.titles,
    required this.onDismiss,
  });

  static Future<void> show(BuildContext context, {required List<GameTitle> titles}) async {
    if (titles.isEmpty) return;
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(.7),
      builder: (_) => TitleUnlockOverlay(
        titles: titles,
        onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    );
  }

  @override
  State<TitleUnlockOverlay> createState() => _TitleUnlockOverlayState();
}

class _TitleUnlockOverlayState extends State<TitleUnlockOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<double> _glow;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _glow  = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _nextOrDismiss() {
    if (_currentIndex < widget.titles.length - 1) {
      _ctrl.reverse().then((_) {
        if (mounted) {
          setState(() => _currentIndex++);
          _ctrl.forward();
        }
      });
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.titles[_currentIndex];
    final rarityColor = _rarityColor(title.rarity);

    return Center(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: GestureDetector(
            onTap: _nextOrDismiss,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF12101E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: rarityColor.withOpacity(.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: rarityColor.withOpacity(.25),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Eyebrow
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: rarityColor.withOpacity(.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: rarityColor.withOpacity(.3)),
                    ),
                    child: Text(
                      'TITLE UNLOCKED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: rarityColor,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Big emoji
                  AnimatedBuilder(
                    animation: _glow,
                    builder: (_, child) => Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rarityColor.withOpacity(.1),
                        boxShadow: [
                          BoxShadow(
                            color: rarityColor.withOpacity(.4 * _glow.value),
                            blurRadius: 30,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(title.emoji, style: const TextStyle(fontSize: 42)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Rarity badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: rarityColor.withOpacity(.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      title.rarity.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: rarityColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title name
                  Text(
                    title.label,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Description
                  Text(
                    title.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Dismiss / Next button
                  GestureDetector(
                    onTap: _nextOrDismiss,
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [rarityColor.withOpacity(.8), rarityColor],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: rarityColor.withOpacity(.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.titles.length > 1 && _currentIndex < widget.titles.length - 1
                            ? 'NEXT (${_currentIndex + 1}/${widget.titles.length})'
                            : 'EQUIP IN PROFILE',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _rarityColor(TitleRarity rarity) {
    switch (rarity) {
      case TitleRarity.common:   return Colors.white60;
      case TitleRarity.uncommon: return const Color(0xFF22C55E);
      case TitleRarity.rare:     return const Color(0xFF3B82F6);
      case TitleRarity.epic:     return const Color(0xFFA855F7);
    }
  }
}