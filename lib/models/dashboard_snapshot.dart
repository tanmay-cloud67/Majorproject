import 'user_profile.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.name,
    required this.email,
    required this.goalLabel,
    required this.goalSummary,
    required this.currentWeightKg,
    required this.currentWeightLabel,
    required this.overviewTiles,
    required this.dailyStats,
    required this.weeklyGoal,
    required this.recentActivities,
    required this.workout,
    required this.progress,
  });

  final String name;
  final String email;
  final String goalLabel;
  final String goalSummary;
  final double currentWeightKg;
  final String currentWeightLabel;
  final List<OverviewTileSnapshot> overviewTiles;
  final List<DailyStatSnapshot> dailyStats;
  final WeeklyGoalSnapshot weeklyGoal;
  final List<ActivitySnapshot> recentActivities;
  final WorkoutSnapshot workout;
  final ProgressSnapshot progress;

  factory DashboardSnapshot.fromProfile({
    required String fallbackName,
    required String fallbackEmail,
    UserProfile? profile,
    int? stepsToday,
    int? stepsGoal,
    List<int>? currentWeekSteps,
    List<int>? previousWeekSteps,
    double waterLiters = 0,
    double waterGoal = 0,
  }) {
    final goalLabel = _goalLabel(profile?.goal);
    final currentWeightKg = profile?.weight ?? 0;
    final name = (profile?.name?.trim().isNotEmpty ?? false)
        ? profile!.name!.trim()
        : fallbackName;
    final email = (profile?.email.trim().isNotEmpty ?? false)
        ? profile!.email.trim()
        : fallbackEmail;

    final resolvedStepsGoal = stepsGoal ?? 0;
    final dailyStats = _buildDailyStats(
      goalLabel,
      currentWeightKg,
      stepsToday: stepsToday,
      stepsGoal: resolvedStepsGoal,
      waterLiters: waterLiters,
      waterGoal: waterGoal,
    );
    final weeklyGoal = _buildWeeklyGoal(
      goalLabel,
      stepsGoal: resolvedStepsGoal,
      currentWeekSteps: currentWeekSteps,
      previousWeekSteps: previousWeekSteps,
    );
    final workout = _buildWorkout(goalLabel);
    final progress = _buildProgress(goalLabel, currentWeightKg);

    return DashboardSnapshot(
      name: name,
      email: email,
      goalLabel: goalLabel,
      goalSummary: _goalSummary(goalLabel),
      currentWeightKg: currentWeightKg,
      currentWeightLabel: _formatWeight(currentWeightKg),
      overviewTiles: _buildOverviewTiles(
        dailyStats,
        weeklyGoal,
        stepsGoal: resolvedStepsGoal,
      ),
      dailyStats: dailyStats,
      weeklyGoal: weeklyGoal,
      recentActivities: _buildRecentActivities(goalLabel),
      workout: workout,
      progress: progress,
    );
  }

  static List<OverviewTileSnapshot> _buildOverviewTiles(
    List<DailyStatSnapshot> dailyStats,
    WeeklyGoalSnapshot weeklyGoal, {
    required int stepsGoal,
  }) {
    return [
      OverviewTileSnapshot(
        kind: OverviewTileKind.activity,
        title: 'Activity',
        value: dailyStats[1].displayValue,
        detail: 'Goal ${_formatNumber(stepsGoal)}',
      ),
      OverviewTileSnapshot(
        kind: OverviewTileKind.hydration,
        title: 'Water',
        value: dailyStats[2].displayValue,
        detail: dailyStats[2].targetLabel,
      ),
      OverviewTileSnapshot(
        kind: OverviewTileKind.calories,
        title: 'Calories',
        value: dailyStats[0].displayValue,
        detail: dailyStats[0].targetLabel,
      ),
      OverviewTileSnapshot(
        kind: OverviewTileKind.weeklyGoal,
        title: 'Weekly goal',
        value: weeklyGoal.completionLabel,
        detail: weeklyGoal.changeLabel,
      ),
    ];
  }

  static List<DailyStatSnapshot> _buildDailyStats(
    String goalLabel,
    double currentWeightKg,
    {
      int? stepsToday,
      int stepsGoal = 0,
      double waterLiters = 0,
      double waterGoal = 0,
    }) {
    final resolvedSteps = stepsToday ?? 0;
    final stepDisplay = _formatSteps(resolvedSteps);
    final stepProgress =
        (stepsToday == null || stepsGoal <= 0)
            ? 0.0
            : (resolvedSteps / stepsGoal).clamp(0.0, 1.0);
    return [
      const DailyStatSnapshot(
        label: 'Calories consumed',
        displayValue: '0 kcal',
        targetLabel: 'Goal 0 kcal',
        progress: 0.0,
      ),
      DailyStatSnapshot(
        label: 'Steps',
        displayValue: stepDisplay,
        targetLabel: 'Goal ${_formatNumber(stepsGoal)}',
        progress: stepProgress,
      ),
      DailyStatSnapshot(
        label: 'Water intake',
        displayValue: '${waterLiters.toStringAsFixed(1)} L',
        targetLabel: 'Goal ${waterGoal.toStringAsFixed(1)} L',
        progress: 0.0,
      ),
      const DailyStatSnapshot(
        label: 'Sleep',
        displayValue: '0 h',
        targetLabel: 'Goal 0 h',
        progress: 0.0,
      ),
    ];
  }

  static WeeklyGoalSnapshot _buildWeeklyGoal(
    String goalLabel, {
    required int stepsGoal,
    List<int>? currentWeekSteps,
    List<int>? previousWeekSteps,
  }) {
    final current = _normalizeWeekSteps(currentWeekSteps);
    final previous = _normalizeWeekSteps(previousWeekSteps);
    final currentTotal = current.fold<int>(0, (sum, value) => sum + value);
    final previousTotal = previous.fold<int>(0, (sum, value) => sum + value);
    final completion =
        stepsGoal <= 0
            ? 0
            : ((currentTotal / (stepsGoal * 7)) * 100).clamp(0, 999).round();

    return WeeklyGoalSnapshot(
      dateRangeLabel: _formatWeekRange(DateTime.now()),
      completionLabel: '$completion%',
      changeLabel: _formatWeeklyChange(currentTotal, previousTotal),
      bars: List<GoalBarSnapshot>.generate(
        7,
        (index) => GoalBarSnapshot(
          dayLabel: _weekdayLabel(index),
          displayValue: _formatBarSteps(current[index]),
          amount: current[index].toDouble(),
        ),
      ),
    );
  }

  static String _formatSteps(int steps) {
    if (steps >= 1000) {
      final value = (steps / 1000).toStringAsFixed(1);
      return '${value}k steps';
    }
    return '$steps steps';
  }

  static List<int> _normalizeWeekSteps(List<int>? values) {
    if (values == null || values.isEmpty) {
      return List<int>.filled(7, 0);
    }
    if (values.length == 7) {
      return List<int>.from(values, growable: false);
    }

    final normalized = List<int>.filled(7, 0);
    final start = values.length > 7 ? values.length - 7 : 0;
    final slice = values.sublist(start);
    final offset = 7 - slice.length;
    for (var i = 0; i < slice.length; i++) {
      normalized[offset + i] = slice[i];
    }
    return normalized;
  }

  static String _formatBarSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }

  static String _formatWeeklyChange(int currentTotal, int previousTotal) {
    if (currentTotal == 0 && previousTotal == 0) {
      return '0% from last week';
    }
    if (previousTotal <= 0) {
      return '+100% from last week';
    }
    final delta = ((currentTotal - previousTotal) / previousTotal) * 100;
    final rounded = delta.round();
    final sign = rounded > 0 ? '+' : '';
    return '$sign$rounded% from last week';
  }

  static String _weekdayLabel(int index) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[index];
  }

  static String _formatNumber(int value) {
    final text = value.toString();
    if (text.length <= 3) {
      return text;
    }
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final position = text.length - i;
      buffer.write(text[i]);
      if (position > 1 && position % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  static List<ActivitySnapshot> _buildRecentActivities(String goalLabel) {
    return const [
      ActivitySnapshot(
        category: 'Activity',
        title: 'No activity yet',
        detail: '0 recorded sessions',
        metricLabel: '0',
      ),
      ActivitySnapshot(
        category: 'Workout',
        title: 'No workout yet',
        detail: '0 recorded sessions',
        metricLabel: '0',
      ),
      ActivitySnapshot(
        category: 'Recovery',
        title: 'No recovery data',
        detail: '0 recorded sessions',
        metricLabel: '0',
      ),
    ];
  }

  static WorkoutSnapshot _buildWorkout(String goalLabel) {
    return const WorkoutSnapshot(
      title: 'Workout',
      duration: '0 min',
      intensity: '0%',
      completedWorkouts: 0,
      exercises: ['0 exercises logged'],
      recentWorkouts: [],
    );
  }

  static ProgressSnapshot _buildProgress(
    String goalLabel,
    double currentWeightKg,
  ) {
    final points = [
      const WeightPoint(label: 'W1', value: 0),
      const WeightPoint(label: 'W2', value: 0),
      const WeightPoint(label: 'W3', value: 0),
      const WeightPoint(label: 'W4', value: 0),
      const WeightPoint(label: 'W5', value: 0),
      const WeightPoint(label: 'Now', value: 0),
    ];
    return ProgressSnapshot(
      headline: 'Weight progress',
      summary: '0 kg change',
      weightPoints: points,
      weeklyStats: const [
        WeeklyStatSnapshot(
          label: 'Workouts',
          value: '0',
          detail: 'Sessions completed',
        ),
        WeeklyStatSnapshot(
          label: 'Avg steps',
          value: '0',
          detail: 'Steps logged',
        ),
        WeeklyStatSnapshot(
          label: 'Water',
          value: '0 L',
          detail: 'Daily average',
        ),
      ],
    );
  }

  static String _goalLabel(String? goal) {
    switch (goal) {
      case 'Lose Weight':
        return 'Fat loss';
      case 'Build Muscle':
        return 'Muscle gain';
      default:
        return 'Stay active';
    }
  }

  static String _goalSummary(String goalLabel) {
    switch (goalLabel) {
      case 'Fat loss':
        return 'Tight calorie control with higher movement and smart recovery.';
      case 'Muscle gain':
        return 'Push strength, fuel recovery, and keep training volume high.';
      default:
        return 'Build a balanced routine with movement, hydration, and sleep.';
    }
  }

  static String _formatWeight(double weight) {
    final wholeNumber = weight == weight.roundToDouble();
    return '${wholeNumber ? weight.toStringAsFixed(0) : weight.toStringAsFixed(1)} kg';
  }

  static String _formatWeekRange(DateTime now) {
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return '${_monthLabel(monday.month)} ${monday.day} - ${_monthLabel(sunday.month)} ${sunday.day}';
  }

  static String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

class OverviewTileSnapshot {
  const OverviewTileSnapshot({
    required this.kind,
    required this.title,
    required this.value,
    required this.detail,
  });

  final OverviewTileKind kind;
  final String title;
  final String value;
  final String detail;
}

enum OverviewTileKind { activity, hydration, calories, weeklyGoal }

class DailyStatSnapshot {
  const DailyStatSnapshot({
    required this.label,
    required this.displayValue,
    required this.targetLabel,
    required this.progress,
  });

  final String label;
  final String displayValue;
  final String targetLabel;
  final double progress;
}

class WeeklyGoalSnapshot {
  const WeeklyGoalSnapshot({
    required this.dateRangeLabel,
    required this.completionLabel,
    required this.changeLabel,
    required this.bars,
  });

  final String dateRangeLabel;
  final String completionLabel;
  final String changeLabel;
  final List<GoalBarSnapshot> bars;
}

class GoalBarSnapshot {
  const GoalBarSnapshot({
    required this.dayLabel,
    required this.displayValue,
    required this.amount,
  });

  final String dayLabel;
  final String displayValue;
  final double amount;
}

class ActivitySnapshot {
  const ActivitySnapshot({
    required this.category,
    required this.title,
    required this.detail,
    required this.metricLabel,
  });

  final String category;
  final String title;
  final String detail;
  final String metricLabel;
}

class WorkoutSnapshot {
  const WorkoutSnapshot({
    required this.title,
    required this.duration,
    required this.intensity,
    required this.completedWorkouts,
    required this.exercises,
    required this.recentWorkouts,
  });

  final String title;
  final String duration;
  final String intensity;
  final int completedWorkouts;
  final List<String> exercises;
  final List<String> recentWorkouts;
}

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.headline,
    required this.summary,
    required this.weightPoints,
    required this.weeklyStats,
  });

  final String headline;
  final String summary;
  final List<WeightPoint> weightPoints;
  final List<WeeklyStatSnapshot> weeklyStats;
}

class WeightPoint {
  const WeightPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class WeeklyStatSnapshot {
  const WeeklyStatSnapshot({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;
}
