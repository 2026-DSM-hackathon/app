import 'package:flutter/material.dart';

import 'status_chip.dart';

/// 사람 감지 알림 카드.
///
/// 차량 내부에 탑승자가 감지되었는지 여부를 표시한다.
class PersonDetectionCard extends StatelessWidget {
  const PersonDetectionCard({super.key, required this.personDetected});

  /// 차량 내부 사람 감지 여부.
  final bool personDetected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = personDetected ? colors.tertiary : colors.outline;

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
              child: Icon(personDetected ? Icons.person : Icons.person_off),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('사람 감지'),
                  const SizedBox(height: 4),
                  Text(
                    personDetected ? '탑승자 감지됨' : '탑승자 없음',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                  ),
                ],
              ),
            ),
            StatusChip(
              label: personDetected ? '감지' : '없음',
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}
