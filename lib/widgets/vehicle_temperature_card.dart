import 'package:flutter/material.dart';

import 'status_chip.dart';

/// 차량 온도 알림 카드.
///
/// [warningThreshold] 이상이면 고온 경고 상태로 표시한다.
class VehicleTemperatureCard extends StatelessWidget {
  const VehicleTemperatureCard({
    super.key,
    required this.temperature,
    this.warningThreshold = 40.0,
  });

  /// 현재 차량 내부 온도(섭씨).
  final double temperature;

  /// 경고 임계 온도(섭씨). 이 값 이상이면 위험 상태로 표시한다.
  final double warningThreshold;

  bool get _isWarning => temperature >= warningThreshold;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = _isWarning ? colors.error : colors.primary;

    return Card(
      elevation: 0,
      color: accent.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.15),
              foregroundColor: accent,
              child: const Icon(Icons.thermostat),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('차량 온도'),
                  const SizedBox(height: 4),
                  Text(
                    '${temperature.toStringAsFixed(1)}°C',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                  ),
                ],
              ),
            ),
            StatusChip(
              label: _isWarning ? '고온 경고' : '정상',
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}
