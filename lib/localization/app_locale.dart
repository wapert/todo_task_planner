import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

enum AppLanguage { traditionalChinese, english }

String localizedDeviceAuthLabel(String label, {required bool english}) {
  if (!english) return label;
  return switch (label) {
    '生物辨識' => 'Biometric authentication',
    '臉部辨識' => 'Face recognition',
    '指紋辨識' => 'Fingerprint',
    '虹膜辨識' => 'Iris recognition',
    '螢幕鎖定密碼' => 'Screen lock password',
    _ => label,
  };
}

class AppLocaleController extends ChangeNotifier {
  AppLocaleController(this._storage);

  static const _storageKey = 'app_language';
  final FlutterSecureStorage _storage;

  AppLanguage language = AppLanguage.traditionalChinese;

  Locale get locale => language == AppLanguage.english
      ? const Locale('en')
      : const Locale('zh', 'TW');

  bool get isEnglish => language == AppLanguage.english;

  Future<void> load() async {
    language = await _storage.read(key: _storageKey) == 'en'
        ? AppLanguage.english
        : AppLanguage.traditionalChinese;
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (language == value) return;
    language = value;
    notifyListeners();
    await _storage.write(
      key: _storageKey,
      value: value == AppLanguage.english ? 'en' : 'zh_TW',
    );
  }
}

extension AppLocalizationContext on BuildContext {
  AppLocaleController get appLocale => watch<AppLocaleController>();

  bool get isEnglish => read<AppLocaleController>().isEnglish;

  String tr(String traditionalChinese, String english) =>
      read<AppLocaleController>().isEnglish ? english : traditionalChinese;
}
