import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/providers.dart';
import '../features/alerts/alert_fullscreen.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/home/home_screen.dart';
import '../features/pairing/pairing_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/timeline/timeline_screen.dart';
import 'responsive.dart';
import 'theme.dart';

/// 하단 네비게이션 선택 인덱스(탭: 0 홈 · 1 타임라인 · 2 알림 · 3 프로필).
class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int i) => state = i;
}

final navIndexProvider =
    NotifierProvider<NavIndexNotifier, int>(NavIndexNotifier.new);

/// 메인 셸: IndexedStack 4탭 + 커스텀 하단 바(가운데 + 액션).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const List<Widget> _tabs = <Widget>[
    HomeScreen(),
    TimelineScreen(),
    AlertsScreen(),
    ProfileScreen(),
  ];

  String? _lastShownAlertId;

  @override
  Widget build(BuildContext context) {
    final int index = ref.watch(navIndexProvider);
    final int unread = ref.watch(unacknowledgedCountProvider);

    // 새 치명 알림 발생 시 풀스크린 경보 표시(6.5).
    ref.listen<List<AlertEvent>>(alertsProvider, (prev, next) {
      if (next.isEmpty) return;
      final AlertEvent newest = next.first;
      if (newest.severity == AlertSeverity.critical &&
          !newest.acknowledged &&
          newest.id != _lastShownAlertId) {
        _lastShownAlertId = newest.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showCriticalAlert(context, ref, newest);
        });
      }
    });

    return Scaffold(
      extendBody: true,
      // 기종 반응형: 넓은 화면에서는 콘텐츠/하단 바를 중앙 폭으로 제한한다.
      body: ResponsiveCenter(
        child: IndexedStack(index: index, children: _tabs),
      ),
      // 하단 바는 높이를 자식(66px)에 맞춰야 한다(heightFactor: 1).
      // 넓은 화면에서는 가운데 정렬 + 최대폭 제한으로 반응형 처리.
      bottomNavigationBar: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _BottomBar(
            currentIndex: index,
            unread: unread,
            onTap: (int i) => ref.read(navIndexProvider.notifier).set(i),
            onCenter: () => _openQuickActions(context),
          ),
        ),
      ),
    );
  }

  void _openQuickActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                _sheetItem(ctx, Icons.sensors, '기기 연결(시리얼)',
                    () => _push(context, const PairingScreen())),
                _sheetItem(ctx, Icons.tune, '설정',
                    () => _push(context, const SettingsScreen())),
              ],
            ),
          ),
        );
      },
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _sheetItem(
      BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label,
          style: const TextStyle(color: AppColors.textPrimary)),
      onTap: onTap,
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.unread,
    required this.onTap,
    required this.onCenter,
  });

  final int currentIndex;
  final int unread;
  final ValueChanged<int> onTap;
  final VoidCallback onCenter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _navIcon(Icons.home_rounded, 0),
            _navIcon(Icons.bar_chart_rounded, 1),
            _centerButton(),
            _navIcon(Icons.notifications_rounded, 2, badge: unread),
            _navIcon(Icons.person_rounded, 3),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, int index, {int badge = 0}) {
    final bool active = currentIndex == index;
    final Widget iconWidget = Icon(
      icon,
      size: 26,
      color: active ? AppColors.textPrimary : AppColors.textTertiary,
    );
    return IconButton(
      onPressed: () => onTap(index),
      icon: badge > 0
          ? Badge(
              label: Text('$badge'),
              backgroundColor: AppColors.red,
              child: iconWidget,
            )
          : iconWidget,
    );
  }

  Widget _centerButton() {
    return GestureDetector(
      onTap: onCenter,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }
}
