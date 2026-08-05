import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Why biometric sign-in can or cannot be offered on this device.
enum BiometricAvailability {
  /// Web/desktop — biometrics don't exist here; hide the option entirely.
  unsupportedPlatform,

  /// No PIN / pattern / password / biometric set on the device, so there is
  /// nothing to authenticate against. The user must fix this in system
  /// settings first.
  noScreenLock,

  /// A screen lock exists but no fingerprint/face is enrolled — it still
  /// works via the device passcode.
  passcodeOnly,

  /// Biometrics are enrolled and ready.
  ready,
}

/// Wraps device biometrics (Face ID / Touch ID / fingerprint).
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Biometrics only exist on iOS/Android — never on web or desktop.
  bool get _supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Detailed availability so the UI can explain itself instead of silently
  /// hiding the option.
  Future<BiometricAvailability> availability() async {
    if (!_supportedPlatform) return BiometricAvailability.unsupportedPlatform;
    try {
      // isDeviceSupported() is true when *any* secure lock exists
      // (PIN/pattern/password or biometric).
      final deviceOk = await _auth.isDeviceSupported();
      if (!deviceOk) return BiometricAvailability.noScreenLock;

      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isEmpty
          ? BiometricAvailability.passcodeOnly
          : BiometricAvailability.ready;
    } catch (e) {
      debugPrint('Biometric availability check failed: $e');
      // A failure here shouldn't hide the feature outright; treat it as
      // passcode-only so the user can still try.
      return BiometricAvailability.passcodeOnly;
    }
  }

  /// True when biometric sign-in can be turned on at all.
  Future<bool> isAvailable() async {
    final a = await availability();
    return a == BiometricAvailability.ready ||
        a == BiometricAvailability.passcodeOnly;
  }

  /// Human label for what the device offers, for use in UI copy.
  Future<String> methodLabel() async {
    if (!_supportedPlatform) return '生物辨識';
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) {
        return defaultTargetPlatform == TargetPlatform.iOS ? 'Face ID' : '臉部辨識';
      }
      if (types.contains(BiometricType.fingerprint)) {
        return defaultTargetPlatform == TargetPlatform.iOS
            ? 'Touch ID'
            : '指紋辨識';
      }
      if (types.contains(BiometricType.iris)) return '虹膜辨識';
      // Nothing enrolled — falls back to the device passcode.
      return '螢幕鎖定密碼';
    } catch (_) {
      return '生物辨識';
    }
  }

  /// Prompts the user. Returns true only on a successful match.
  Future<bool> authenticate({String reason = '驗證身分以登入待辦計畫'}) async {
    if (!_supportedPlatform) return true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Allow the device passcode as a fallback so a failed or unreadable
        // fingerprint doesn't lock the owner out of their own data.
        biometricOnly: false,
        // Survive the OS briefly backgrounding the app to show the prompt.
        persistAcrossBackgrounding: true,
      );
      return ok;
    } catch (e) {
      debugPrint('Biometric auth failed: $e');
      return false;
    }
  }
}
