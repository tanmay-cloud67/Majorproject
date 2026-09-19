import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class FoodLogEntry {
  const FoodLogEntry({
    required this.id,
    required this.timestamp,
    required this.name,
    this.calories,
    this.photoPath,
    this.photoBase64,
  });

  final String id;
  final DateTime timestamp;
  final String name;
  final double? calories;
  final String? photoPath;
  final String? photoBase64;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'name': name,
        'calories': calories,
        'photoPath': photoPath,
        'photoBase64': photoBase64,
      };

  static FoodLogEntry fromJson(Map<String, dynamic> json) {
    return FoodLogEntry(
      id: json['id']?.toString() ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
              DateTime.now(),
      name: json['name']?.toString() ?? '',
      calories: (json['calories'] as num?)?.toDouble(),
      photoPath: json['photoPath']?.toString(),
      photoBase64: json['photoBase64']?.toString(),
    );
  }
}

class FoodLogService {
  FoodLogService._();

  static final FoodLogService instance = FoodLogService._();

  static const _entriesKey = 'food_log_entries';

  final StreamController<List<FoodLogEntry>> _controller =
      StreamController<List<FoodLogEntry>>.broadcast();
  List<FoodLogEntry> _entries = [];
  bool _loaded = false;

  Stream<List<FoodLogEntry>> get entriesStream {
    _ensureLoaded();
    return _controller.stream;
  }

  Future<void> addEntry({
    required String name,
    double? calories,
    String? photoPath,
  }) async {
    await _ensureLoaded();
    final trimmedPhotoPath = photoPath?.trim();
    final entry = FoodLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      name: name,
      calories: calories,
      photoPath: trimmedPhotoPath,
      photoBase64: await _readPhotoBase64(trimmedPhotoPath),
    );
    _entries = [entry, ..._entries];
    await _persist();
    _controller.add(List<FoodLogEntry>.unmodifiable(_entries));
  }

  Future<void> removeEntry(String id) async {
    await _ensureLoaded();
    _entries.removeWhere((entry) => entry.id == id);
    await _persist();
    _controller.add(List<FoodLogEntry>.unmodifiable(_entries));
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    _entries = _decodeEntries(raw);
    _controller.add(List<FoodLogEntry>.unmodifiable(_entries));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_entries.map((entry) => entry.toJson()).toList());
    await prefs.setString(_entriesKey, raw);
  }

  List<FoodLogEntry> _decodeEntries(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }
      return decoded
          .whereType<Map>()
          .map((item) => FoodLogEntry.fromJson(item.cast<String, dynamic>()))
          .where((entry) => entry.name.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  Future<String?> _readPhotoBase64(String? photoPath) async {
    if (photoPath == null || photoPath.isEmpty) {
      return null;
    }

    try {
      final file = File(photoPath);
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }
}
