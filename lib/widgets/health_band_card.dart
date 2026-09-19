import 'dart:async';
import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../services/esp32_health_band_service.dart';

class HealthBandQuickCard extends StatefulWidget {
  const HealthBandQuickCard({super.key});

  @override
  State<HealthBandQuickCard> createState() => _HealthBandQuickCardState();
}

class _HealthBandQuickCardState extends State<HealthBandQuickCard> {
  late final StreamSubscription<HealthBandData> _sub;
  HealthBandData _data = ESP32HealthBandService.instance.currentData;

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
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.teal.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade900.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.watch_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _data.isConnected
                        ? (_data.isSimulating ? 'ESP32 Band (Sim)' : 'ESP32 Band Connected')
                        : 'ESP32 Wrist Band',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _data.isConnected ? Colors.tealAccent.shade400.withValues(alpha: 0.2) : Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _data.isConnected ? Colors.tealAccent.shade400 : Colors.white24,
                  ),
                ),
                child: Text(
                  _data.isConnected ? 'LIVE' : 'IDLE',
                  style: TextStyle(
                    color: _data.isConnected ? Colors.tealAccent.shade400 : Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricItem(
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFFF3B5C),
                val: _data.bpm > 0 ? '${_data.bpm}' : '--',
                unit: 'BPM',
              ),
              Container(height: 24, width: 1, color: Colors.white24),
              _metricItem(
                icon: Icons.water_drop_rounded,
                iconColor: Colors.cyanAccent,
                val: _data.spo2 > 0 ? '${_data.spo2}' : '--',
                unit: '% SpO2',
              ),
              Container(height: 24, width: 1, color: Colors.white24),
              _metricItem(
                icon: Icons.directions_walk_rounded,
                iconColor: Colors.amberAccent,
                val: '${_data.steps}',
                unit: 'Steps',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.healthBand);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              icon: const Icon(Icons.analytics_rounded, size: 16),
              label: const Text('Open Band Control Center', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricItem({
    required IconData icon,
    required Color iconColor,
    required String val,
    required String unit,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 4),
            Text(
              val,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }
}
