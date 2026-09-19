import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'steps_service.dart';

/// Data model representing real-time telemetry from the ESP32 Wrist-Worn Health Band
class HealthBandData {
  const HealthBandData({
    required this.bpm,
    required this.spo2,
    required this.steps,
    required this.batteryLevel,
    required this.isConnected,
    required this.isSimulating,
    required this.deviceName,
    required this.lastUpdated,
  });

  final int bpm;
  final int spo2;
  final int steps;
  final int batteryLevel;
  final bool isConnected;
  final bool isSimulating;
  final String deviceName;
  final DateTime lastUpdated;

  HealthBandData copyWith({
    int? bpm,
    int? spo2,
    int? steps,
    int? batteryLevel,
    bool? isConnected,
    bool? isSimulating,
    String? deviceName,
    DateTime? lastUpdated,
  }) {
    return HealthBandData(
      bpm: bpm ?? this.bpm,
      spo2: spo2 ?? this.spo2,
      steps: steps ?? this.steps,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isConnected: isConnected ?? this.isConnected,
      isSimulating: isSimulating ?? this.isSimulating,
      deviceName: deviceName ?? this.deviceName,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static HealthBandData initial() {
    return HealthBandData(
      bpm: 0,
      spo2: 0,
      steps: 0,
      batteryLevel: 95,
      isConnected: false,
      isSimulating: false,
      deviceName: 'Disconnected',
      lastUpdated: DateTime.now(),
    );
  }
}

/// Service managing BLE connectivity, GATT characteristic subscriptions,
/// step synchronization, and fallback demo simulation mode.
class ESP32HealthBandService {
  ESP32HealthBandService._();

  static final ESP32HealthBandService instance = ESP32HealthBandService._();

  // BLE UUID Constants
  static final Guid hrServiceUuid = Guid("180D");
  static final Guid hrCharUuid = Guid("2A37");
  static final Guid batteryServiceUuid = Guid("180F");
  static final Guid batteryCharUuid = Guid("2A19");

  static final Guid customServiceUuid = Guid("19b10000-e8f2-537e-4f6c-d104768a1214");
  static final Guid spo2CharUuid = Guid("19b10001-e8f2-537e-4f6c-d104768a1214");
  static final Guid stepCharUuid = Guid("19b10002-e8f2-537e-4f6c-d104768a1214");

  final StreamController<HealthBandData> _controller =
      StreamController<HealthBandData>.broadcast();

  HealthBandData _currentData = HealthBandData.initial();
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  Timer? _simulatorTimer;
  final Random _random = Random();

  HealthBandData get currentData => _currentData;
  Stream<HealthBandData> get dataStream => _controller.stream;

  /// Start scanning for physical ESP32-Health-Band device over BLE
  Future<void> startBLEScan({
    void Function(String message)? onError,
    void Function()? onSuccess,
  }) async {
    if (_currentData.isSimulating) {
      stopSimulator();
    }

    try {
      // Check if Bluetooth is supported & available
      if (await FlutterBluePlus.isSupported == false) {
        onError?.call("Bluetooth Low Energy is not supported on this device.");
        return;
      }

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withNames: ['ESP32-Health-Band'],
      );

      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          if (r.device.platformName == 'ESP32-Health-Band' ||
              r.advertisementData.advName == 'ESP32-Health-Band') {
            await FlutterBluePlus.stopScan();
            await _connectToDevice(r.device, onSuccess: onSuccess, onError: onError);
            break;
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('[ESP32HealthBandService] BLE Scan Error: $e');
      }
      onError?.call("Scan error: $e. You can use Demo Simulator mode.");
    }
  }

  Future<void> _connectToDevice(
    BluetoothDevice device, {
    void Function()? onSuccess,
    void Function(String err)? onError,
  }) async {
    try {
      _connectedDevice = device;
      await device.connect(autoConnect: false);

      _connSub?.cancel();
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _onDisconnected();
        }
      });

      _updateState(
        _currentData.copyWith(
          isConnected: true,
          isSimulating: false,
          deviceName: device.platformName.isNotEmpty
              ? device.platformName
              : 'ESP32-Health-Band',
        ),
      );

      // Discover GATT Services
      final services = await device.discoverServices();
      for (final s in services) {
        // 1. Heart Rate Service
        if (s.uuid == hrServiceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid == hrCharUuid) {
              await c.setNotifyValue(true);
              c.lastValueStream.listen(_parseHeartRate);
            }
          }
        }

        // 2. Custom Health Service (SpO2 & Steps)
        if (s.uuid == customServiceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid == spo2CharUuid) {
              await c.setNotifyValue(true);
              c.lastValueStream.listen(_parseSpO2);
            } else if (c.uuid == stepCharUuid) {
              await c.setNotifyValue(true);
              c.lastValueStream.listen(_parseSteps);
            }
          }
        }

        // 3. Battery Service
        if (s.uuid == batteryServiceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid == batteryCharUuid) {
              await c.setNotifyValue(true);
              c.lastValueStream.listen(_parseBattery);
            }
          }
        }
      }

      onSuccess?.call();
    } catch (e) {
      if (kDebugMode) {
        print('[ESP32HealthBandService] Connection error: $e');
      }
      onError?.call("Connection error: $e");
    }
  }

  void _parseHeartRate(List<int> value) {
    if (value.length < 2) return;
    final flags = value[0];
    int bpm = 0;
    if ((flags & 0x01) == 0) {
      bpm = value[1];
    } else if (value.length >= 3) {
      bpm = value[1] | (value[2] << 8);
    }
    if (bpm > 0) {
      _updateState(_currentData.copyWith(bpm: bpm, lastUpdated: DateTime.now()));
    }
  }

  void _parseSpO2(List<int> value) {
    if (value.isEmpty) return;
    final spo2 = value[0];
    if (spo2 > 0) {
      _updateState(_currentData.copyWith(spo2: spo2, lastUpdated: DateTime.now()));
    }
  }

  void _parseSteps(List<int> value) {
    if (value.length < 4) return;
    final steps = value[0] | (value[1] << 8) | (value[2] << 16) | (value[3] << 24);
    _updateState(_currentData.copyWith(steps: steps, lastUpdated: DateTime.now()));
  }

  void _parseBattery(List<int> value) {
    if (value.isEmpty) return;
    _updateState(_currentData.copyWith(batteryLevel: value[0]));
  }

  Future<void> disconnect() async {
    _simulatorTimer?.cancel();
    _scanSub?.cancel();
    _connSub?.cancel();
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
    }
    _onDisconnected();
  }

  void _onDisconnected() {
    _connectedDevice = null;
    _updateState(
      HealthBandData.initial().copyWith(
        deviceName: 'Disconnected',
        isConnected: false,
        isSimulating: false,
      ),
    );
  }

  /// Toggle Demo Simulator mode for testing without physical BLE hardware
  void toggleSimulator() {
    if (_currentData.isSimulating) {
      stopSimulator();
    } else {
      startSimulator();
    }
  }

  void startSimulator() {
    if (_connectedDevice != null) {
      disconnect();
    }

    _updateState(
      HealthBandData(
        bpm: 74,
        spo2: 98,
        steps: 1420,
        batteryLevel: 92,
        isConnected: true,
        isSimulating: true,
        deviceName: 'ESP32 Band (Simulator)',
        lastUpdated: DateTime.now(),
      ),
    );

    _simulatorTimer?.cancel();
    _simulatorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final bpmNoise = (_random.nextDouble() - 0.5) * 4;
      final newBpm = (_currentData.bpm + bpmNoise).round().clamp(60, 140);
      final newSpo2 = 97 + _random.nextInt(3);
      final newSteps = _currentData.steps + _random.nextInt(3);

      _updateState(
        _currentData.copyWith(
          bpm: newBpm,
          spo2: newSpo2,
          steps: newSteps,
          lastUpdated: DateTime.now(),
        ),
      );
    });
  }

  void stopSimulator() {
    _simulatorTimer?.cancel();
    _simulatorTimer = null;
    _updateState(HealthBandData.initial());
  }

  void _updateState(HealthBandData newData) {
    _currentData = newData;
    _controller.add(_currentData);

    if (newData.isConnected) {
      StepsService.instance.updateBandSteps(newData.steps);
    } else {
      unawaited(StepsService.instance.refreshFromStorage());
    }
  }
}
