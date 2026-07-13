import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// 치명(critical) 알림을 풀스크린으로 표시하고 ACK를 받는다(6.5).
Future<void> showCriticalAlert(
  BuildContext context,
  WidgetRef ref,
  AlertEvent alert,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'critical-alert',
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (BuildContext ctx, _, _) =>
        _AlertFullscreen(alert: alert, ref: ref),
  );
}

class _AlertFullscreen extends StatelessWidget {
  const _AlertFullscreen({required this.alert, required this.ref});

  final AlertEvent alert;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 480,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: <Widget>[
                const Spacer(),
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.red, size: 60),
                ),
                const SizedBox(height: 28),
                Text(
                  alert.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  alert.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      ref.read(alertsProvider.notifier).acknowledge(alert.id);
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      '확인 (ACK)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('나중에',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
