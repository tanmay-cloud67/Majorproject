import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'esp32_health_band_service.dart';

class StepsSnapshot {
  const StepsSnapshot({
    required this.stepsToday,
    required this.lastUpdated,
    this.rawSteps,
    this.status = StepsStatus.live,
  });

  final int stepsToday;
  final int? rawSteps;
  final DateTime lastUpdated;
  final StepsStatus status;
}

class HourlyActivitySnapshot {
  const HourlyActivitySnapshot({
    required this.stepsPerHour,
    required this.lastUpdated,
  });

  final List<int> stepsPerHour;
  final DateTime lastUpdated;
}

class DailyStepsEntry {
  const DailyStepsEntry({required this.date, required this.steps});

  final DateTime date;
  final int steps;
}

class WeeklyStepsSnapshot {
  const WeeklyStepsSnapshot({
    required this.dailySteps,
    required this.currentWeekSteps,
    required this.previousWeekSteps,
    required this.monthlyHistory,
    required this.averageSteps,
    required this.lastUpdated,
  });

  final List<int> dailySteps;
  final List<int> currentWeekSteps;
  final List<int> previousWeekSteps;
  final List<DailyStepsEntry> monthlyHistory;
  final double averageSteps;
  final DateTime lastUpdated;
}

enum StepsStatus { live, permissionRequired, unavailable }

class StepsService {
  StepsService._();

  static final StepsService instance = StepsService._();

  static const _baselineKey = 'steps_baseline';
  static const _baselineDateKey = 'steps_baseline_date';
  static const _hourlyKey = 'steps_hourly';
  static const _hourlyDateKey = 'steps_hourly_date';
  static const _lastStepsKey = 'steps_last_value';
  static const _dailyTotalsKey = 'steps_daily_totals';
  static const _calibrationKey = 'steps_calibration_factor';
  static const MethodChannel _backgroundChannel =
      MethodChannel('health/background_steps');

  final StreamController<StepsSnapshot> _controller =
      StreamController<StepsSnapshot>.broadcast();
  final StreamController<HourlyActivitySnapshot> _hourlyController =
      StreamController<HourlyActivitySnapshot>.broadcast();
  final StreamController<WeeklyStepsSnapshot> _weeklyController =
      StreamController<WeeklyStepsSnapshot>.broadcast();

  StreamSubscription<StepCount>? _subscription;
  int? _baseline;
  String? _baselineDate;
  bool _isStarted = false;
  List<int> _hourlySteps = List<int>.filled(24, 0);
  int? _lastSteps;
  String? _hourlyDate;
  Map<String, int> _dailyTotals = {};
  double _calibrationFactor = 1.0;

  double get calibrationFactor => _calibrationFactor;

  Future<void> start() async {
    await _ensureStarted();
  }

  Stream<StepsSnapshot> get stepsStream {
    _ensureStarted();
    return _controller.stream;
  }

  Stream<HourlyActivitySnapshot> get hourlyStream {
    _ensureStarted();
    return _hourlyController.stream;
  }

  Stream<WeeklyStepsSnapshot> get weeklyStepsStream {
    _ensureStarted();
    return _weeklyController.stream;
  }

  Future<void> _ensureStarted() async {
    if (_isStarted) {
      return;
    }
    _isStarted = true;

    if (kIsWeb) {
      _emitUnavailable();
      _isStarted = false;
      return;
    }

    final hasPermission = await _hasPermission();
    final permissionOk =
        hasPermission ? true : await _requestPermission();
    if (!permissionOk) {
      _emitPermissionRequired();
      _isStarted = false;
      return;
    }

    await _startBackgroundTracking();
    final prefs = await SharedPreferences.getInstance();
    await _loadStoredState(prefs: prefs, emitLiveSnapshot: true);

    _subscription = Pedometer.stepCountStream.listen(
      _handleStepCount,
      onError: _handleStreamError,
      cancelOnError: false,
    );
  }

  Future<void> requestPermission() async {
    final ok = await _requestPermission();
    if (!ok) {
      _emitPermissionRequired();
      return;
    }
    _isStarted = false;
    await _ensureStarted();
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  Future<void> refreshFromStorage() async {
    if (kIsWeb) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final hasPermission = await _hasPermission();
    if (!hasPermission) {
      _emitPermissionRequired();
      return;
    }

    await _loadStoredState(prefs: prefs, emitLiveSnapshot: true);
  }

  Future<void> setCalibrationFactor(double factor) async {
    final clamped = factor.clamp(0.5, 1.6);
    _calibrationFactor = clamped.toDouble();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_calibrationKey, _calibrationFactor);
    if (_lastSteps != null && _baseline != null) {
      final stepsToday = _applyCalibration(
        (_lastSteps! - _baseline!).clamp(0, 999999),
      );
      final now = DateTime.now();
      _controller.add(
        StepsSnapshot(
          stepsToday: stepsToday,
          rawSteps: _lastSteps,
          lastUpdated: now,
          status: StepsStatus.live,
        ),
      );
      _updateDailyTotals(_baselineDate ?? _formatDate(now), stepsToday);
    }
  }

  /// Called when ESP32 Health Band is connected to prioritize live band step count
  void updateBandSteps(int bandSteps) {
    final now = DateTime.now();
    _controller.add(
      StepsSnapshot(
        stepsToday: bandSteps,
        rawSteps: bandSteps,
        lastUpdated: now,
        status: StepsStatus.live,
      ),
    );
  }

  Future<bool> _hasPermission() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      final status = await Permission.sensors.status;
      return status.isGranted;
    }

    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.status;
      return status.isGranted;
    }

    return false;
  }

  Future<bool> _requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      final status = await Permission.sensors.request();
      return status.isGranted;
    }

    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      return status.isGranted;
    }

    return false;
  }

  void _handleStreamError(Object error) async {
    await _subscription?.cancel();
    _subscription = null;
    _isStarted = false;
    final hasPermission = await _hasPermission();
    if (!hasPermission) {
      _emitPermissionRequired();
      return;
    }
    _emitUnavailable();
  }

  void _handleStepCount(StepCount event) async {
    // If ESP32 Health Band is connected, preserve mobile readings unmutated
    if (ESP32HealthBandService.instance.currentData.isConnected) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedLastSteps = prefs.getInt(_lastStepsKey);
    final currentSteps = event.steps;

    // Avoid duplicate processing if background tracking already saved equal or higher step count
    if (storedLastSteps != null && storedLastSteps >= currentSteps && _lastSteps != null && storedLastSteps > _lastSteps!) {
      await _loadStoredState(prefs: prefs, emitLiveSnapshot: true);
      return;
    }

    final eventDate = _formatDate(event.timeStamp.toLocal());
    final previousSteps = storedLastSteps != null && storedLastSteps > (_lastSteps ?? 0)
        ? storedLastSteps
        : _lastSteps;
    final dateChanged = _baselineDate != eventDate;
    final resetDetected = (_baseline != null && currentSteps < _baseline!) ||
        (previousSteps != null && currentSteps < previousSteps);
    if (previousSteps != null && currentSteps == previousSteps) {
      return;
    }
    if (_baseline == null || dateChanged || resetDetected) {
      _baseline = currentSteps;
      _baselineDate = eventDate;
      await prefs.setInt(_baselineKey, _baseline!);
      await prefs.setString(_baselineDateKey, _baselineDate!);
      _hourlySteps = List<int>.filled(24, 0);
      _hourlyDate = eventDate;
      await prefs.setString(_hourlyDateKey, _hourlyDate!);
      await prefs.setString(_hourlyKey, _serializeHourlySteps(_hourlySteps));
    }

    final stepsToday = _applyCalibration(
      (currentSteps - (_baseline ?? 0)).clamp(0, 999999),
    );
    _controller.add(
      StepsSnapshot(
        stepsToday: stepsToday,
        rawSteps: currentSteps,
        lastUpdated: event.timeStamp.toLocal(),
        status: StepsStatus.live,
      ),
    );
    _updateDailyTotals(eventDate, stepsToday);

    _lastSteps = currentSteps;
    await prefs.setInt(_lastStepsKey, _lastSteps!);

    _updateHourly(event, previousSteps: previousSteps);
  }

  void _emitPermissionRequired() {
    _controller.add(
      StepsSnapshot(
        stepsToday: 0,
        rawSteps: null,
        lastUpdated: DateTime.now(),
        status: StepsStatus.permissionRequired,
      ),
    );
    _emitWeeklySnapshot(DateTime.now());
  }

  void _emitUnavailable() {
    _controller.add(
      StepsSnapshot(
        stepsToday: 0,
        rawSteps: null,
        lastUpdated: DateTime.now(),
        status: StepsStatus.unavailable,
      ),
    );
    _emitWeeklySnapshot(DateTime.now());
  }

  void _updateHourly(StepCount event, {required int? previousSteps}) {
    final time = event.timeStamp.toLocal();
    final eventDate = _formatDate(time);
    if (_hourlyDate != eventDate) {
      _hourlySteps = List<int>.filled(24, 0);
      _hourlyDate = eventDate;
    }

    final rawDelta =
        previousSteps != null && event.steps >= previousSteps
            ? event.steps - previousSteps
            : 0;
    final calibratedDelta = _applyCalibration(rawDelta);
    _hourlySteps[time.hour] =
        (_hourlySteps[time.hour] + calibratedDelta).clamp(0, 999999);

    final stepsToday = _baseline != null
        ? _applyCalibration((event.steps - _baseline!).clamp(0, 999999))
        : 0;
    final currentSum = _hourlySteps.fold<int>(0, (s, v) => s + v);
    if (stepsToday > currentSum) {
      _hourlySteps[time.hour] =
          (_hourlySteps[time.hour] + (stepsToday - currentSum)).clamp(0, 999999);
    }

    _hourlyController.add(
      HourlyActivitySnapshot(
        stepsPerHour: List<int>.from(_hourlySteps),
        lastUpdated: time,
      ),
    );

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_hourlyDateKey, _hourlyDate ?? _formatDate(time));
      prefs.setString(_hourlyKey, _serializeHourlySteps(_hourlySteps));
    });
  }

  void _updateDailyTotals(String dateKey, int stepsToday) {
    _dailyTotals[dateKey] = stepsToday;
    _pruneDailyTotals(dateKey);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_dailyTotalsKey, jsonEncode(_dailyTotals));
    });
    _emitWeeklySnapshot(DateTime.now());
  }

  void _emitWeeklySnapshot(DateTime now) {
    final dailySteps = _computeLastSevenDays(now);
    final currentWeekSteps = _computeWeekSteps(now);
    final previousWeekSteps = _computeWeekSteps(now, weeksAgo: 1);
    final monthlyHistory = _computeLastThirtyDaysHistory(now);
    final sum = dailySteps.fold<int>(0, (total, value) => total + value);
    final average = dailySteps.isEmpty ? 0.0 : sum / dailySteps.length;
    _weeklyController.add(
      WeeklyStepsSnapshot(
        dailySteps: dailySteps,
        currentWeekSteps: currentWeekSteps,
        previousWeekSteps: previousWeekSteps,
        monthlyHistory: monthlyHistory,
        averageSteps: average,
        lastUpdated: now,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
    await _hourlyController.close();
    await _weeklyController.close();
  }

  Map<String, int> _loadDailyTotals(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      return decoded.map<String, int>(
        (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
      );
    } catch (_) {
      return {};
    }
  }

  void _pruneDailyTotals(String todayKey) {
    final today = DateTime.tryParse(todayKey) ?? DateTime.now();
    final cutoff = today.subtract(const Duration(days: 29));
    _dailyTotals.removeWhere((key, value) {
      final date = DateTime.tryParse(key);
      return date == null || date.isBefore(cutoff);
    });
  }

  List<int> _computeLastSevenDays(DateTime now) {
    final result = <int>[];
    for (var i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _formatDate(date);
      result.add(_dailyTotals[key] ?? 0);
    }
    return result;
  }

  List<int> _computeWeekSteps(DateTime now, {int weeksAgo = 0}) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final weekStart = monday.subtract(Duration(days: weeksAgo * 7));
    final result = <int>[];
    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      result.add(_dailyTotals[_formatDate(date)] ?? 0);
    }
    return result;
  }

  List<DailyStepsEntry> _computeLastThirtyDaysHistory(DateTime now) {
    final result = <DailyStepsEntry>[];
    for (var i = 29; i >= 0; i--) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      result.add(
        DailyStepsEntry(
          date: date,
          steps: _dailyTotals[_formatDate(date)] ?? 0,
        ),
      );
    }
    return result;
  }

  List<int> _loadHourlySteps(
    String? raw,
    String? rawDate,
    String today,
  ) {
    if (raw == null || raw.trim().isEmpty) {
      return List<int>.filled(24, 0);
    }
    if (rawDate != null && rawDate != today) {
      return List<int>.filled(24, 0);
    }
    final parts = raw.split(',');
    if (parts.length != 24) {
      return List<int>.filled(24, 0);
    }
    return parts
        .map((value) => int.tryParse(value) ?? 0)
        .toList(growable: false);
  }

  String _serializeHourlySteps(List<int> values) {
    return values.map((value) => value.toString()).join(',');
  }

  int _applyCalibration(int value) {
    final calibrated = (value * _calibrationFactor).round();
    return calibrated.clamp(0, 999999);
  }

  Future<void> _loadStoredState({
    required SharedPreferences prefs,
    required bool emitLiveSnapshot,
  }) async {
    _baseline = prefs.getInt(_baselineKey);
    _baselineDate = prefs.getString(_baselineDateKey);
    _lastSteps = prefs.getInt(_lastStepsKey);
    _hourlyDate = prefs.getString(_hourlyDateKey);
    _calibrationFactor = prefs.getDouble(_calibrationKey) ?? 1.0;

    final now = DateTime.now();
    final todayKey = _formatDate(now);
    _dailyTotals = _loadDailyTotals(prefs.getString(_dailyTotalsKey));
    final storedDailyTotals = Map<String, int>.from(_dailyTotals);
    _pruneDailyTotals(todayKey);
    if (!mapEquals(storedDailyTotals, _dailyTotals)) {
      await prefs.setString(_dailyTotalsKey, jsonEncode(_dailyTotals));
    }
    _hourlySteps = _loadHourlySteps(
      prefs.getString(_hourlyKey),
      _hourlyDate,
      todayKey,
    );

    final hasBaselineToday =
        _baseline != null &&
        _baselineDate == todayKey &&
        _lastSteps != null;
    final initialSteps =
        hasBaselineToday
            ? _applyCalibration(
              (_lastSteps! - (_baseline ?? 0)).clamp(0, 999999),
            )
            : (_dailyTotals[todayKey] ?? 0);

    final currentSum = _hourlySteps.fold<int>(0, (s, v) => s + v);
    if (initialSteps > currentSum) {
      _hourlySteps[now.hour] =
          (_hourlySteps[now.hour] + (initialSteps - currentSum)).clamp(0, 999999);
    }

    _controller.add(
      StepsSnapshot(
        stepsToday: initialSteps,
        rawSteps: _lastSteps,
        lastUpdated: now,
        status: emitLiveSnapshot ? StepsStatus.live : StepsStatus.unavailable,
      ),
    );
    _hourlyController.add(
      HourlyActivitySnapshot(
        stepsPerHour: List<int>.from(_hourlySteps),
        lastUpdated: now,
      ),
    );
    _emitWeeklySnapshot(now);
  }

  Future<void> _startBackgroundTracking() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    try {
      await _backgroundChannel.invokeMethod<void>('startBackgroundTracking');
    } catch (_) {
      // Keep the in-app pedometer flow alive even if background startup fails.
    }
  }
}
