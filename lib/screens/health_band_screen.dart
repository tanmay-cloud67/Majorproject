import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/esp32_health_band_service.dart';

class HealthBandScreen extends StatefulWidget {
  const HealthBandScreen({super.key});

  @override
  State<HealthBandScreen> createState() => _HealthBandScreenState();
}

class _HealthBandScreenState extends State<HealthBandScreen>
    with SingleTickerProviderStateMixin {
  late final StreamSubscription<HealthBandData> _sub;
  HealthBandData _data = ESP32HealthBandService.instance.currentData;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _sub = ESP32HealthBandService.instance.dataStream.listen((newData) {
      if (mounted) {
        setState(() {
          _data = newData;
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onConnectPressed() {
    if (_data.isConnected && !_data.isSimulating) {
      ESP32HealthBandService.instance.disconnect();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Scanning for 'ESP32-Health-Band' over Bluetooth..."),
          duration: Duration(seconds: 3),
        ),
      );
      ESP32HealthBandService.instance.startBLEScan(
        onError: (err) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err), backgroundColor: Colors.orange.shade800),
            );
          }
        },
        onSuccess: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Connected to ESP32 Health Band!"),
                backgroundColor: Colors.teal,
              ),
            );
          }
        },
      );
    }
  }

  void _onSimulatorPressed() {
    ESP32HealthBandService.instance.toggleSimulator();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EC),
      appBar: AppBar(
        title: const Text(
          'ESP32 Health Band',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _data.isConnected
                  ? (_data.isSimulating ? Colors.cyan.shade100 : Colors.teal.shade100)
                  : Colors.red.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _data.isConnected
                    ? (_data.isSimulating ? Colors.cyan : Colors.teal)
                    : Colors.red.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: _data.isConnected
                      ? (_data.isSimulating ? Colors.cyan.shade800 : Colors.teal.shade800)
                      : Colors.red.shade800,
                ),
                const SizedBox(width: 6),
                Text(
                  _data.isConnected
                      ? (_data.isSimulating ? 'Simulator' : 'BLE Connected')
                      : 'Disconnected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _data.isConnected
                        ? (_data.isSimulating ? Colors.cyan.shade900 : Colors.teal.shade900)
                        : Colors.red.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Controls Card
            _buildControlsCard(),

            const SizedBox(height: 16),

            // Live Pulse Waveform & BPM Card
            _buildLivePulseCard(),

            const SizedBox(height: 16),

            // SpO2 & Steps Dual Metric Cards Row
            Row(
              children: [
                Expanded(child: _buildSpO2Card()),
                const SizedBox(width: 12),
                Expanded(child: _buildStepsCard()),
              ],
            ),

            const SizedBox(height: 16),

            // Active Burn & Distance Metrics Card
            _buildCaloriesDistanceCard(),

            const SizedBox(height: 16),

            // Hardware Telemetry & Safety Card
            _buildHardwareTelemetryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.watch_rounded, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  _data.deviceName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _onConnectPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      _data.isConnected && !_data.isSimulating
                          ? Icons.bluetooth_disabled_rounded
                          : Icons.bluetooth_searching_rounded,
                    ),
                    label: Text(
                      _data.isConnected && !_data.isSimulating
                          ? 'Disconnect'
                          : 'Scan & Connect',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _onSimulatorPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _data.isSimulating ? Colors.cyan.shade900 : Colors.black87,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: _data.isSimulating
                          ? Colors.cyan
                          : Colors.grey.shade400,
                    ),
                  ),
                  icon: Icon(
                    _data.isSimulating ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: _data.isSimulating ? Colors.cyan : Colors.teal,
                  ),
                  label: Text(_data.isSimulating ? 'Stop Sim' : 'Demo Sim'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePulseCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF3B5C), size: 22),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Real-Time Heart Rate',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF3B5C).withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_data.bpm > 0 ? _data.bpm : "--"} BPM',
                  style: const TextStyle(
                    color: Color(0xFFFF3B5C),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Synthetic Pulse Waveform Canvas
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(
              painter: PulsePainter(bpm: _data.bpm > 0 ? _data.bpm : 70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpO2Card() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyan.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.water_drop_rounded, color: Colors.cyan),
              ),
              const SizedBox(width: 8),
              const Text(
                'SpO2 Saturation',
                style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_data.spo2 > 0 ? _data.spo2 : "--"}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              const Text('%', style: TextStyle(fontSize: 14, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _data.spo2 >= 95 ? 'Optimal' : (_data.spo2 > 0 ? 'Low SpO2' : 'No Signal'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_walk_rounded, color: Colors.teal),
              ),
              const SizedBox(width: 8),
              const Text(
                'Band Steps',
                style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_data.steps}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (_data.steps / 10000).clamp(0.0, 1.0),
            backgroundColor: Colors.teal.shade50,
            color: Colors.teal,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesDistanceCard() {
    final calories = (_data.steps * 0.04).round();
    final distanceKm = (_data.steps * 0.00075).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text('Active Burn', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 4),
                  Text('$calories kcal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ],
          ),
          Container(height: 30, width: 1, color: Colors.grey.shade300),
          Column(
            children: [
              const Text('Est. Distance', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.map_rounded, color: Colors.blue, size: 18),
                  const SizedBox(width: 4),
                  Text('$distanceKm km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareTelemetryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hardware Telemetry',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          _telemetryRow('Brain MCU', 'ESP32 (GPIO21 / GPIO22)'),
          _telemetryRow('MAX30102 Sensor', 'Pulse Oximeter (0x57)'),
          _telemetryRow('MPU6050 Motion', '6-Axis Accelerometer (0x68)'),
          _telemetryRow('OLED Display', 'SSD1306 128x64 (0x3C)'),
          _telemetryRow('Li-ion Battery', '${_data.batteryLevel}% (TP4056)'),
          const Divider(height: 20),
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Hobby fitness tracker project. MAX30102 readings are sensitive to skin contact & movement.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _telemetryRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

class PulsePainter extends CustomPainter {
  PulsePainter({required this.bpm});
  final int bpm;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF3B5C)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final centerY = size.height / 2;
    final points = size.width.toInt();

    path.moveTo(0, centerY);

    for (int x = 0; x < points; x += 3) {
      final progress = (x / points) * 4 * pi;
      final wave = sin(progress) * 15 * (sin(progress * 0.5) + 0.5);
      path.lineTo(x.toDouble(), centerY - wave);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PulsePainter oldDelegate) => oldDelegate.bpm != bpm;
}
