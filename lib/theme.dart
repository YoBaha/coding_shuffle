import 'package:flutter/material.dart';

// ── Fonts ───────────────────────────────────────────────────────────────────
// GAME TITLE → Orbitron · UI (buttons/labels/headers) → Bebas Neue
// SQL / code → JetBrains Mono · Descriptions/body → Inter
class AppFonts {
  static const title = 'Orbitron';
  static const ui = 'BebasNeue';
  static const code = 'JetBrainsMono';
  static const body = 'Inter';
}

const TextStyle kTitleStyle = TextStyle(
  fontFamily: AppFonts.title,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.5,
);

const TextStyle kUiLabelStyle = TextStyle(
  fontFamily: AppFonts.ui,
  fontWeight: FontWeight.w400,
  letterSpacing: 1.2,
);

const TextStyle kCodeStyle = TextStyle(
  fontFamily: AppFonts.code,
  fontWeight: FontWeight.w500,
);

const TextStyle kBodyStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontWeight: FontWeight.w400,
);

// ── Brand colours (from the logo) ──────────────────────────────────────────
const Color kBgDark      = Color(0xFF0D0B1A); // deep dark purple-black
const Color kBgCard      = Color(0xFF1A1530); // card surface
const Color kPurpleLight = Color(0xFFB06EF5); // logo purple highlight
const Color kPurpleMid   = Color(0xFF7C3AED); // mid purple
const Color kPurpleDark  = Color(0xFF4C1D95); // deep purple
const Color kGold        = Color(0xFFF59E0B); // logo gold/amber
const Color kGoldLight   = Color(0xFFFBBF24);
const Color kCyan        = Color(0xFF22D3EE); // code token cyan
const Color kGreen       = Color(0xFF22C55E); // beginner green
const Color kBlue        = Color(0xFF3B82F6); // intermediate blue
const Color kAdvPurple   = Color(0xFFA855F7); // advanced purple
// ── Gradients ───────────────────────────────────────────────────────────────
const LinearGradient kBgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF0D0B1A), Color(0xFF1A0A2E), Color(0xFF0D0B1A)],
);
const LinearGradient kPurpleGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kPurpleMid, kPurpleDark],
);
const LinearGradient kGoldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kGoldLight, kGold],
);
const LinearGradient kButtonGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
);
const LinearGradient kGoldButtonGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
);
LinearGradient levelGradient(String levelId) {
  switch (levelId) {
    case 'beginner':
      return const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF22C55E)]);
    case 'intermediate':
      return const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]);
    case 'advanced':
      return const LinearGradient(colors: [Color(0xFF7E22CE), Color(0xFFA855F7)]);
    default:
      return kPurpleGradient;
  }
}
// ── Theme ───────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBgDark,
    colorScheme: const ColorScheme.dark(
      primary: kPurpleMid,
      secondary: kGold,
      surface: kBgCard,
    ),
    fontFamily: AppFonts.body, // Inter as the app-wide default (descriptions/body)
    useMaterial3: true,
  );
}