import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point called from HomeScreen
// ─────────────────────────────────────────────────────────────────────────────

void showSyncModal(
  BuildContext context, {
  required Map<String, dynamic> progress,
  required int xp,
  required void Function(String username) onSynced,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SyncModal(progress: progress, xp: xp, onSynced: onSynced),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal widget
// ─────────────────────────────────────────────────────────────────────────────

enum _SyncMode { login, register }

class _SyncModal extends StatefulWidget {
  final Map<String, dynamic> progress;
  final int xp;
  final void Function(String username) onSynced;

  const _SyncModal({
    required this.progress,
    required this.xp,
    required this.onSynced,
  });

  @override
  State<_SyncModal> createState() => _SyncModalState();
}

class _SyncModalState extends State<_SyncModal> {
  final _sb = Supabase.instance.client;

  _SyncMode _mode = _SyncMode.login;

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  bool _showPassword = false;
  bool _isLoading    = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  String? _validateFields() {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final username = _usernameCtrl.text.trim();

    if (email.isEmpty)    return 'Please enter your email.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Please enter a valid email address.';
    }
    if (password.isEmpty) return 'Please enter your password.';
    if (password.length < 6) return 'Password must be at least 6 characters.';

    if (_mode == _SyncMode.register) {
      if (username.isEmpty) return 'Please choose a username.';
      if (username.length < 3) return 'Username must be at least 3 characters.';
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        return 'Username can only contain letters, numbers, and underscores.';
      }
    }
    return null;
  }

  String _friendlyError(Object e) {
    // AuthApiException / AuthException both expose a .message
    if (e is AuthException) {
      final code = e.statusCode?.toString() ?? '';
      final msg  = e.message.toLowerCase();
      debugPrint('[SyncModal] AuthException code=$code message=${e.message}');

      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid_credentials') ||
          msg.contains('email not confirmed') ||
          code == '400') {
        return 'Incorrect email or password. Please try again.';
      }
      if (msg.contains('user already registered') ||
          msg.contains('email already')) {
        return 'An account with this email already exists. Try logging in.';
      }
      if (msg.contains('rate limit') || msg.contains('too many')) {
        return 'Too many attempts. Please wait a moment and try again.';
      }
      // Surface the raw Supabase message so we can diagnose unknowns
      return 'Auth error: ${e.message}';
    }

    if (e is PostgrestException) {
      final msg = e.message.toLowerCase();
      debugPrint('[SyncModal] PostgrestException message=${e.message}');
      if (msg.contains('username') && msg.contains('unique')) {
        return 'That username is already taken. Please choose another.';
      }
      if (msg.contains('username_format')) {
        return 'Username must be 3+ characters (letters, numbers, underscores only).';
      }
      return 'Database error: ${e.message}';
    }

    final msg = e.toString().toLowerCase();
    debugPrint('[SyncModal] Unknown error: $e');
    if (msg.contains('username already taken')) {
      return 'That username is already taken. Please choose another.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Network error. Please check your connection and try again.';
    }
    return 'Error: $e';
  }

  // ── Auth actions ───────────────────────────────────────────────────────────

  Future<void> _submit() async {
    _clearError();
    final validationError = _validateFields();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_mode == _SyncMode.login) {
        await _doLogin();
      } else {
        await _doRegister();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _doLogin() async {
    // Real Supabase sign-in — throws AuthException on bad credentials
    final response = await _sb.auth.signInWithPassword(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    final user = response.user;
    if (user == null) throw Exception('Login failed — no user returned.');

    // Fetch the username from profiles
    final profile = await _sb
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .maybeSingle();

    final username = (profile?['username'] as String?) ?? 'Player';

    if (mounted) {
      Navigator.pop(context);
      widget.onSynced(username);
    }
  }

  Future<void> _doRegister() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final username = _usernameCtrl.text.trim();

    // Check username availability before creating account
    final taken = await _sb.rpc('is_username_taken', params: {'p_username': username});
    if (taken == true) {
      throw Exception('Username already taken');
    }

    // Sign up — Supabase trigger will create the profile row with the username
    final response = await _sb.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );

    debugPrint('[SyncModal] signUp user=${response.user?.id} session=${response.session}');

    final user = response.user;
    if (user == null) throw Exception('Registration failed — no user returned.');

    // If email confirmation is ON, session will be null — tell the user to verify
    if (response.session == null) {
      if (mounted) {
        Navigator.pop(context);
        _showConfirmationBanner();
      }
      return;
    }

    // Email confirmation is OFF (instant login) — proceed normally
    // Small delay for the DB trigger to fire
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      Navigator.pop(context);
      widget.onSynced(username);
    }
  }

  void _showConfirmationBanner() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1838),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: kPurpleLight.withOpacity(.3)),
        ),
        content: const Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: Colors.greenAccent, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Check your email to confirm your account, then log in.',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1838),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ──────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Icon + title ─────────────────────────────────────────────
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: kButtonGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: kPurpleMid.withOpacity(.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _mode == _SyncMode.login ? 'Welcome Back' : 'Create Account',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _mode == _SyncMode.login
                  ? 'Sign in to sync your progress across devices.'
                  : 'Create an account to save and sync your progress.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // ── Mode toggle ──────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _ModeTab(
                    label: 'Log In',
                    selected: _mode == _SyncMode.login,
                    onTap: () {
                      setState(() {
                        _mode = _SyncMode.login;
                        _error = null;
                      });
                    },
                  ),
                  _ModeTab(
                    label: 'Register',
                    selected: _mode == _SyncMode.register,
                    onTap: () {
                      setState(() {
                        _mode = _SyncMode.register;
                        _error = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Username field (register only) ───────────────────────────
            if (_mode == _SyncMode.register) ...[
              _InputField(
                controller: _usernameCtrl,
                hint: 'Username',
                icon: Icons.person_rounded,
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 12),
            ],

            // ── Email ────────────────────────────────────────────────────
            _InputField(
              controller: _emailCtrl,
              hint: 'Email',
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _clearError(),
            ),
            const SizedBox(height: 12),

            // ── Password ─────────────────────────────────────────────────
            _InputField(
              controller: _passwordCtrl,
              hint: 'Password',
              icon: Icons.lock_rounded,
              obscureText: !_showPassword,
              onChanged: (_) => _clearError(),
              suffix: IconButton(
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),

            // ── Error message ─────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
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

            const SizedBox(height: 20),

            // ── Submit button ─────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: EdgeInsets.zero,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _isLoading ? null : kButtonGradient,
                    color: _isLoading ? Colors.white12 : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white70),
                          )
                        : Text(
                            _mode == _SyncMode.login ? 'Sign In' : 'Create Account',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Switch mode hint ──────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _mode = _mode == _SyncMode.login
                        ? _SyncMode.register
                        : _SyncMode.login;
                    _error = null;
                  });
                },
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.white38),
                    children: [
                      TextSpan(
                        text: _mode == _SyncMode.login
                            ? "Don't have an account? "
                            : 'Already have an account? ',
                      ),
                      TextSpan(
                        text: _mode == _SyncMode.login ? 'Register' : 'Log In',
                        style: TextStyle(
                          color: kPurpleLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? kButtonGradient : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white38,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final Widget? suffix;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: kBgDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kPurpleLight.withOpacity(.5), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}