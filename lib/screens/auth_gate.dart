import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:microwins/screens/login_screen.dart';
import 'package:microwins/services/auth_service.dart';
import 'package:microwins/main.dart';
import 'package:microwins/widgets/focus_lock_host.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  late final Future<void> _startupAuthCheck;

  @override
  void initState() {
    super.initState();
    _startupAuthCheck = _applyRememberMeOnStartup();
  }

  Future<void> _applyRememberMeOnStartup() async {
    final bool rememberMe = await _authService.getRememberMePreference();
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && !rememberMe) {
      await _authService.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startupAuthCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (authSnapshot.hasData) {
              return const FocusLockHost(child: MainNavigation());
            }

            return const LoginScreen();
          },
        );
      },
    );
  }
}