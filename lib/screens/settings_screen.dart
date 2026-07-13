import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/music_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _music = MusicService.instance;
  late bool _musicEnabled;

  @override
  void initState() {
    super.initState();
    _musicEnabled = _music.enabled;
  }

  Future<void> _toggleMusic(bool value) async {
    await _music.setEnabled(value);
    if (mounted) setState(() => _musicEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 28),

              // ── Sound & Music section ────────────────────────────────────
              _sectionLabel('SOUND & MUSIC'),
              const SizedBox(height: 10),

              _SettingsCard(
                children: [
                  _ToggleRow(
                    icon: Icons.music_note_rounded,
                    iconColor: kPurpleLight,
                    title: 'Background Music',
                    subtitle: _musicEnabled
                        ? 'Music is playing'
                        : 'Music is off',
                    value: _musicEnabled,
                    onChanged: _toggleMusic,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── About section ─────────────────────────────────────────────
              _sectionLabel('ABOUT'),
              const SizedBox(height: 10),

              _SettingsCard(
                children: [
                  _InfoRow(
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.white38,
                    title: 'Version',
                    value: '1.0.0',
                  ),
                  _divider(),
                  _InfoRow(
                    icon: Icons.code_rounded,
                    iconColor: Colors.white38,
                    title: 'Made with',
                    value: 'Flutter ❤️',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white38,
          letterSpacing: 2,
        ),
      );

  Widget _divider() => Divider(
        color: Colors.white.withOpacity(.06),
        height: 1,
        indent: 52,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable card container
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1838),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPurpleMid.withOpacity(.2)),
      ),
      child: Column(children: children),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle row (music on/off)
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kPurpleMid.withOpacity(.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kPurpleLight,
            activeTrackColor: kPurpleMid.withOpacity(.4),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info row (version, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}