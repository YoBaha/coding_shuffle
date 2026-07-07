import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/progress_service.dart';
import 'package:code_shuffle/modals/modals.dart';

/// Shows the Sync / Login bottom sheet.
/// Call via: showSyncModal(context, progress: _progress, xp: _xp, onSynced: ...)
Future<void> showSyncModal(
  BuildContext context, {
  required Map<String, PuzzleProgress> progress,
  required int xp,
  required void Function(String username) onSynced,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SyncSheet(
      progress: progress,
      xp: xp,
      onSynced: onSynced,
    ),
  );
}

class _SyncSheet extends StatefulWidget {
  final Map<String, PuzzleProgress> progress;
  final int xp;
  final void Function(String username) onSynced;

  const _SyncSheet({
    required this.progress,
    required this.xp,
    required this.onSynced,
  });

  @override
  State<_SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends State<_SyncSheet> {
  final _sb = Supabase.instance.client;
  final _progressService = ProgressService();

  bool _isLogin = true;
  bool _loading = false;
  String? _error;
  bool _synced = false;

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        await _sb.auth.signInWithPassword(
          email:    _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      } else {
        await _sb.auth.signUp(
          email:    _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          data:     {'username': _usernameCtrl.text.trim()},
        );
      }

      // Sync local progress to Supabase
      await _syncLocalProgress();

      // Fetch username to pass back
      final profile = await _progressService.fetchProfile();
final username = profile?['username'] as String? ??
    (_usernameCtrl.text.trim().isNotEmpty
        ? _usernameCtrl.text.trim()
        : _emailCtrl.text.split('@').first);

      if (mounted) {
        setState(() { _synced = true; _loading = false; });
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          widget.onSynced(username);
          Navigator.of(context).pop();
        }
      }
    } on AuthException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Something went wrong. Try again.'; _loading = false; });
    }
  }

  /// Push every locally-saved puzzle completion up to Supabase.
  Future<void> _syncLocalProgress() async {
    final user = _sb.auth.currentUser;
    if (user == null) return;

    for (final entry in widget.progress.entries) {
      final p = entry.value;
      if (p.stars == 0) continue;
      try {
        await _sb.from('puzzle_progress').upsert({
          'user_id':    user.id,
          'puzzle_id':  p.puzzleId,
          'level_id':   _levelIdForPuzzle(p.puzzleId),
          'stars':      p.stars,
          'best_time':  p.bestTime,
          'completed':  true,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,puzzle_id');
      } catch (_) {
        // Keep going — best-effort sync
      }
    }

    // Sync XP
    if (widget.xp > 0) {
      try {
        // Set XP directly (it's a fresh account or re-login)
        await _sb.from('profiles').upsert({
          'id':    user.id,
          'xp':    widget.xp,
          'level': (widget.xp / 100).floor() + 1,
        }, onConflict: 'id');
      } catch (_) {}
    }
  }

  /// Infer level_id from puzzle id prefix (b=beginner, i=intermediate, a=advanced)
  String _levelIdForPuzzle(String puzzleId) {
    if (puzzleId.startsWith('b')) return 'beginner';
    if (puzzleId.startsWith('i')) return 'intermediate';
    if (puzzleId.startsWith('a')) return 'advanced';
    return 'beginner';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1530),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: _synced
    ? _buildSuccessView()
    : SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: _buildFormView(),
      ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: kGoldGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_done_rounded, color: Colors.black, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Progress Synced!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your local progress has been saved to your account.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.white54),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFormView() {
return Column(
  mainAxisSize: MainAxisSize.max,
  crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle bar
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

        // Title
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: kPurpleGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Sync Your Progress',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Save your XP & stars across devices',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Tab toggle
        Container(
          decoration: BoxDecoration(
            color: kBgDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kPurpleMid.withOpacity(.3)),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _tabBtn('Log In', _isLogin, () => setState(() { _isLogin = true; _error = null; })),
              _tabBtn('Sign Up', !_isLogin, () => setState(() { _isLogin = false; _error = null; })),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (!_isLogin) ...[
          _field(controller: _usernameCtrl, label: 'Username', icon: Icons.person_outline),
          const SizedBox(height: 12),
        ],
        _field(
          controller: _emailCtrl,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _field(
          controller: _passwordCtrl,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: true,
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(.3)),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Submit
        GestureDetector(
          onTap: _loading ? null : _submit,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: kButtonGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: kPurpleMid.withOpacity(.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    _isLogin ? 'LOG IN & SYNC' : 'CREATE ACCOUNT & SYNC',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: () => setState(() { _isLogin = !_isLogin; _error = null; }),
            child: Text(
              _isLogin ? "Don't have an account? Sign up" : 'Already have an account? Log in',
              style: TextStyle(color: kPurpleLight.withOpacity(.8), fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          decoration: BoxDecoration(
            gradient: active ? kButtonGradient : null,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : Colors.white54,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kBgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPurpleMid.withOpacity(.3)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: kPurpleLight, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}