import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WorkoutSession {
  const WorkoutSession({required this.startTime, required this.durationMinutes});

  final DateTime startTime;
  final int durationMinutes;

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'durationMinutes': durationMinutes,
      };

  static WorkoutSession? fromJson(Map<String, dynamic> json) {
    final startRaw = json['startTime'];
    final durationRaw = json['durationMinutes'];
    if (startRaw is! String || durationRaw is! num) {
      return null;
    }
    final start = DateTime.tryParse(startRaw);
    if (start == null) {
      return null;
    }
    return WorkoutSession(
      startTime: start,
      durationMinutes: durationRaw.toInt(),
    );
  }
}

class WorkoutSummary {
  const WorkoutSummary({
    required this.isActive,
    required this.activeMinutes,
    required this.activeSeconds,
    required this.todayMinutes,
    required this.weeklySessions,
    required this.intensityLabel,
    required this.recentLogs,
  });

  final bool isActive;
  final int activeMinutes;
  final int activeSeconds;
  final int todayMinutes;
  final int weeklySessions;
  final String intensityLabel;
  final List<String> recentLogs;
}

class WorkoutService {
  WorkoutService._();

  static final WorkoutService instance = WorkoutService._();

  static const _sessionsKey = 'workout_sessions';
  static const _activeStartKey = 'workout_active_start';

  final StreamController<WorkoutSummary> _controller =
      StreamController<WorkoutSummary>.broadcast();

  bool _isStarted = false;
  List<WorkoutSession> _sessions = [];
  DateTime? _activeStart;
  Timer? _ticker;

  Stream<WorkoutSummary> get summaryStream {
    _ensureStarted();
    return _controller.stream;
  }

  Future<void> startSession() async {
    await _ensureStarted();
    if (_activeStart != null) {
      return;
    }
    _activeStart = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeStartKey, _activeStart!.toIso8601String());
    _startTicker();
    _emitSummary(DateTime.now());
  }

  Future<void> endSession() async {
    await _ensureStarted();
    final start = _activeStart;
    if (start == null) {
      return;
    }
    final now = DateTime.now();
    final duration = now.difference(start).inMinutes;
    final safeDuration = duration <= 0 ? 1 : duration;
    _sessions.add(
      WorkoutSession(startTime: start, durationMinutes: safeDuration),
    );
    _activeStart = null;
    _ticker?.cancel();
    _ticker = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeStartKey);
    await _persistSessions(prefs);
    _emitSummary(now);
  }

  Future<void> _ensureStarted() async {
    if (_isStarted) {
      return;
    }
    _isStarted = true;
    final prefs = await SharedPreferences.getInstance();
    _sessions = _loadSessions(prefs.getString(_sessionsKey));
    final activeRaw = prefs.getString(_activeStartKey);
    _activeStart = activeRaw == null ? null : DateTime.tryParse(activeRaw);
    if (_activeStart != null) {
      _startTicker();
    }
    _emitSummary(DateTime.now());
  }

  void _emitSummary(DateTime now) {
    final todayKey = _dateKey(now);
    final todayMinutes = _sessions
        .where((session) => _dateKey(session.startTime) == todayKey)
        .fold<int>(0, (sum, session) => sum + session.durationMinutes);
    final weekSessions = _sessions
        .where(
          (session) =>
              session.startTime.isAfter(now.subtract(const Duration(days: 6))),
        )
        .length;
    final activeSeconds = _activeStart == null
        ? 0
        : now.difference(_activeStart!).inSeconds;
    final activeMinutes = _activeStart == null ? 0 : activeSeconds ~/ 60;
    final displayMinutes =
        _activeStart != null ? todayMinutes + activeMinutes : todayMinutes;
    final intensityLabel = _intensityLabel(displayMinutes);
    final logs = _sessions
        .reversed
        .take(3)
        .map((session) {
          final date = session.startTime;
          final label =
              '${_shortWeekday(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          return '$label • ${session.durationMinutes} min';
        })
        .toList(growable: false);

    _controller.add(
      WorkoutSummary(
        isActive: _activeStart != null,
        activeMinutes: activeMinutes,
        activeSeconds: activeSeconds,
        todayMinutes: displayMinutes,
        weeklySessions: weekSessions,
        intensityLabel: intensityLabel,
        recentLogs: logs.isEmpty ? ['No sessions logged'] : logs,
      ),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _emitSummary(DateTime.now());
    });
  }

  String _intensityLabel(int minutes) {
    if (minutes <= 0) {
      return '0 min';
    }
    if (minutes < 20) {
      return 'Low';
    }
    if (minutes < 45) {
      return 'Moderate';
    }
    return 'High';
  }

  List<WorkoutSession> _loadSessions(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }
      return decoded
          .map((entry) => entry is Map<String, dynamic> ? entry : null)
          .whereType<Map<String, dynamic>>()
          .map(WorkoutSession.fromJson)
          .whereType<WorkoutSession>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistSessions(SharedPreferences prefs) async {
    final encoded = jsonEncode(
      _sessions.map((session) => session.toJson()).toList(),
    );
    await prefs.setString(_sessionsKey, encoded);
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _shortWeekday(DateTime date) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[date.weekday - 1];
  }
}
