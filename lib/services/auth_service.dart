import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'google_auth_config.dart';

/// Thin wrapper around FirebaseAuth.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// GoogleSignIn.instance is a singleton, so initialization is shared
  /// process-wide between sign-in and Calendar sync.
  static bool _googleInitialized = false;

  static Future<void> ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: defaultTargetPlatform == TargetPlatform.android
          ? googleServerClientId
          : null,
    );
    _googleInitialized = true;
  }

  /// True when the account signed in through Google rather than a password.
  bool get isGoogleAccount =>
      _auth.currentUser?.providerData.any(
        (info) => info.providerId == 'google.com',
      ) ??
      false;

  bool get hasPasswordProvider =>
      _auth.currentUser?.providerData.any(
        (info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
      ) ??
      false;

  /// Signs in with Google, asking for the Calendar scope at the same time so
  /// syncing later needs no second consent screen.
  Future<void> signInWithGoogle() async {
    await ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: googleCalendarScopes,
    );
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: '無法取得 Google 憑證，請再試一次',
      );
    }
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  /// Links Google to the currently signed-in Firebase user. Linking—not
  /// signing in—is essential here: it preserves the uid and therefore keeps
  /// all existing tasks under the same Firestore account.
  Future<void> linkGoogleAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('尚未登入');
    if (isGoogleAccount) return;

    await ensureGoogleInitialized();
    // Always show the chooser so users do not accidentally link a previously
    // cached Google identity.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // The account chooser can still proceed when no cached session exists.
    }
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: googleCalendarScopes,
    );
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: '無法取得 Google 憑證，請再試一次',
      );
    }
    await user.linkWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    await user.reload();
  }

  /// Adds an email/password login to the current account while retaining the
  /// existing uid and task data. The email can differ from Apple's private
  /// relay address, provided it is not already used by another account.
  Future<void> linkEmailPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('尚未登入');
    if (hasPasswordProvider) return;
    await user.linkWithCredential(
      EmailAuthProvider.credential(email: email.trim(), password: password),
    );
    await user.reload();
  }

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  String? get email => _auth.currentUser?.email;
  bool get isSignedIn => _auth.currentUser != null;

  /// A linked account may have Apple/Google and a Firebase password at the
  /// same time. Password reset remains valid whenever the password provider
  /// is present.
  bool get canResetPassword => hasPasswordProvider;

  /// Emits on every sign-in / sign-out.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUp(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Set when the user signs out on purpose, so the login screen doesn't
  /// immediately prompt them to sign back in. Consumed by LoginScreen.
  bool justSignedOut = false;

  Future<void> signOut() async {
    justSignedOut = true;
    if (_googleInitialized) {
      // Clear the cached Google account too, otherwise the next sign-in
      // silently reuses it and the account picker never appears.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Non-fatal: the Firebase sign-out below is what actually matters.
      }
    }
    await _auth.signOut();
  }

  /// Whether Sign in with Apple can be offered on this device. Required by
  /// App Store guideline 4.8 wherever a third-party login is offered.
  static Future<bool> isAppleSignInAvailable() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return false;
    }
    try {
      return await SignInWithApple.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Signs in with Apple.
  ///
  /// Apple returns an identity token bound to a nonce: we send the SHA-256
  /// hash and hand Firebase the raw value, so a replayed token can't be
  /// accepted.
  Future<void> signInWithApple() async {
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: '無法取得 Apple 憑證，請再試一次',
      );
    }

    await _auth.signInWithCredential(
      OAuthProvider(
        'apple.com',
      ).credential(idToken: idToken, rawNonce: rawNonce),
    );
  }

  static String _randomNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Re-authenticates a Google account by running the picker again. Firebase
  /// requires a recent login before destructive operations like deletion.
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('尚未登入');
    await ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: '無法取得 Google 憑證，請再試一次',
      );
    }
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  /// True when the account signed in through Apple.
  bool get isAppleAccount =>
      _auth.currentUser?.providerData.any(
        (info) => info.providerId == 'apple.com',
      ) ??
      false;

  /// Re-authenticates an Apple account, and revokes the Apple token.
  ///
  /// Apple requires that deleting an account also revokes the Sign in with
  /// Apple grant, so the app stops appearing under the user's Apple ID. The
  /// authorization code needed for that is only issued by a fresh
  /// authorization, which is why revocation lives here.
  Future<void> reauthenticateWithApple() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('尚未登入');

    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email],
      nonce: hashedNonce,
    );
    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: '無法取得 Apple 憑證，請再試一次',
      );
    }

    await user.reauthenticateWithCredential(
      OAuthProvider(
        'apple.com',
      ).credential(idToken: idToken, rawNonce: rawNonce),
    );

    try {
      await _auth.revokeTokenWithAuthorizationCode(
        appleCredential.authorizationCode,
      );
    } catch (_) {
      // Revocation is best-effort: never block deletion of the account itself.
    }
  }

  /// Permanently deletes the Firebase Auth account. Call only after the user's
  /// cloud data has been removed and after a recent re-authentication.
  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }

  /// Re-authenticate with the current email + password. Used to prove account
  /// ownership before storing the password for biometric sign-in.
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('尚未登入');
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(cred);
  }

  /// Maps FirebaseAuthException codes to friendly error messages.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return '電子郵件格式不正確';
        case 'user-disabled':
          return '此帳號已被停用';
        case 'user-not-found':
          return '找不到此帳號';
        case 'wrong-password':
        case 'invalid-credential':
          return '電子郵件或密碼錯誤';
        case 'email-already-in-use':
          return '此電子郵件已被註冊';
        case 'credential-already-in-use':
        case 'account-exists-with-different-credential':
          return '這個登入方式已連結到另一個帳號，請改用其他帳號';
        case 'provider-already-linked':
          return '這個登入方式已經連結';
        case 'weak-password':
          return '密碼強度不足（至少 6 個字元）';
        case 'network-request-failed':
          return '網路連線失敗，請稍後再試';
        case 'too-many-requests':
          return '嘗試次數過多，請稍後再試';
        case 'operation-not-allowed':
          return '尚未啟用電子郵件登入，請稍後再試';
        default:
          return error.message ?? '發生錯誤，請稍後再試';
      }
    }
    return '發生錯誤，請稍後再試';
  }
}
