import 'package:flutter/material.dart';

import 'person_detection_card.dart';
import 'vehicle_temperature_card.dart';

/// 알림 섹션.
///
/// 두 개의 하위 위젯(차량 온도, 사람 감지)을 하나로 묶어서 보여준다.
class NotificationSection extends StatelessWidget {
  const NotificationSection({
    super.key,
    required this.temperature,
    required this.personDetected,
  });

  /// 차량 내부 온도(섭씨).
  final double temperature;

  /// 차량 내부 사람 감지 여부.
  final bool personDetected;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.notifications_active_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text('알림', style: textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        VehicleTemperatureCard(temperature: temperature),
        const SizedBox(height: 12),
        PersonDetectionCard(personDetected: personDetected),
      ],
    );
  }
}
