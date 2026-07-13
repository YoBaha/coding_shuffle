import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChangePasswordScreen
// ─────────────────────────────────────────────────────────────────────────────

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _sb = Supabase.instance.client;

  final _currentCtrl  = TextEditingController();
  final _newCtrl      = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;

  bool   _loading = false;
  bool   _success = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  String? _validate() {
    if (_currentCtrl.text.isEmpty) return 'Please enter your current password.';
    if (_newCtrl.text.isEmpty)     return 'Please enter a new password.';
    if (_newCtrl.text.length < 6)  return 'New password must be at least 6 characters.';
    if (_confirmCtrl.text != _newCtrl.text) return 'Passwords do not match.';
    if (_currentCtrl.text == _newCtrl.text) return 'New password must differ from the current one.';
    return null;
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) { setState(() => _error = err); return; }

    setState(() { _loading = true; _error = null; });

    try {
      // 1. Re-authenticate with the current password to verify it's correct
      final user = _sb.auth.currentUser;
      if (user?.email == null) throw Exception('No authenticated user found.');

      await _sb.auth.signInWithPassword(
        email:    user!.email!,
        password: _currentCtrl.text,
      );

      // 2. Update to the new password
      await _sb.auth.updateUser(
        UserAttributes(password: _newCtrl.text),
      );

      if (mounted) setState(() { _success = true; _loading = false; });

      // Auto-pop after a short celebration delay
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.of(context).pop();

    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      final friendly = msg.contains('invalid') || msg.contains('credentials')
          ? 'Current password is incorrect.'
          : 'Auth error: ${e.message}';
      setState(() { _error = friendly; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Something went wrong. Please try again.'; _loading = false; });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back + Title ──────────────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kPurpleMid.withOpacity(.2)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70, size: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Success state ─────────────────────────────────────────────
              if (_success) _buildSuccess(),

              // ── Form ──────────────────────────────────────────────────────
              if (!_success) ...[
                _sectionLabel('CURRENT PASSWORD'),
                const SizedBox(height: 10),
                _PasswordCard(
                  children: [
                    _PasswordField(
                      controller:  _currentCtrl,
                      label:       'Current Password',
                      icon:        Icons.lock_outline_rounded,
                      obscure:     _obscureCurrent,
                      onToggle:    () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _sectionLabel('NEW PASSWORD'),
                const SizedBox(height: 10),
                _PasswordCard(
                  children: [
                    _PasswordField(
                      controller:  _newCtrl,
                      label:       'New Password',
                      icon:        Icons.lock_reset_rounded,
                      obscure:     _obscureNew,
                      onToggle:    () => setState(() => _obscureNew = !_obscureNew),
                    ),
                    Divider(color: Colors.white.withOpacity(.06), height: 1, indent: 52),
                    _PasswordField(
                      controller:  _confirmCtrl,
                      label:       'Confirm New Password',
                      icon:        Icons.check_circle_outline_rounded,
                      obscure:     _obscureConfirm,
                      onToggle:    () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ],
                ),

                // ── Error banner ───────────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // ── Submit button ──────────────────────────────────────────
                GestureDetector(
                  onTap: _loading ? null : _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: _loading ? null : kButtonGradient,
                      color: _loading ? kPurpleMid.withOpacity(.3) : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _loading
                          ? []
                          : [
                              BoxShadow(
                                color: kPurpleMid.withOpacity(.4),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white70),
                          )
                        : const Text(
                            'UPDATE PASSWORD',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 1.6,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Success widget ──────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: kPurpleGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kPurpleMid.withOpacity(.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Password Updated!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your password has been changed successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ],
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Card wrapper (matches SettingsScreen style)
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordCard extends StatelessWidget {
  final List<Widget> children;
  const _PasswordCard({required this.children});

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
// Password field row with show/hide toggle
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String   label;
  final IconData icon;
  final bool     obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: TextField(
        controller:  controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText:  label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: Icon(icon, color: kPurpleLight, size: 19),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.white38,
              size: 19,
            ),
            onPressed: onToggle,
          ),
          border:          InputBorder.none,
          contentPadding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}