import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/credential_store.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_TW', null);

  String? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    firebaseError = '$e';
  }

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: AuthService()),
        Provider.value(value: CredentialStore()),
      ],
      child: TodoPlannerApp(firebaseError: firebaseError),
    ),
  );
}

class TodoPlannerApp extends StatelessWidget {
  const TodoPlannerApp({super.key, this.firebaseError});

  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '待辦計畫',
      // The UI is written in Traditional Chinese, so pin the framework's own
      // dialogs (date/time pickers) to match instead of defaulting to English.
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: pageBackgroundColor,
        // The app bar carries no title, so blend it into the page instead of
        // letting it read as a separate band.
        appBarTheme: const AppBarTheme(
          backgroundColor: pageBackgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final isPhoneWidth = MediaQuery.sizeOf(context).width < 600;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: isPhoneWidth
                ? const TextScaler.linear(0.85)
                : MediaQuery.textScalerOf(context),
          ),
          child: child!,
        );
      },
      home: firebaseError == null
          ? const AuthGate()
          : _FirebaseErrorScreen(error: firebaseError!),
    );
  }
}

class _FirebaseErrorScreen extends StatelessWidget {
  const _FirebaseErrorScreen({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text(
                '無法連線到 Firebase',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
