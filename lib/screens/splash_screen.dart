import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import 'dashboard_shell.dart';
import 'profile_setup_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const WelcomeScreen();
        }

        final user = snapshot.data!;
        return FutureBuilder<UserProfile>(
          future: AuthService().ensureUserProfile(
            uid: user.uid,
            email: user.email ?? '',
          ),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (profileSnapshot.hasError) {
              return const DashboardShell();
            }

            if (profileSnapshot.data?.profileCompleted == true) {
              return const DashboardShell();
            }

            return ProfileSetupScreen(uid: user.uid);
          },
        );
      },
    );
  }
}
