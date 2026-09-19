import 'package:flutter_test/flutter_test.dart';
import 'package:health/models/dashboard_snapshot.dart';
import 'package:health/models/user_profile.dart';

void main() {
  test('builds a fat loss dashboard from a weight-loss profile', () {
    const profile = UserProfile(
      uid: 'user-1',
      email: 'alex@example.com',
      name: 'Alex',
      weight: 84.2,
      goal: 'Lose Weight',
      profileCompleted: true,
    );

    final snapshot = DashboardSnapshot.fromProfile(
      fallbackName: 'Fallback',
      fallbackEmail: 'fallback@example.com',
      profile: profile,
    );

    expect(snapshot.name, 'Alex');
    expect(snapshot.goalLabel, 'Fat loss');
    expect(snapshot.currentWeightLabel, '84.2 kg');
    expect(snapshot.overviewTiles, hasLength(4));
    expect(snapshot.dailyStats, hasLength(4));
    expect(snapshot.weeklyGoal.completionLabel, '0%');
    expect(snapshot.recentActivities.first.title, 'No activity yet');
    expect(snapshot.workout.title, 'Workout');
    expect(snapshot.progress.summary, '0 kg change');
    expect(snapshot.progress.weightPoints.last.value, 0);
  });

  test('falls back cleanly for a general activity dashboard', () {
    final snapshot = DashboardSnapshot.fromProfile(
      fallbackName: 'Jamie',
      fallbackEmail: 'jamie@example.com',
    );

    expect(snapshot.name, 'Jamie');
    expect(snapshot.email, 'jamie@example.com');
    expect(snapshot.goalLabel, 'Stay active');
    expect(snapshot.currentWeightLabel, '0 kg');
    expect(snapshot.weeklyGoal.bars, hasLength(7));
    expect(snapshot.workout.completedWorkouts, 0);
    expect(snapshot.recentActivities.first.metricLabel, '0');
    expect(snapshot.progress.weeklyStats.first.value, '0');
  });

  test('uses saved weekly step history for goal progress', () {
    final snapshot = DashboardSnapshot.fromProfile(
      fallbackName: 'Jamie',
      fallbackEmail: 'jamie@example.com',
      stepsGoal: 10000,
      currentWeekSteps: const [8000, 10000, 9000, 11000, 7000, 12000, 13000],
      previousWeekSteps: const [
        4000,
        5000,
        4500,
        5500,
        3500,
        6000,
        6500,
      ],
    );

    expect(snapshot.weeklyGoal.completionLabel, '100%');
    expect(snapshot.weeklyGoal.changeLabel, '+100% from last week');
    expect(snapshot.weeklyGoal.bars, hasLength(7));
    expect(snapshot.weeklyGoal.bars.first.dayLabel, 'Mon');
    expect(snapshot.weeklyGoal.bars.first.displayValue, '8.0k');
    expect(snapshot.overviewTiles.last.value, '100%');
  });
}
