import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/dashboard_snapshot.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/steps_service.dart';
import 'home_screen.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({
    super.key,
    this.authService,
    this.showBottomNav = true,
  });

  final AuthService? authService;
  final bool showBottomNav;

  AuthService get _authService => authService ?? AuthService();

  Future<void> _signOut(BuildContext context) async {
    await _authService.signOut();
    if (!context.mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.splash, (route) => false);
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About'),
                  subtitle: const Text('Health Tracker app information'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('About Health Tracker'),
                        content: const Text(
                          'Health Tracker helps you stay on top of your goals, '
                          'daily activity, and progress.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Logout'),
                  subtitle: const Text('Sign out of this account'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _signOut(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your stats.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F1EC),
        elevation: 0,
        title: const Text('Stats & Progress'),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _authService.watchUserProfile(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;
          return StreamBuilder<StepsSnapshot>(
            stream: StepsService.instance.stepsStream,
            builder: (context, stepsSnapshot) {
              final stepsData = stepsSnapshot.data;
              final stepsToday =
                  stepsData?.status == StepsStatus.live
                      ? stepsData?.stepsToday
                      : null;
              return StreamBuilder<WeeklyStepsSnapshot>(
                stream: StepsService.instance.weeklyStepsStream,
                builder: (context, weeklyStepsSnapshot) {
                  final weeklySteps = weeklyStepsSnapshot.data;
                  final dashboard = DashboardSnapshot.fromProfile(
                    fallbackName: _displayName(profile, user),
                    fallbackEmail: _emailAddress(profile, user),
                    profile: profile,
                    stepsToday: stepsToday,
                    stepsGoal: profile?.stepsGoal,
                    currentWeekSteps: weeklySteps?.currentWeekSteps,
                    previousWeekSteps: weeklySteps?.previousWeekSteps,
                  );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      WeeklyGoalCard(weeklyGoal: dashboard.weeklyGoal),
                      const SizedBox(height: 18),
                      ProgressTrackingCard(progress: dashboard.progress),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: showBottomNav
          ? DashboardNavigationBar(
              currentIndex: 3,
              onHomeTap: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.home),
              onFavoritesTap: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.activity),
              onScanTap: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.foodLog),
              onStatsTap: () {},
              onSettingsTap: () => _showSettingsSheet(context),
            )
          : null,
    );
  }

  String _displayName(UserProfile? profile, User user) {
    final name = profile?.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email = user.email ?? profile?.email ?? '';
    if (email.isEmpty || !email.contains('@')) {
      return 'there';
    }

    return email.split('@').first;
  }

  String _emailAddress(UserProfile? profile, User user) {
    final storedEmail = profile?.email.trim() ?? '';
    final email = storedEmail.isNotEmpty ? storedEmail : (user.email ?? '');
    return email.isEmpty ? 'No email saved yet.' : email;
  }
}
