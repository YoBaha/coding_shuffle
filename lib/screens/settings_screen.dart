import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/music_service.dart';
import 'change_password_screen.dart';
import 'delete_account_dialog.dart';
import 'support_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onSignedOut;
  final VoidCallback? onAccountDeleted;
  const SettingsScreen({super.key, this.onSignedOut, this.onAccountDeleted});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _music = MusicService.instance;
  final _sb = Supabase.instance.client;
  late bool _musicEnabled;

  // Redeem code
  final _codeController = TextEditingController();
  bool _redeemLoading = false;

  @override
  void initState() {
    super.initState();
    _musicEnabled = _music.enabled;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _toggleMusic(bool value) async {
    await _music.setEnabled(value);
    if (mounted) setState(() => _musicEnabled = value);
  }

  // ── Redeem code ───────────────────────────────────────────────────────────

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _redeemLoading = true);
    await Future.delayed(const Duration(milliseconds: 600)); // feels intentional
    setState(() => _redeemLoading = false);

    _codeController.clear();
    _showCodeSnack(valid: false);
  }

  void _showCodeSnack({required bool valid}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1530),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: valid ? Colors.greenAccent : Colors.redAccent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              valid ? 'Code redeemed!' : 'Invalid code. Please try again.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1838),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'Are you sure you want to sign out? Your progress will still be saved to your account.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sb.auth.signOut();
              if (mounted) Navigator.pop(context);
              widget.onSignedOut?.call();
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteAccountDialog(onAccountDeleted: widget.onAccountDeleted),
    );
  }

  void _shareApp() {
    const shareText =
        '🎮 Check out Code Shuffle Duel — the app that makes learning SQL addictive! '
        'Solve puzzles, climb the ranks, and master SQL for free. '
        'Download it now 👇\n'
        'https://play.google.com/store/apps/details?id=com.example.code_shuffle';
    Clipboard.setData(const ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1530),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
            SizedBox(width: 10),
            Text(
              'Copied to clipboard! Ready to share',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSuggestion() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'codingshuffleduel@gmail.com',
      queryParameters: {
        'subject': 'Code Shuffle Duel — Feature Suggestion',
        'body': "Here's what I'd like to add to this app:\n\n",
      },
    );
    if (!await launchUrl(uri)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app.')),
      );
    }
  }

  Future<void> _reportBug() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'codingshuffleduel@gmail.com',
      queryParameters: {
        'subject': 'Code Shuffle Duel — Bug Report',
        'body': "Hello, here's the bug/problem I encountered:\n\n",
      },
    );
    if (!await launchUrl(uri)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app.')),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _sb.auth.currentUser != null;

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

              // ── Redeem Code ──────────────────────────────────────────────
              _sectionLabel('REDEEM CODE'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1838),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kPurpleMid.withOpacity(.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Have a code? Enter it below to unlock exclusive rewards.',
                      style: TextStyle(fontSize: 12, color: Colors.white38, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: 2,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ENTER CODE',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(.2),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 2,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(.05),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(.08),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: kPurpleMid.withOpacity(.5),
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.confirmation_number_rounded,
                                color: kPurpleLight.withOpacity(.6),
                                size: 18,
                              ),
                            ),
                            onSubmitted: (_) => _redeemCode(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _redeemLoading ? null : _redeemCode,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: _redeemLoading ? null : kButtonGradient,
                              color: _redeemLoading ? Colors.white.withOpacity(.05) : null,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _redeemLoading
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: kPurpleMid.withOpacity(.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            alignment: Alignment.center,
                            child: _redeemLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white38,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Sound & Music ────────────────────────────────────────────
              _sectionLabel('SOUND & MUSIC'),
              const SizedBox(height: 10),
              _SettingsCard(
                children: [
                  _ToggleRow(
                    icon: Icons.music_note_rounded,
                    iconColor: kPurpleLight,
                    title: 'Background Music',
                    subtitle: _musicEnabled ? 'Music is playing' : 'Music is off',
                    value: _musicEnabled,
                    onChanged: _toggleMusic,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Account ───────────────────────────────────────────────────
              _sectionLabel('ACCOUNT'),
              const SizedBox(height: 10),
              _SettingsCard(
                children: [
                  _ActionRow(
                    icon: Icons.lock_reset_rounded,
                    iconColor: kPurpleLight,
                    title: 'Change Password',
                    subtitle: 'Update your login password',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                    ),
                  ),
                  if (isLoggedIn) ...[
                    _divider(),
                    _ActionRow(
                      icon: Icons.logout_rounded,
                      iconColor: Colors.redAccent,
                      title: 'Sign Out',
                      subtitle: 'Log out of your account',
                      onTap: _showSignOutDialog,
                    ),
                    _divider(),
                    _ActionRow(
                      icon: Icons.delete_forever_rounded,
                      iconColor: Colors.redAccent,
                      title: 'Delete Account',
                      subtitle: 'Permanently delete your account and all data',
                      onTap: _showDeleteAccountDialog,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // ── Assistance ────────────────────────────────────────────────
              _sectionLabel('ASSISTANCE'),
              const SizedBox(height: 10),
              _SettingsCard(
                children: [
                  _ActionRow(
                    icon: Icons.share_rounded,
                    iconColor: kPurpleLight,
                    title: 'Share the App',
                    subtitle: 'Copy a message to share with friends',
                    onTap: _shareApp,
                  ),
                  _divider(),
                  _ActionRow(
                    icon: Icons.lightbulb_outline_rounded,
                    iconColor: const Color(0xFFFFD166),
                    title: 'Send a Suggestion',
                    subtitle: 'Got an idea? We\'d love to hear it',
                    onTap: _sendSuggestion,
                  ),
                  _divider(),
                  _ActionRow(
                    icon: Icons.bug_report_outlined,
                    iconColor: Colors.orangeAccent,
                    title: 'Report a Bug',
                    subtitle: 'Something not working? Let us know',
                    onTap: _reportBug,
                  ),
                  _divider(),
                  _ActionRow(
                    icon: Icons.favorite_rounded,
                    iconColor: const Color(0xFFFF6B6B),
                    title: 'Support Us',
                    subtitle: 'Watch an ad to support development',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SupportScreen()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── About ─────────────────────────────────────────────────────
              _sectionLabel('ABOUT'),
              const SizedBox(height: 10),
              _SettingsCard(
                children: [
                  _InfoRow(
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.white38,
                    title: 'Version',
                    value: '2.5.6',
                  ),
                  _divider(),
                  _ActionRow(
                    icon: Icons.description_outlined,
                    iconColor: Colors.white38,
                    title: 'Terms of Service',
                    subtitle: 'Read our terms and conditions',
                    onTap: () => _launchUrl('https://codingshuffleduel.vercel.app/terms'),
                  ),
                  _divider(),
                  _ActionRow(
                    icon: Icons.people_outline_rounded,
                    iconColor: Colors.white38,
                    title: 'About Us',
                    subtitle: 'Learn about the team behind the app',
                    onTap: () => _launchUrl('https://codingshuffleduel.vercel.app/about'),
                  ),
                  _divider(),
                  _ActionRow(
                    icon: Icons.shield_outlined,
                    iconColor: Colors.white38,
                    title: 'Privacy Policy',
                    subtitle: 'How we handle your data',
                    onTap: () => _launchUrl('https://codingshuffleduel.vercel.app/privacy'),
                  ),
                  _divider(),
                  _ActionRow(
                    icon: Icons.map_outlined,
                    iconColor: Colors.white38,
                    title: 'Future Updates',
                    subtitle: 'See what\'s coming next',
                    onTap: () => _launchUrl('https://codingshuffleduel.vercel.app/roadmap'),
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

// ── Reusable card container ───────────────────────────────────────────────────

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

// ── Toggle row ────────────────────────────────────────────────────────────────

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
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
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

// ── Tappable action row ───────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
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
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

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
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Text(value, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}