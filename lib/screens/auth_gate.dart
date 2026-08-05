import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/task_provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Decides what to show based on Firebase auth state:
/// - signed out → LoginScreen
/// - signed in  → HomeScreen, backed by a fresh TaskProvider for that user
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        // Keying on uid forces a fresh TaskProvider (and its Firestore
        // stream) if the user signs out and back in as someone else.
        return ChangeNotifierProvider<TaskProvider>(
          key: ValueKey(user.uid),
          create: (_) => TaskProvider(uid: user.uid)..init(),
          child: const HomeScreen(),
        );
      },
    );
  }
}
