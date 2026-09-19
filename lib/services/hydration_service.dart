import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HydrationSnapshot {
  const HydrationSnapshot({
    required this.todayLiters,
    required this.goalLiters,
    required this.weeklyAverageLiters,
    required this.lastUpdated,
  });

  final double todayLiters;
  final double goalLiters;
  final double weeklyAverageLiters;
  final DateTime lastUpdated;
}

class HydrationService {
  HydrationService._();

  static final HydrationService instance = HydrationService._();

  static const _dailyWaterKey = 'water_daily_totals';
  static const _goalKey = 'water_goal_liters';

  final StreamController<HydrationSnapshot> _controller =
      StreamController<HydrationSnapshot>.broadcast();

  bool _isStarted = false;
  Map<String, double> _dailyTotals = {};
  double _goalLiters = 0;

  Stream<HydrationSnapshot> get hydrationStream {
    _ensureStarted();
    return _controller.stream;
  }

  Future<void> addWater(double liters) async {
    await _ensureStarted();
    if (liters <= 0) {
      return;
    }
    final now = DateTime.now();
    final key = _dateKey(now);
    final current = _dailyTotals[key] ?? 0;
    _dailyTotals[key] = current + liters;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyWaterKey, jsonEncode(_dailyTotals));
    _emitSnapshot(now);
  }

  Future<void> setGoal(double liters) async {
    await _ensureStarted();
    final clamped = liters.clamp(0, 6).toDouble();
    _goalLiters = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_goalKey, _goalLiters);
    _emitSnapshot(DateTime.now());
  }

  Future<void> _ensureStarted() async {
    if (_isStarted) {
      return;
    }
    _isStarted = true;
    final prefs = await SharedPreferences.getInstance();
    _dailyTotals = _loadDailyTotals(prefs.getString(_dailyWaterKey));
    _goalLiters = prefs.getDouble(_goalKey) ?? 0;
    _emitSnapshot(DateTime.now());
  }

  void _emitSnapshot(DateTime now) {
    final todayKey = _dateKey(now);
    final todayLiters = _dailyTotals[todayKey] ?? 0;
    final lastSeven = _computeLastSevenDays(now);
    final sum = lastSeven.fold<double>(0, (total, value) => total + value);
    final average = lastSeven.isEmpty ? 0.0 : sum / lastSeven.length;
    _controller.add(
      HydrationSnapshot(
        todayLiters: todayLiters,
        goalLiters: _goalLiters,
        weeklyAverageLiters: average,
        lastUpdated: now,
      ),
    );
  }

  Map<String, double> _loadDailyTotals(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      return decoded.map<String, double>(
        (key, value) =>
            MapEntry(key.toString(), (value as num?)?.toDouble() ?? 0),
      );
    } catch (_) {
      return {};
    }
  }

  List<double> _computeLastSevenDays(DateTime now) {
    final result = <double>[];
    for (var i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      result.add(_dailyTotals[key] ?? 0);
    }
    return result;
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
