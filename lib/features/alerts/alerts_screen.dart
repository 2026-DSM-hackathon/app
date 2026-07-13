import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_pill.dart';

/// 알림 목록(6.5): 알림 히스토리 + ACK/에스컬레이션 표시.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AlertEvent> alerts = ref.watch(alertsProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          _Header(
            hasAlerts: alerts.isNotEmpty,
            onClearAll: () => ref.read(alertsProvider.notifier).clearAll(),
          ),
          Expanded(
            child: alerts.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    itemCount: alerts.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final AlertEvent alert = alerts[index];
                      return _AlertCard(
                        alert: alert,
                        onAcknowledge: () => ref
                            .read(alertsProvider.notifier)
                            .acknowledge(alert.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 상단 제목 + (알림이 있을 때만) "모두 지우기" 버튼.
class _Header extends StatelessWidget {
  const _Header({required this.hasAlerts, required this.onClearAll});

  final bool hasAlerts;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final Widget? clearButton = hasAlerts
        ? TextButton(
            onPressed: onClearAll,
            child: const Text('모두 지우기'),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          const Text(
            '알림',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          ?clearButton,
        ],
      ),
    );
  }
}

/// 알림이 하나도 없을 때의 빈 상태 화면.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.notifications_off_outlined,
              size: 48, color: AppColors.textTertiary),
          SizedBox(height: 12),
          Text(
            '알림이 없어요',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// 알림 한 건을 나타내는 카드(심각도 배지 + 본문 + ACK/에스컬레이션).
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onAcknowledge});

  final AlertEvent alert;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final Color color = _sevColor(alert.severity);
    final IconData icon = _sevIcon(alert.severity);
    final Widget ackWidget = alert.acknowledged
        ? const StatusPill(label: '확인됨', color: AppColors.green)
        : FilledButton(
            onPressed: onAcknowledge,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('확인', style: TextStyle(fontSize: 13)),
          );

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  alert.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('a h:mm', 'en').format(alert.time),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              ackWidget,
              if (alert.escalated) ...<Widget>[
                const SizedBox(height: 6),
                const StatusPill(label: '에스컬레이션', color: AppColors.red),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

Color _sevColor(AlertSeverity severity) => switch (severity) {
      AlertSeverity.critical => AppColors.red,
      AlertSeverity.warning => AppColors.orange,
      AlertSeverity.info => AppColors.blue,
    };

IconData _sevIcon(AlertSeverity severity) => switch (severity) {
      AlertSeverity.critical => Icons.warning_amber_rounded,
      AlertSeverity.warning => Icons.timelapse_rounded,
      AlertSeverity.info => Icons.info_outline,
    };
