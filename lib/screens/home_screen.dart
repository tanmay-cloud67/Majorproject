import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_routes.dart';
import '../models/dashboard_snapshot.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/food_log_service.dart';
import '../services/hydration_service.dart';
import '../services/steps_service.dart';
import '../services/weight_service.dart';
import '../services/workout_service.dart';
import '../widgets/calz_mascot_widget.dart';
import '../widgets/weekly_steps_graph_card.dart';
import '../widgets/health_band_card.dart';
import 'food_scanner_screen.dart';

const List<BoxShadow> _softCardShadow = [
  BoxShadow(color: Color(0x12000000), blurRadius: 22, offset: Offset(0, 10)),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.authService, this.showBottomNav = true});

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

  static Future<void> showHydrationSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => const _HydrationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F8),
      body: CalzHomeScreenView(
        onSettingsTap: () => _showSettingsSheet(context),
      ),
      bottomNavigationBar: showBottomNav
          ? DashboardNavigationBar(
              currentIndex: 0,
              onHomeTap: () {},
              onSettingsTap: () => _showSettingsSheet(context),
              onFavoritesTap: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.activity),
              onScanTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
              ),
              onStatsTap: () => Navigator.of(context).pushReplacementNamed(
                AppRoutes.stats,
              ),
            )
          : null,
    );
  }
}

Future<void> showUserProfileSheet(
  BuildContext context, {
  UserProfile? profile,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  final effectiveProfile = profile ??
      (user != null ? await AuthService().getUserProfile(user.uid) : null);

  final name = (effectiveProfile?.name?.trim().isNotEmpty ?? false)
      ? effectiveProfile!.name!
      : (user?.displayName?.trim().isNotEmpty ?? false)
          ? user!.displayName!
          : (user?.email != null && user!.email!.contains('@'))
              ? user.email!.split('@').first
              : 'User';

  final email = (effectiveProfile?.email.trim().isNotEmpty ?? false)
      ? effectiveProfile!.email.trim()
      : (user?.email ?? 'No email saved.');

  final dashboard = DashboardSnapshot.fromProfile(
    fallbackName: name,
    fallbackEmail: email,
    profile: effectiveProfile,
  );

  if (!context.mounted) return;

  _DashboardHeader(dashboard: dashboard, profile: effectiveProfile)
      ._showProfileSheet(context);
}

class _HomeProfileAvatar extends StatelessWidget {
  const _HomeProfileAvatar();

  String _getInitials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0]).join();
    return initials.isEmpty ? 'U' : initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return GestureDetector(
        onTap: () => showUserProfileSheet(context),
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFFF0EFEA),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.person_outline_rounded,
            color: Color(0xFFFF6A1B),
            size: 26,
          ),
        ),
      );
    }

    return StreamBuilder<UserProfile?>(
      stream: AuthService().watchUserProfile(user.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = (profile?.name?.trim().isNotEmpty ?? false)
            ? profile!.name!
            : (user.displayName?.trim().isNotEmpty ?? false)
                ? user.displayName!
                : (user.email != null && user.email!.contains('@'))
                    ? user.email!.split('@').first
                    : 'User';
        final initials = _getInitials(name);

        return InkWell(
          onTap: () => showUserProfileSheet(context, profile: profile),
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _ProfileAvatar(
                initials: initials,
                photoUrl: profile?.photoUrl,
                size: 48,
                radius: 24,
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF9F9F8), width: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.dashboard, required this.profile});

  final DashboardSnapshot dashboard;
  final UserProfile? profile;

  Future<void> _saveProfilePhoto(BuildContext context, String photoUrl) async {
    final uid = profile?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile photo.')),
      );
      return;
    }

    try {
      await AuthService().updateProfilePhoto(uid: uid, photoUrl: photoUrl);
      if (!context.mounted) {
        return;
      }
      final message = photoUrl.trim().isEmpty
          ? 'Profile photo removed.'
          : 'Profile updated.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
    }
  }

  Future<void> _saveBio(BuildContext context, String bio) async {
    final uid = profile?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update bio.')),
      );
      return;
    }

    try {
      await AuthService().updateBio(uid: uid, bio: bio);
      if (!context.mounted) {
        return;
      }
      final message =
          bio.trim().isEmpty ? 'Bio cleared.' : 'Bio updated.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
    }
  }

  Future<void> _promptBio(BuildContext context) async {
    final controller = TextEditingController(text: profile?.bio ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit bio'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Bio',
            hintText: 'Tell us about you',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    await _saveBio(context, result);
  }

  Future<void> _promptProfileDetails(BuildContext context) async {
    final uid = profile?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile.')),
      );
      return;
    }

    final professionController =
        TextEditingController(text: profile?.profession ?? '');
    final ageController =
        TextEditingController(text: profile?.age?.toString() ?? '');
    final heightController = TextEditingController(
      text: profile?.height?.toStringAsFixed(0) ?? '',
    );
    final weightController = TextEditingController(
      text: profile?.weight?.toStringAsFixed(1) ?? '',
    );

    const goals = [
      'Lose Weight',
      'Build Muscle',
      'Stay Active',
      'Improve Sleep',
    ];
    var selectedGoal =
        goals.contains(profile?.goal) ? profile!.goal! : goals.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: professionController,
                  decoration: const InputDecoration(labelText: 'Profession'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedGoal,
                  decoration: const InputDecoration(labelText: 'Goal'),
                  items: goals
                      .map(
                        (goal) => DropdownMenuItem<String>(
                          value: goal,
                          child: Text(goal),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      selectedGoal = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      professionController.dispose();
      ageController.dispose();
      heightController.dispose();
      weightController.dispose();
      return;
    }

    final ageText = ageController.text.trim();
    final heightText = heightController.text.trim();
    final weightText = weightController.text.trim();

    final parsedAge = ageText.isEmpty ? null : int.tryParse(ageText);
    final parsedHeight =
        heightText.isEmpty ? null : double.tryParse(heightText);
    final parsedWeight =
        weightText.isEmpty ? null : double.tryParse(weightText);

    if ((ageText.isNotEmpty && parsedAge == null) ||
        (heightText.isNotEmpty && parsedHeight == null) ||
        (weightText.isNotEmpty && parsedWeight == null)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid numeric values.')),
      );
      professionController.dispose();
      ageController.dispose();
      heightController.dispose();
      weightController.dispose();
      return;
    }

    try {
      await AuthService().updateProfileDetails(
        uid: uid,
        profession: professionController.text,
        goal: selectedGoal,
        age: parsedAge,
        height: parsedHeight,
        weight: parsedWeight,
        clearProfession: professionController.text.trim().isEmpty,
        clearAge: ageText.isEmpty,
        clearHeight: heightText.isEmpty,
        clearWeight: weightText.isEmpty,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
    } finally {
      professionController.dispose();
      ageController.dispose();
      heightController.dispose();
      weightController.dispose();
    }
  }

  Future<void> _promptPhotoUrl(BuildContext context) async {
    final controller = TextEditingController(
      text: profile?.photoUrl?.trim() ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profile photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste an image URL to use as your profile photo.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://example.com/photo.jpg',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Leave empty to remove the photo.',
              style: TextStyle(color: Color(0xFF6F6A64), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    await _saveProfilePhoto(context, result);
  }

  Future<void> _captureProfilePhoto(BuildContext context) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (photo == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    await _saveProfilePhoto(context, photo.path);
  }

  void _showPhotoOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _captureProfilePhoto(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Paste image URL'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _promptPhotoUrl(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _saveProfilePhoto(context, '');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProfileSheet(BuildContext context) {
    final age = profile?.age;
    final height = profile?.height;
    final weightLabel = profile?.weight == null
        ? dashboard.currentWeightLabel
        : '${profile!.weight!.toStringAsFixed(1)} kg';
    final goalLabel = profile?.goal ?? dashboard.goalLabel;
    final professionLabel =
        (profile?.profession?.trim().isNotEmpty ?? false)
            ? profile!.profession!.trim()
            : 'Not set';
    final bio = profile?.bio?.trim();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _ProfileAvatar(
                      initials: _initialsFromName(dashboard.name),
                      photoUrl: profile?.photoUrl,
                      size: 54,
                      radius: 18,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dashboard.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dashboard.email,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF6F6A64),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ProfileInfoTile(
                      label: 'Profession',
                      value: professionLabel,
                      icon: Icons.work_outline,
                    ),
                    _ProfileInfoTile(
                      label: 'Goal',
                      value: goalLabel,
                      icon: Icons.flag_rounded,
                    ),
                    _ProfileInfoTile(
                      label: 'Age',
                      value: age == null ? '0 yrs' : '$age yrs',
                      icon: Icons.cake_outlined,
                    ),
                    _ProfileInfoTile(
                      label: 'Height',
                      value: height == null
                          ? '0 cm'
                          : '${height.toStringAsFixed(0)} cm',
                      icon: Icons.height,
                    ),
                    _ProfileInfoTile(
                      label: 'Weight',
                      value: weightLabel,
                      icon: Icons.monitor_weight_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _promptProfileDetails(context);
                    },
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Edit profile'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _showBluetoothStub(context);
                    },
                    icon: const Icon(Icons.bluetooth_connected),
                    label: const Text('Add device'),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Bio',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF111111),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    (bio == null || bio.isEmpty)
                        ? 'No bio added yet.'
                        : bio,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6F6A64),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _promptBio(context);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit bio'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _showPhotoOptions(context);
                    },
                    icon: Icon(
                      (profile?.photoUrl?.trim().isNotEmpty ?? false)
                          ? Icons.photo_camera_back_outlined
                          : Icons.add_a_photo_outlined,
                    ),
                    label: Text(
                      (profile?.photoUrl?.trim().isNotEmpty ?? false)
                          ? 'Change profile photo'
                          : 'Add profile photo',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBluetoothStub(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Bluetooth device support is coming soon.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final nameParts = dashboard.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    final initials = nameParts.isEmpty
        ? 'H'
        : nameParts.map((part) => part.substring(0, 1).toUpperCase()).join();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${dashboard.name}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: const Color(0xFF131313),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeaderChip(
                    icon: Icons.flag_rounded,
                    label: dashboard.goalLabel,
                    backgroundColor: const Color(0xFFFFE9DB),
                    foregroundColor: const Color(0xFFFF6A1B),
                  ),
                  _HeaderChip(
                    icon: Icons.monitor_weight_outlined,
                    label: dashboard.currentWeightLabel,
                    backgroundColor: const Color(0xFFE5F1FF),
                    foregroundColor: const Color(0xFF2F80ED),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderActionButton(
              icon: Icons.bluetooth_connected,
              onTap: () => _showBluetoothStub(context),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => _showProfileSheet(context),
              borderRadius: BorderRadius.circular(18),
              child: _ProfileAvatar(
                initials: initials,
                photoUrl: profile?.photoUrl,
                size: 58,
                radius: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _initialsFromName(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0]).join();
    return initials.isEmpty ? 'H' : initials.toUpperCase();
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: _softCardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foregroundColor ?? const Color(0xFF111111)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foregroundColor ?? const Color(0xFF111111),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _softCardShadow,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: const Color(0xFF111111)),
      ),
    );
  }
}

class _OverviewTileGrid extends StatelessWidget {
  const _OverviewTileGrid({required this.tiles, this.onHydrationTap});

  final List<OverviewTileSnapshot> tiles;
  final VoidCallback? onHydrationTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileHeight = switch (constraints.maxWidth) {
          >= 560 => 174.0,
          >= 420 => 182.0,
          _ => 192.0,
        };

        return GridView.builder(
          itemCount: tiles.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: tileHeight,
          ),
          itemBuilder: (context, index) => _OverviewTile(
            tile: tiles[index],
            onHydrationTap: onHydrationTap,
          ),
        );
      },
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({required this.tile, this.onHydrationTap});

  final OverviewTileSnapshot tile;
  final VoidCallback? onHydrationTap;

  @override
  Widget build(BuildContext context) {
    final iconData = _tileIcon(tile.kind);
    final iconColor = _tileIconColor(tile.kind);
    final tileGradient = _tileGradient(tile.kind);
    final onChevronTap = tile.kind == OverviewTileKind.activity
        ? () =>
            Navigator.of(context).pushNamed(AppRoutes.activityDetails)
        : tile.kind == OverviewTileKind.hydration
        ? onHydrationTap
        : null;

    final card = Container(
      decoration: BoxDecoration(
        color: tileGradient == null ? Colors.white : null,
        gradient: tileGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softCardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (tile.kind == OverviewTileKind.activity)
              const Positioned(
                left: 28,
                bottom: -18,
                child: _GlowOrb(color: Color(0xFFFF6A1B), size: 92),
              ),
            if (tile.kind == OverviewTileKind.hydration)
              const Positioned(
                right: -10,
                bottom: -18,
                child: _GlowOrb(color: Color(0xFF8BCBFF), size: 84),
              ),
            if (iconData != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconData,
                    size: 28,
                    color: iconColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tile.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF2A2A2A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      onChevronTap == null
                          ? const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF2A2A2A),
                            )
                          : IconButton(
                              onPressed: onChevronTap,
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF2A2A2A),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    tile.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF111111),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tile.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6F6A64),
                    ),
                  ),
                  SizedBox(height: iconData == null ? 10 : 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onChevronTap == null) {
      return card;
    }

    return InkWell(
      onTap: onChevronTap,
      borderRadius: BorderRadius.circular(24),
      child: card,
    );
  }
}

class _HydrationBottle extends StatelessWidget {
  const _HydrationBottle({
    required this.progress,
    required this.liters,
    required this.goal,
  });

  final double progress;
  final double liters;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: 78,
      height: 170,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFBFD7F2), width: 2),
              color: const Color(0xFFF4FAFF),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: clamped,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      bottom: const Radius.circular(22),
                      top: Radius.circular(clamped > 0.95 ? 22 : 10),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF7EC8FF), Color(0xFF4BA7FF)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  '${(clamped * 100).round()}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF1A3D66),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${liters.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} L',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF5A6B7F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterQuickAdd extends StatelessWidget {
  const _WaterQuickAdd({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1A3D66),
        side: const BorderSide(color: Color(0xFF9CCBFF)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(label),
    );
  }
}

class _HydrationSheet extends StatefulWidget {
  const _HydrationSheet();

  @override
  State<_HydrationSheet> createState() => _HydrationSheetState();
}

class _HydrationSheetState extends State<_HydrationSheet> {
  final TextEditingController _controller = TextEditingController();
  late final StreamSubscription<HydrationSnapshot> _subscription;
  HydrationSnapshot _snapshot = HydrationSnapshot(
    todayLiters: 0,
    goalLiters: 0,
    weeklyAverageLiters: 0,
    lastUpdated: DateTime.now(),
  );
  String? _error;
  double _goalValue = 0;
  bool _goalDirty = false;

  @override
  void initState() {
    super.initState();
    _subscription = HydrationService.instance.hydrationStream.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = value;
        if (!_goalDirty) {
          _goalValue = value.goalLiters;
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _snapshot.todayLiters;
    final goal = _snapshot.goalLiters;
    final progress = goal <= 0 ? 0.0 : (today / goal).clamp(0.0, 1.0);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _HydrationBottle(
                  progress: progress,
                  liters: today,
                  goal: goal,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Water intake',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${today.toStringAsFixed(1)} L today',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Goal: ${goal.toStringAsFixed(1)} L',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6F6A64),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _WaterQuickAdd(
                  label: '+0.2 L',
                  onTap: () {
                    HydrationService.instance.addWater(0.2);
                  },
                ),
                _WaterQuickAdd(
                  label: '+0.5 L',
                  onTap: () {
                    HydrationService.instance.addWater(0.5);
                  },
                ),
                _WaterQuickAdd(
                  label: '+1.0 L',
                  onTap: () {
                    HydrationService.instance.addWater(1.0);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Add custom (L)',
                    ),
                    onChanged: (_) {
                      if (_error != null) {
                        setState(() {
                          _error = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () {
                    final parsed = double.tryParse(_controller.text.trim());
                    if (parsed == null || parsed <= 0) {
                      setState(() {
                        _error = 'Enter a valid water amount.';
                      });
                      return;
                    }
                    _controller.clear();
                    setState(() {
                      _error = null;
                    });
                    HydrationService.instance.addWater(parsed);
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Daily goal (max 6 L)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Slider(
              value: _goalValue,
              min: 0,
              max: 6,
              divisions: 12,
              label: '${_goalValue.toStringAsFixed(1)} L',
              onChanged: (value) {
                setState(() {
                  _goalDirty = true;
                  _goalValue = value;
                });
              },
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _goalDirty = false;
                  HydrationService.instance.setGoal(_goalValue);
                },
                icon: const Icon(Icons.water_drop_outlined),
                label: const Text('Set goal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData? _tileIcon(OverviewTileKind kind) {
  switch (kind) {
    case OverviewTileKind.activity:
      return Icons.directions_bike;
    case OverviewTileKind.hydration:
      return Icons.local_drink_rounded;
    case OverviewTileKind.calories:
      return Icons.local_fire_department_rounded;
    case OverviewTileKind.weeklyGoal:
      return Icons.emoji_events_rounded;
  }
}

Color _tileIconColor(OverviewTileKind kind) {
  switch (kind) {
    case OverviewTileKind.activity:
      return const Color(0xFFFF6A1B);
    case OverviewTileKind.hydration:
      return const Color(0xFF4BA7FF);
    case OverviewTileKind.calories:
      return const Color(0xFFEF5350);
    case OverviewTileKind.weeklyGoal:
      return const Color(0xFF7E57C2);
  }
}

LinearGradient? _tileGradient(OverviewTileKind kind) {
  switch (kind) {
    case OverviewTileKind.activity:
      return const LinearGradient(
        colors: [Color(0xFFFFF4E6), Color(0xFFFFE6D1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case OverviewTileKind.hydration:
      return const LinearGradient(
        colors: [Color(0xFFEAF6FF), Color(0xFFDDEEFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case OverviewTileKind.calories:
      return const LinearGradient(
        colors: [Color(0xFFFFEEF0), Color(0xFFFFE2E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case OverviewTileKind.weeklyGoal:
      return const LinearGradient(
        colors: [Color(0xFFF3EDFF), Color(0xFFE8E0FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withAlpha(220), color.withAlpha(0)],
        ),
      ),
    );
  }
}

class RecentActivitiesCard extends StatelessWidget {
  const RecentActivitiesCard({super.key, required this.activities});

  final List<ActivitySnapshot> activities;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE6F6),
        borderRadius: BorderRadius.circular(30),
        boxShadow: _softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent activities',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'See all',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF111111),
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActivityFilterChip(label: 'All', active: true),
              _ActivityFilterChip(label: 'Morning activities'),
              _ActivityFilterChip(label: 'Recovery'),
            ],
          ),
          const SizedBox(height: 18),
          ...activities.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ActivityRow(activity: activity),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityFilterChip extends StatelessWidget {
  const _ActivityFilterChip({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0D0D0D) : Colors.transparent,
        border: Border.all(color: const Color(0xFF8692A7)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: active ? Colors.white : const Color(0xFF253044),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final ActivitySnapshot activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(150),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.category,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: const Color(0xFF5B6577)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  activity.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF111111),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F1EC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  activity.metricLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF111111),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            activity.detail,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF566172)),
          ),
        ],
      ),
    );
  }
}

class WeeklyGoalCard extends StatelessWidget {
  const WeeklyGoalCard({super.key, required this.weeklyGoal});

  final WeeklyGoalSnapshot weeklyGoal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: _softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weekly goal',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF111111),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                weeklyGoal.dateRangeLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF565656),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
          const SizedBox(height: 18),
          _WeeklyGoalBars(bars: weeklyGoal.bars),
        ],
      ),
    );
  }
}

class _WeeklyGoalBars extends StatelessWidget {
  const _WeeklyGoalBars({required this.bars});

  final List<GoalBarSnapshot> bars;

  @override
  Widget build(BuildContext context) {
    final maxAmount = bars.map((bar) => bar.amount).reduce(math.max);
    final safeMax = maxAmount <= 0 ? 1.0 : maxAmount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars
          .map(
            (bar) => Expanded(
              child: Column(
                children: [
                  Text(
                    bar.displayValue,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF929292),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 146,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 36,
                      height: 42 + (bar.amount / safeMax) * 82,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6A1B),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bar.dayLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class WorkoutSectionCard extends StatelessWidget {
  const WorkoutSectionCard({
    super.key,
    required this.workout,
  });

  final WorkoutSnapshot workout;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WorkoutSummary>(
      stream: WorkoutService.instance.summaryStream,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final displayDuration = summary == null
            ? workout.duration
            : '${summary.todayMinutes} min';
        final completedLabel = summary == null
            ? '${workout.completedWorkouts} workouts'
            : '${summary.weeklySessions} workouts';
        final intensityLabel =
            summary == null ? workout.intensity : summary.intensityLabel;
        final logs = summary == null ? workout.exercises : summary.recentLogs;
        final isActive = summary?.isActive ?? false;
        final activeSeconds = summary?.activeSeconds ?? 0;
        final timerLabel =
            isActive ? _formatDuration(activeSeconds) : 'Start Workout';

        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6A1B),
            borderRadius: BorderRadius.circular(30),
            boxShadow: _softCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout section',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                workout.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _WorkoutStatPill(label: 'Today', value: displayDuration),
                  _WorkoutStatPill(label: 'Completed', value: completedLabel),
                  _WorkoutStatPill(label: 'Intensity', value: intensityLabel),
                ],
              ),
              const SizedBox(height: 18),
              ...logs.take(3).map(
                (exercise) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.black),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          exercise,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    if (!isActive) {
                      await WorkoutService.instance.startSession();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('Workout started.')),
                        );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: Icon(
                    isActive ? Icons.timelapse_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(isActive ? timerLabel : 'Start Workout'),
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await WorkoutService.instance.endSession();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Workout session saved.'),
                          ),
                        );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('End Session'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = remainder.toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _WorkoutStatPill extends StatelessWidget {
  const _WorkoutStatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(210),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: const Color(0xFF4D4037)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressTrackingCard extends StatelessWidget {
  const ProgressTrackingCard({super.key, required this.progress});

  final ProgressSnapshot progress;

  Future<void> _promptAddWeight(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add weight'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Weight (kg)',
            hintText: 'Enter today’s weight',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null || result.isEmpty) {
      return;
    }

    final parsed = double.tryParse(result);
    if (parsed == null || parsed <= 0) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Enter a valid weight.')));
      return;
    }

    await WeightService.instance.addWeight(parsed);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await AuthService().updateProfileDetails(
          uid: uid,
          weight: parsed,
          clearWeight: false,
        );
      } catch (_) {
        // Ignore profile update failures; local log is still saved.
      }
    }

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Weight updated.')));
  }

  String _weightSummary(List<WeightEntry> entries) {
    if (entries.length < 2) {
      return '0 kg change';
    }
    final sorted = List<WeightEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));
    final delta = sorted.last.weight - sorted.first.weight;
    final formatted = delta.toStringAsFixed(1);
    return delta >= 0
        ? '+$formatted kg change'
        : '$formatted kg change';
  }

  List<WeightPoint> _buildWeightPoints(List<WeightEntry> entries) {
    const labels = ['W1', 'W2', 'W3', 'W4', 'W5', 'Now'];
    final points = List<WeightPoint>.generate(
      labels.length,
      (index) => WeightPoint(label: labels[index], value: 0),
    );

    if (entries.isEmpty) {
      return points;
    }

    final sorted = List<WeightEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));
    final subset =
        sorted.length <= labels.length
            ? sorted
            : sorted.sublist(sorted.length - labels.length);
    final startIndex = labels.length - subset.length;
    for (var i = 0; i < subset.length; i++) {
      points[startIndex + i] = WeightPoint(
        label: labels[startIndex + i],
        value: subset[i].weight,
      );
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WeightLogSnapshot>(
      stream: WeightService.instance.weightStream,
      builder: (context, weightSnapshot) {
        final entries = weightSnapshot.data?.entries ?? const [];
        final weightPoints = _buildWeightPoints(entries);
        final summary = _weightSummary(entries);

        return StreamBuilder<WeeklyStepsSnapshot>(
          stream: StepsService.instance.weeklyStepsStream,
          builder: (context, stepsSnapshot) {
            final avgSteps =
                stepsSnapshot.data?.averageSteps ?? 0;

            return StreamBuilder<WorkoutSummary>(
              stream: WorkoutService.instance.summaryStream,
              builder: (context, workoutSnapshot) {
                final weeklySessions =
                    workoutSnapshot.data?.weeklySessions ?? 0;

                return StreamBuilder<HydrationSnapshot>(
                  stream: HydrationService.instance.hydrationStream,
                  builder: (context, hydrationSnapshot) {
                    final weeklyWater =
                        hydrationSnapshot.data?.weeklyAverageLiters ?? 0;
                    final stats = [
                      WeeklyStatSnapshot(
                        label: 'Workouts',
                        value: weeklySessions.toString(),
                        detail: 'Sessions completed',
                      ),
                      WeeklyStatSnapshot(
                        label: 'Avg steps',
                        value: avgSteps.round().toString(),
                        detail: 'Steps logged',
                      ),
                      WeeklyStatSnapshot(
                        label: 'Water',
                        value: '${weeklyWater.toStringAsFixed(1)} L',
                        detail: 'Daily average',
                      ),
                    ];

                    return Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE6F6),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: _softCardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  progress.headline,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: const Color(0xFF111111),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _promptAddWeight(context),
                                icon: const Icon(Icons.add_circle_outline),
                                color: const Color(0xFF111111),
                                tooltip: 'Add weight',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            summary,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: const Color(0xFF425066)),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 170,
                            child: _WeightTrendChart(points: weightPoints),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Weekly stats',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: const Color(0xFF111111),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: stats
                                .map((stat) => _ProgressStatCard(stat: stat))
                                .toList(),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ProgressStatCard extends StatelessWidget {
  const _ProgressStatCard({required this.stat});

  final WeeklyStatSnapshot stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(150),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: const Color(0xFF44526A)),
          ),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF111111),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.detail,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5E697E)),
          ),
        ],
      ),
    );
  }
}

class _WeightTrendChart extends StatelessWidget {
  const _WeightTrendChart({required this.points});

  final List<WeightPoint> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(150),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(14),
      child: CustomPaint(
        painter: _WeightTrendPainter(points: points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WeightTrendPainter extends CustomPainter {
  const _WeightTrendPainter({required this.points});

  final List<WeightPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }

    const verticalPadding = 18.0;
    final chartRect = Rect.fromLTWH(
      0,
      verticalPadding,
      size.width,
      size.height - (verticalPadding * 2),
    );

    final minValue = points.map((point) => point.value).reduce(math.min);
    final maxValue = points.map((point) => point.value).reduce(math.max);
    final range = math.max(maxValue - minValue, 0.4);

    final gridPaint = Paint()
      ..color = const Color(0xFFBEC9DA)
      ..strokeWidth = 1;

    for (var index = 0; index < 4; index++) {
      final y = chartRect.top + (chartRect.height / 3) * index;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final linePath = Path();
    final fillPath = Path();
    final dots = <Offset>[];

    for (var index = 0; index < points.length; index++) {
      final dx =
          chartRect.left + (chartRect.width / (points.length - 1)) * index;
      final normalized = (points[index].value - minValue) / range;
      final dy = chartRect.bottom - (normalized * chartRect.height);
      final offset = Offset(dx, dy);
      dots.add(offset);

      if (index == 0) {
        linePath.moveTo(dx, dy);
        fillPath
          ..moveTo(dx, chartRect.bottom)
          ..lineTo(dx, dy);
      } else {
        linePath.lineTo(dx, dy);
        fillPath.lineTo(dx, dy);
      }
    }

    fillPath
      ..lineTo(chartRect.right, chartRect.bottom)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x55FF6A1B), Color(0x00FF6A1B)],
        ).createShader(chartRect),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFFFF6A1B)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final labelStyle = TextStyle(
      color: const Color(0xFF5B677A),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    for (var index = 0; index < dots.length; index++) {
      final dot = dots[index];
      canvas.drawCircle(dot, 4.5, Paint()..color = const Color(0xFFFF6A1B));
      canvas.drawCircle(dot, 2.5, Paint()..color = Colors.white);

      final textPainter = TextPainter(
        text: TextSpan(text: points[index].label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(dot.dx - (textPainter.width / 2), chartRect.bottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class DashboardNavigationBar extends StatelessWidget {
  const DashboardNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onHomeTap,
    required this.onFavoritesTap,
    required this.onScanTap,
    required this.onStatsTap,
    required this.onSettingsTap,
  });

  final int currentIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onScanTap;
  final VoidCallback onStatsTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFF9F9F8),
          border: Border(top: BorderSide(color: Color(0xFFEBEAE5), width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _CalzNavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: currentIndex == 0,
              onTap: onHomeTap,
            ),
            _CalzNavItem(
              icon: Icons.directions_run_rounded,
              label: 'Activity',
              active: currentIndex == 1,
              onTap: onFavoritesTap,
            ),
            _CalzNavItem(
              icon: Icons.auto_awesome_rounded,
              label: 'Calz Coach',
              active: currentIndex == 2,
              hasDot: true,
              onTap: onScanTap,
            ),
            _CalzNavItem(
              icon: Icons.scale_rounded,
              label: 'Weight',
              active: currentIndex == 3,
              onTap: onStatsTap,
            ),
            _CalzNavItem(
              icon: Icons.favorite_rounded,
              label: 'Wellness',
              active: currentIndex == 4,
              onTap: onSettingsTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CalzNavItem extends StatelessWidget {
  const _CalzNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.hasDot = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool hasDot;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF111111) : const Color(0xFFC4C4C4);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 26),
                if (hasDot)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanNavButton extends StatelessWidget {
  const _ScanNavButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? const Color(0xFFFF8A4C) : const Color(0xFFFFC7A4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const _CrossedUtensilsIcon(size: 28),
      ),
    );
  }
}

class _CrossedUtensilsIcon extends StatelessWidget {
  const _CrossedUtensilsIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CrossedUtensilsPainter(),
      ),
    );
  }
}

class _CrossedUtensilsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final center = Offset(size.width / 2, size.height / 2);
    final spoonAngle = -0.8;
    final forkAngle = 0.8;

    canvas.save();
    canvas.translate(center.dx - 2, center.dy + 2);
    canvas.rotate(spoonAngle);
    final spoonHandle =
        Rect.fromCenter(center: const Offset(0, 4), width: 3.2, height: 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(spoonHandle, const Radius.circular(2)),
      paint,
    );
    final spoonHead =
        Rect.fromCenter(center: const Offset(0, -8), width: 8, height: 10);
    canvas.drawOval(spoonHead, paint);
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx + 2, center.dy + 2);
    canvas.rotate(forkAngle);
    final forkHandle =
        Rect.fromCenter(center: const Offset(0, 4), width: 3.2, height: 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(forkHandle, const Radius.circular(2)),
      paint,
    );
    for (final dx in [-4.0, 0.0, 4.0]) {
      canvas.drawRect(
        Rect.fromLTWH(dx - 0.6, -12, 1.2, 6),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3A3A3A)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF6F6A64),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF111111),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    required this.photoUrl,
    required this.size,
    required this.radius,
  });

  final String initials;
  final String? photoUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = photoUrl?.trim();
    final hasPhoto = trimmedUrl != null && trimmedUrl.isNotEmpty;
    final imageProvider = hasPhoto ? _resolveImageProvider(trimmedUrl) : null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFA36C), Color(0xFFFF6A1B)],
        ),
        image: imageProvider == null
            ? null
            : DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Text(
              initials,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  ImageProvider? _resolveImageProvider(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return null;
    }

    if (trimmedValue.startsWith('http://') ||
        trimmedValue.startsWith('https://') ||
        trimmedValue.startsWith('blob:')) {
      return NetworkImage(trimmedValue);
    }

    if (kIsWeb) {
      return null;
    }

    final uri = Uri.tryParse(trimmedValue);
    final filePath = uri != null && uri.scheme == 'file'
        ? uri.toFilePath(windows: Platform.isWindows)
        : trimmedValue;
    if (filePath.isEmpty) {
      return null;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      return null;
    }

    return FileImage(file);
  }
}

class _FirestoreWarningCard extends StatelessWidget {
  const _FirestoreWarningCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE0D3),
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFF111111)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Firestore access is blocked',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF111111),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Deploy the Firestore rules in this project so signed-in users can read and write their own profile documents.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF41332D)),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5E4B43)),
          ),
        ],
      ),
    );
  }
}

class CalzHomeScreenView extends StatefulWidget {
  const CalzHomeScreenView({super.key, required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  State<CalzHomeScreenView> createState() => _CalzHomeScreenViewState();
}

class _CalzHomeScreenViewState extends State<CalzHomeScreenView> {
  late DateTime _now;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _selectedDayIndex = _now.weekday % 7;
  }

  List<Map<String, dynamic>> get _dynamicWeekDays {
    final sunday = _now.subtract(Duration(days: _now.weekday % 7));
    const dayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    final todayIndex = _now.weekday % 7;

    return List.generate(7, (index) {
      final dayDate = sunday.add(Duration(days: index));
      return {
        'day': dayNames[index],
        'num': dayDate.day.toString(),
        'target': '2327',
        'active': index == _selectedDayIndex,
        'isToday': index == todayIndex,
      };
    });
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  String _fullDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FoodLogEntry>>(
      stream: FoodLogService.instance.entriesStream,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const [];
        var totalCalories = 0.0;
        var totalCarbs = 0.0;
        var totalProtein = 0.0;
        var totalFat = 0.0;

        for (final entry in entries) {
          if (entry.calories != null) {
            totalCalories += entry.calories!;
            totalProtein += (entry.calories! * 0.25) / 4.0;
            totalCarbs += (entry.calories! * 0.50) / 4.0;
            totalFat += (entry.calories! * 0.25) / 9.0;
          }
        }

        const calorieTarget = 2327;
        const carbTarget = 87;
        const proteinTarget = 175;
        const fatTarget = 142;

        final weekDays = _dynamicWeekDays;

        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F8),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // 1. Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _HomeProfileAvatar(),
                      Column(
                        children: [
                          Text(
                            "${_monthName(_now.month)} '${_now.year.toString().substring(2)}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fullDayName(_now.weekday),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF6A1B),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.healthBand);
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0EFEA),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.bluetooth_connected_rounded,
                            color: Color(0xFF2F80ED),
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ESP32 Health Band Quick Action Card
                  const HealthBandQuickCard(),

                  const SizedBox(height: 12),

                  // 2. Weekday Calendar Selector Bar
                  SizedBox(
                    height: 76,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(weekDays.length, (index) {
                        final item = weekDays[index];
                        final isSelected = index == _selectedDayIndex;
                        final isToday = item['isToday'] == true;

                        if (isSelected) {
                          return Container(
                            width: 44,
                            height: 72,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isToday
                                    ? const Color(0xFFFF6A1B)
                                    : const Color(0xFFEBEAE5),
                                width: isToday ? 2.0 : 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0E000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['day'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isToday
                                        ? const Color(0xFFFF6A1B)
                                        : const Color(0xFFB0BEC5),
                                  ),
                                ),
                                Text(
                                  item['num'] as String,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isToday
                                        ? const Color(0xFFFF6A1B)
                                        : const Color(0xFF111111),
                                  ),
                                ),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? const Color(0xFFFF6A1B)
                                        : const Color(0xFFFFC107),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return GestureDetector(
                          onTap: () => setState(() => _selectedDayIndex = index),
                          child: SizedBox(
                            width: 42,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item['day'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isToday
                                        ? const Color(0xFFFF6A1B)
                                        : const Color(0xFFC4C4C4),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['num'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isToday
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    color: isToday
                                        ? const Color(0xFFFF6A1B)
                                        : const Color(0xFFB0BEC5),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (isToday)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF6A1B),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else
                                  Text(
                                    item['target'] as String,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFD0D0D0),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Mascot Graphic with Star Badge
                  const CalzMascotWidget(starPoints: 0),
                  const SizedBox(height: 20),

                  // 4. Main Calorie Display: "0 / 2327 CALORIES EATEN"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${totalCalories.toInt()}',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111111),
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        ' / $calorieTarget',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFCFD8DC),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'CALORIES EATEN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 5. Macro Breakdown Row
                  Row(
                    children: [
                      Expanded(
                        child: _MacroColumn(
                          label: 'CARBS',
                          value: totalCarbs.toInt(),
                          target: carbTarget,
                        ),
                      ),
                      Expanded(
                        child: _MacroColumn(
                          label: 'PROTEIN',
                          value: totalProtein.toInt(),
                          target: proteinTarget,
                        ),
                      ),
                      Expanded(
                        child: _MacroColumn(
                          label: 'FAT',
                          value: totalFat.toInt(),
                          target: fatTarget,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 6. Device Steps & Movement Graph Card
                  const WeeklyStepsGraphCard(),
                  const SizedBox(height: 28),

                  // 7. Calz AI Coach Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF111111), Color(0xFF2C2C2C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6A1B).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFFFF6A1B),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Calz Coach AI Scanner',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Snap a photo of your food to auto-track calories & macros.',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FoodScannerScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6A1B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            'Scan 📸',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 8. Action Row: "Logged: X" Pill + Floating Food Emojis Scanner Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EFEA),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            const Text('🍎', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              'Logged: ${entries.length}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        height: 90,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Positioned(
                              top: -12,
                              right: 8,
                              child: Text('🥗', style: TextStyle(fontSize: 30)),
                            ),
                            const Positioned(
                              top: 20,
                              left: 6,
                              child: Text('🌭', style: TextStyle(fontSize: 26)),
                            ),
                            const Positioned(
                              bottom: -6,
                              right: 26,
                              child: Text('🍟', style: TextStyle(fontSize: 24)),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 6,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const FoodScannerScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111111),
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x40000000),
                                        blurRadius: 12,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MacroColumn extends StatelessWidget {
  const _MacroColumn({
    required this.label,
    required this.value,
    required this.target,
  });

  final String label;
  final int value;
  final int target;

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9E9E9E),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 3,
          color: const Color(0xFFEAE8E2),
          alignment: Alignment.centerLeft,
          child: Container(
            width: 80 * progress,
            height: 3,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111111),
              ),
            ),
            Text(
              ' / $target g',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFCFD8DC),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
