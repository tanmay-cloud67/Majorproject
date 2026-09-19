import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WeightEntry {
  const WeightEntry({required this.date, required this.weight});

  final DateTime date;
  final double weight;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weight': weight,
      };

  static WeightEntry? fromJson(Map<String, dynamic> json) {
    final dateRaw = json['date'];
    final weightRaw = json['weight'];
    if (dateRaw is! String || weightRaw is! num) {
      return null;
    }
    final date = DateTime.tryParse(dateRaw);
    if (date == null) {
      return null;
    }
    return WeightEntry(date: date, weight: weightRaw.toDouble());
  }
}

class WeightLogSnapshot {
  const WeightLogSnapshot({required this.entries, required this.lastUpdated});

  final List<WeightEntry> entries;
  final DateTime lastUpdated;
}

class WeightService {
  WeightService._();

  static final WeightService instance = WeightService._();

  static const _weightsKey = 'weight_logs';

  final StreamController<WeightLogSnapshot> _controller =
      StreamController<WeightLogSnapshot>.broadcast();

  bool _isStarted = false;
  List<WeightEntry> _entries = [];

  Stream<WeightLogSnapshot> get weightStream {
    _ensureStarted();
    return _controller.stream;
  }

  List<WeightEntry> get entries => List.unmodifiable(_entries);

  Future<void> addWeight(double weight) async {
    await _ensureStarted();
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final updated = <WeightEntry>[];
    var replaced = false;
    for (final entry in _entries) {
      if (_dateKey(entry.date) == todayKey) {
        updated.add(WeightEntry(date: now, weight: weight));
        replaced = true;
      } else {
        updated.add(entry);
      }
    }
    if (!replaced) {
      updated.add(WeightEntry(date: now, weight: weight));
    }
    _entries = updated..sort((a, b) => a.date.compareTo(b.date));
    final prefs = await SharedPreferences.getInstance();
    await _persist(prefs);
    _emitSnapshot();
  }

  Future<void> _ensureStarted() async {
    if (_isStarted) {
      return;
    }
    _isStarted = true;
    final prefs = await SharedPreferences.getInstance();
    _entries = _loadEntries(prefs.getString(_weightsKey));
    _emitSnapshot();
  }

  void _emitSnapshot() {
    _controller.add(
      WeightLogSnapshot(entries: List<WeightEntry>.from(_entries), lastUpdated: DateTime.now()),
    );
  }

  List<WeightEntry> _loadEntries(String? raw) {
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
          .map(WeightEntry.fromJson)
          .whereType<WeightEntry>()
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(SharedPreferences prefs) async {
    final encoded = jsonEncode(
      _entries.map((entry) => entry.toJson()).toList(),
    );
    await prefs.setString(_weightsKey, encoded);
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
