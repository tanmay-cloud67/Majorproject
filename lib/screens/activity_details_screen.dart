import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/dashboard_tab_controller.dart';
import '../services/steps_service.dart';
import 'home_screen.dart';

class ActivityDetailsScreen extends StatelessWidget {
  const ActivityDetailsScreen({super.key, this.authService});

  final AuthService? authService;

  AuthService get _authService => authService ?? AuthService();

  static const List<BoxShadow> _softCardShadow = [
    BoxShadow(color: Color(0x12000000), blurRadius: 22, offset: Offset(0, 10)),
  ];

  Future<void> _promptStepGoal(
    BuildContext context, {
    required int? currentGoal,
  }) async {
    final controller = TextEditingController(
      text: currentGoal == null ? '' : currentGoal.toString(),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Step goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Daily step goal',
            hintText: 'Enter step goal',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed < 0) {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid step goal.')),
                );
                return;
              }
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null || uid == null) {
      return;
    }

    try {
      await AuthService().updateStepsGoal(uid: uid, stepsGoal: result);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Step goal updated to $result.')),
        );
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

  void _showCalibrationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => const _CalibrationSheet(),
    );
  }

  void _jumpToTab(BuildContext context, int index) {
    DashboardTabController.setIndex(index);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openFoodLog(BuildContext context) {
    DashboardTabController.setIndex(2);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your activity.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F1EC),
        elevation: 0,
        title: const Text('Activity details'),
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
                      ? (stepsData?.stepsToday ?? 0)
                      : 0;
              final status = stepsData?.status ?? StepsStatus.unavailable;
              final showStatus =
                  stepsSnapshot.hasData && status != StepsStatus.live;

              return StreamBuilder<HourlyActivitySnapshot>(
                stream: StepsService.instance.hourlyStream,
                builder: (context, hourlySnapshot) {
                  final values =
                      hourlySnapshot.data?.stepsPerHour ??
                          List<int>.filled(24, 0);
                  final hourlyTotal = values.fold<int>(
                    0,
                    (sum, value) => sum + value,
                  );
                  final totalSteps =
                      stepsToday > 0 ? stepsToday : hourlyTotal;
                  final maxValue = values.fold<int>(
                    0,
                    (max, value) => value > max ? value : max,
                  );
                  final peakIndex = values.indexOf(maxValue);
                  final peakLabel =
                      maxValue == 0
                          ? '0 steps'
                          : '${_hourLabel(peakIndex)} - $maxValue steps';

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      if (showStatus) _StepsStatusBanner(status: status),
                      if (showStatus) const SizedBox(height: 14),
                      _GoalCard(
                        goal: profile?.stepsGoal,
                        onEdit: () => _promptStepGoal(
                          context,
                          currentGoal: profile?.stepsGoal,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _CalibrationCard(
                        factor: StepsService.instance.calibrationFactor,
                        onCalibrate: () => _showCalibrationSheet(context),
                        onReset:
                            StepsService.instance.calibrationFactor == 1.0
                                ? null
                                : () => StepsService.instance
                                    .setCalibrationFactor(1.0),
                      ),
                      const SizedBox(height: 18),
                      _SummaryStrip(
                        totalSteps: totalSteps,
                        peakHourLabel: peakLabel,
                      ),
                      const SizedBox(height: 18),
                      _HourlyActivityCard(values: values),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: DashboardNavigationBar(
        currentIndex: 1,
        onHomeTap: () => _jumpToTab(context, 0),
        onFavoritesTap: () => _jumpToTab(context, 1),
        onScanTap: () => _openFoodLog(context),
        onStatsTap: () => _jumpToTab(context, 3),
        onSettingsTap: () => _showSettingsSheet(context),
      ),
    );
  }

  String _hourLabel(int index) {
    if (index == 0) {
      return '12 AM';
    }
    if (index < 12) {
      return '$index AM';
    }
    if (index == 12) {
      return '12 PM';
    }
    return '${index - 12} PM';
  }
}

class _StepsStatusBanner extends StatelessWidget {
  const _StepsStatusBanner({required this.status});

  final StepsStatus status;

  @override
  Widget build(BuildContext context) {
    final isPermission = status == StepsStatus.permissionRequired;
    final title = isPermission ? 'Enable activity access' : 'Steps unavailable';
    final description = isPermission
        ? 'Allow Physical Activity permission to track steps.'
        : 'Retry if permissions changed or the sensor was restarted.';
    final actionLabel = isPermission ? 'Allow' : 'Retry';
    void onPressed() => StepsService.instance.requestPermission();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: ActivityDetailsScreen._softCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPermission
                ? Icons.directions_walk_rounded
                : Icons.info_outline_rounded,
            color: const Color(0xFF111111),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF111111),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6F6A64),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.totalSteps,
    required this.peakHourLabel,
  });

  final int totalSteps;
  final String peakHourLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ActivityDetailsScreen._softCardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'Total steps',
              value: '$totalSteps steps',
              icon: Icons.route_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryItem(
              label: 'Peak hour',
              value: peakHourLabel,
              icon: Icons.access_time_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onEdit});

  final int? goal;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final goalValue = goal ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ActivityDetailsScreen._softCardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: Color(0xFF111111)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily step goal',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF6F6A64),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  goalValue == 0 ? '0 steps' : '$goalValue steps',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF111111),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: Text(goalValue == 0 ? 'Set' : 'Edit'),
          ),
        ],
      ),
    );
  }
}

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({
    required this.factor,
    required this.onCalibrate,
    this.onReset,
  });

  final double factor;
  final VoidCallback onCalibrate;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final label = 'Calibration x${factor.toStringAsFixed(2)}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ActivityDetailsScreen._softCardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: Color(0xFF111111)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step calibration',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF6F6A64),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF111111),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onReset != null)
            TextButton(onPressed: onReset, child: const Text('Reset')),
          TextButton(onPressed: onCalibrate, child: const Text('Calibrate')),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF111111)),
          const SizedBox(width: 10),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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

class _HourlyActivityCard extends StatelessWidget {
  const _HourlyActivityCard({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: ActivityDetailsScreen._softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '24-hour activity',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF111111),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Steps taken by hour (12 AM to 12 AM)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6F6A64),
            ),
          ),
          const SizedBox(height: 16),
          _HourlyBarChart(values: values),
        ],
      ),
    );
  }
}

class _CalibrationSheet extends StatefulWidget {
  const _CalibrationSheet();

  @override
  State<_CalibrationSheet> createState() => _CalibrationSheetState();
}

class _CalibrationSheetState extends State<_CalibrationSheet> {
  final TextEditingController _actualController = TextEditingController();
  int? _startRawSteps;
  int _measuredSteps = 0;
  int? _latestRaw;
  bool _isMeasuring = false;

  @override
  void dispose() {
    _actualController.dispose();
    super.dispose();
  }

  void _startMeasurement() {
    final raw = _latestRaw;
    if (raw == null) {
      _showMessage('Waiting for step sensor data...');
      return;
    }
    setState(() {
      _startRawSteps = raw;
      _measuredSteps = 0;
      _isMeasuring = true;
      _actualController.text = '';
    });
  }

  void _stopMeasurement() {
    final raw = _latestRaw;
    if (raw == null || _startRawSteps == null) {
      _showMessage('No step data yet.');
      return;
    }
    final measured = (raw - _startRawSteps!).clamp(0, 999999);
    setState(() {
      _measuredSteps = measured;
      _isMeasuring = false;
      _actualController.text = measured.toString();
    });
  }

  Future<void> _saveCalibration() async {
    if (_isMeasuring) {
      _showMessage('Stop the walk first.');
      return;
    }
    if (_measuredSteps <= 0) {
      _showMessage('Take a short walk first to measure steps.');
      return;
    }
    final parsed = int.tryParse(_actualController.text.trim());
    if (parsed == null || parsed <= 0) {
      _showMessage('Enter a valid actual step count.');
      return;
    }
    final factor = parsed / _measuredSteps;
    if (factor < 0.5 || factor > 1.6) {
      _showMessage('Calibration looks too far off. Try a longer walk.');
      return;
    }
    await StepsService.instance.setCalibrationFactor(factor);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Calibration saved (x${factor.toStringAsFixed(2)}).')),
      );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: StreamBuilder<StepsSnapshot>(
        stream: StepsService.instance.stepsStream,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final status = data?.status ?? StepsStatus.unavailable;
          final live = status == StepsStatus.live;
          _latestRaw = data?.rawSteps;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step calibration',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Walk a known number of steps, then confirm how many you actually took.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6F6A64),
                ),
              ),
              const SizedBox(height: 16),
              if (!live)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F1EC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Step sensor not available. Enable permissions first.',
                  ),
                ),
              if (live) ...[
                Row(
                  children: [
                    Expanded(
                      child: _CalibrationMetric(
                        label: 'Sensor steps',
                        value: (_latestRaw ?? 0).toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CalibrationMetric(
                        label: 'Measured',
                        value: _measuredSteps.toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _isMeasuring ? null : _startMeasurement,
                        child: const Text('Start walk'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isMeasuring ? _stopMeasurement : null,
                        child: const Text('Stop walk'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _actualController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Actual steps walked',
                    hintText: 'e.g. 100',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saveCalibration,
                    child: const Text('Save calibration'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CalibrationMetric extends StatelessWidget {
  const _CalibrationMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EC),
        borderRadius: BorderRadius.circular(16),
      ),
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
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF111111),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HourlyBarChart extends StatelessWidget {
  const _HourlyBarChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(0, (max, value) {
      return value > max ? value : max;
    });
    final safeMax = maxValue <= 0 ? 1.0 : maxValue.toDouble();
    const minHeight = 6.0;
    const maxHeight = 110.0;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: const Color(0xFF8A8580),
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: 160,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (index) {
                  final value = values[index].toDouble();
                  final height =
                      minHeight + (value / safeMax) * (maxHeight - minHeight);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      width: 24,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 14,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                value.toInt().toString(),
                                style: labelStyle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 12,
                            height: height,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6A1B),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _HourAxisLabels(),
        ],
      ),
    );
  }
}

class _HourAxisLabels extends StatelessWidget {
  const _HourAxisLabels();

  @override
  Widget build(BuildContext context) {
    const labels = ['12am', '4am', '8am', '12pm', '4pm', '8pm', '11pm'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (label) => Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8A8580),
              ),
            ),
          )
          .toList(),
    );
  }
}
