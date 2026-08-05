import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the account password so the user can sign back in with biometrics
/// after an explicit 登出.
///
/// Security posture — this is a deliberate trade-off the user opts into:
///  * Values live in the platform secure store, never in SharedPreferences:
///    iOS Keychain, Android EncryptedSharedPreferences (AES-256 keyed by the
///    hardware-backed Keystore).
///  * On iOS the item is `first_unlock_this_device`, so it is never synced to
///    iCloud and is unreadable while the device is locked.
///  * Callers must pass a biometric check *before* calling [read]; nothing in
///    this class exposes the password without that gate.
///  * Cleared on disable, and whenever a stored password turns out to be
///    stale (e.g. changed on another device).
class CredentialStore {
  static const _kEmail = 'bio_email';
  static const _kPassword = 'bio_password';

  /// Web has no hardware-backed store worth trusting for this, and biometrics
  /// don't exist there either, so the feature is mobile-only.
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<bool> hasCredentials() async {
    if (!_supported) return false;
    try {
      return await _storage.read(key: _kEmail) != null &&
          await _storage.read(key: _kPassword) != null;
    } catch (e) {
      debugPrint('CredentialStore.hasCredentials failed: $e');
      return false;
    }
  }

  /// Email only — safe to show on the login screen as a hint.
  Future<String?> savedEmail() async {
    if (!_supported) return null;
    try {
      return await _storage.read(key: _kEmail);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String email, String password) async {
    if (!_supported) return;
    try {
      await _storage.write(key: _kEmail, value: email);
      await _storage.write(key: _kPassword, value: password);
    } catch (e) {
      debugPrint('CredentialStore.save failed: $e');
    }
  }

  /// Returns (email, password). Only call after a successful biometric check.
  Future<(String, String)?> read() async {
    if (!_supported) return null;
    try {
      final email = await _storage.read(key: _kEmail);
      final password = await _storage.read(key: _kPassword);
      if (email == null || password == null) return null;
      return (email, password);
    } catch (e) {
      debugPrint('CredentialStore.read failed: $e');
      return null;
    }
  }

  Future<void> clear() async {
    if (!_supported) return;
    try {
      await _storage.delete(key: _kEmail);
      await _storage.delete(key: _kPassword);
    } catch (e) {
      debugPrint('CredentialStore.clear failed: $e');
    }
  }
}
