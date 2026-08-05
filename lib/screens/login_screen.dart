import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/credential_store.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  final _bio = BiometricService();
  bool _appleAvailable = false;
  bool _bioAvailable = false;
  String? _savedEmail;
  String _bioLabel = '生物辨識';
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    _initBiometric();
    _initAppleAvailability();
  }

  Future<void> _initAppleAvailability() async {
    final available = await AuthService.isAppleSignInAvailable();
    if (mounted) setState(() => _appleAvailable = available);
  }

  Future<void> _appleSignIn() async {
    if (_busy) return;
    final auth = context.read<AuthService>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.signInWithApple();
      // AuthGate reacts to the auth state change.
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      // Cancelling isn't an error worth showing.
      setState(
        () => _error = e.code == AuthorizationErrorCode.canceled
            ? null
            : 'Apple 登入失敗：${e.message}',
      );
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _initBiometric() async {
    final store = context.read<CredentialStore>();
    final auth = context.read<AuthService>();

    // If the user just chose 登出, don't immediately ask them to sign back
    // in. The button stays available for when they actually want it.
    final deliberateSignOut = auth.justSignedOut;
    auth.justSignedOut = false;

    final hasCreds = await store.hasCredentials();
    if (!hasCreds) return;
    final available = await _bio.isAvailable();
    final label = await _bio.methodLabel();
    final email = await store.savedEmail();
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _bioLabel = label;
      _savedEmail = email;
      if (email != null) _emailCtrl.text = email;
    });
    // Auto-prompt only on a fresh launch, never right after a sign-out.
    if (available && !deliberateSignOut && !_autoPrompted) {
      _autoPrompted = true;
      _biometricSignIn();
    }
  }

  Future<void> _biometricSignIn() async {
    if (_busy) return;
    final store = context.read<CredentialStore>();
    // Capture before the await so BuildContext isn't used across the gap.
    final auth = context.read<AuthService>();
    final ok = await _bio.authenticate();
    if (!ok || !mounted) return;

    final creds = await store.read();
    if (creds == null) {
      if (mounted) setState(() => _error = '找不到已儲存的登入資訊，請手動登入');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.signIn(creds.$1, creds.$2);
      // AuthGate reacts to the auth state change.
    } catch (e) {
      // Most likely the password was changed on another device — the stored
      // copy is now useless, so drop it rather than prompting forever.
      await store.clear();
      if (!mounted) return;
      setState(() {
        _bioAvailable = false;
        _error = '儲存的密碼已失效，請重新輸入密碼登入';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = '請輸入電子郵件與密碼');
      return;
    }
    if (_isSignUp && pw.length < 6) {
      setState(() => _error = '密碼至少需要 6 個字元');
      return;
    }
    if (_isSignUp && pw != _pwConfirmCtrl.text) {
      setState(() => _error = '兩次輸入的密碼不一致');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      if (_isSignUp) {
        await auth.signUp(email, pw);
      } else {
        await auth.signIn(email, pw);
      }
      // AuthGate reacts to the auth state change automatically.
    } catch (e) {
      setState(() => _error = AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignIn() async {
    if (_busy) return;
    final auth = context.read<AuthService>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.signInWithGoogle();
      // AuthGate reacts to the auth state change.
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      // Cancelling the account picker isn't an error worth showing.
      setState(
        () => _error = e.code == GoogleSignInExceptionCode.canceled
            ? null
            : 'Google 登入失敗：${e.description ?? e.code.name}',
      );
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '請先輸入電子郵件');
      return;
    }
    try {
      await context.read<AuthService>().sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已寄送重設密碼郵件至 $email')));
    } catch (e) {
      setState(() => _error = AuthService.messageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Icon(Icons.task_alt, size: 56, color: flaggedColor),
                  const SizedBox(height: 16),
                  const Text(
                    '待辦計畫',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp ? '建立帳號以同步你的待辦事項' : '登入以同步你的待辦事項',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: flaggedColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _busy ? null : _googleSignIn,
                      icon: const Icon(Icons.account_circle_outlined, size: 22),
                      label: const Text(
                        '使用 Google 帳號登入',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Required by App Store guideline 4.8 alongside Google.
                  if (_appleAvailable) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _busy ? null : _appleSignIn,
                        icon: const Icon(Icons.apple, size: 24),
                        label: const Text(
                          '使用 Apple 帳號登入',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '或使用電子郵件',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: _fieldDeco('電子郵件', Icons.email_outlined),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _pwCtrl,
                    obscureText: _obscure,
                    textInputAction: _isSignUp
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: (_) => _isSignUp ? null : _submit(),
                    decoration:
                        _fieldDeco(
                          _isSignUp ? '設定密碼' : '密碼',
                          Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                  ),

                  if (_isSignUp) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pwConfirmCtrl,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      decoration: _fieldDeco('確認密碼', Icons.lock_outline),
                    ),
                  ],

                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child: const Text(
                          '忘記密碼？',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: flaggedColor,
                        side: const BorderSide(color: flaggedColor, width: 1.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          : Text(
                              _isSignUp ? '註冊' : '登入',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  // Biometric sign-in, only once credentials have been saved.
                  if (_bioAvailable && !_isSignUp) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '或',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: flaggedColor,
                          side: const BorderSide(
                            color: flaggedColor,
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.fingerprint, size: 22),
                        label: Text(
                          '使用 $_bioLabel 登入',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _busy ? null : _biometricSignIn,
                      ),
                    ),
                    if (_savedEmail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _savedEmail!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSignUp ? '已經有帳號了？' : '還沒有帳號？',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                                _pwConfirmCtrl.clear();
                              }),
                        child: Text(
                          _isSignUp ? '登入' : '註冊',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: flaggedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: flaggedColor, width: 1.6),
    ),
  );
}
