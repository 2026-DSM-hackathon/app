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
import '../widgets/status_pill.dart';
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

  /// 동시에 겹쳐 띄우는 풀스크린 위험 경보 최대 개수(초과분은 무시).
  static const int _maxConcurrentCriticalAlerts = 3;

  String? _lastShownAlertId;
  int _openCriticalAlerts = 0;

  @override
  Widget build(BuildContext context) {
    final int index = ref.watch(navIndexProvider);
    final int unread = ref.watch(unacknowledgedCountProvider);
    // MQTT 미연결 시 대시보드 기능을 비활성화하고 안내를 띄운다(연결될 때까지 매번).
    final bool mqttConnected = ref.watch(mqttConnectedProvider);
    final MqttStatus mqttStatus = ref.watch(mqttStatusProvider);

    // 새 치명(위험) 알림 발생 시 풀스크린 경보 표시(6.5).
    // 단, 동시에 떠 있는 경보는 최대 _maxConcurrentCriticalAlerts 개까지만 — 초과분은 무시.
    ref.listen<List<AlertEvent>>(alertsProvider, (prev, next) {
      if (next.isEmpty) return;
      final AlertEvent newest = next.first;
      if (newest.severity != AlertSeverity.critical ||
          newest.acknowledged ||
          newest.id == _lastShownAlertId) {
        return;
      }
      _lastShownAlertId = newest.id;
      if (_openCriticalAlerts >= _maxConcurrentCriticalAlerts) {
        debugPrint('[ALERT] 위험 경보 팝업 최대 $_maxConcurrentCriticalAlerts개 '
            '초과 — 무시: ${newest.title}');
        return;
      }
      _openCriticalAlerts++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _openCriticalAlerts--;
          return;
        }
        // 팝업이 닫히면(ACK/나중에) 슬롯을 반납해 다음 위험 알림이 다시 뜰 수 있게 한다.
        showCriticalAlert(context, ref, newest)
            .whenComplete(() => _openCriticalAlerts--);
      });
    });

    return Scaffold(
      extendBody: true,
      // 기종 반응형: 넓은 화면에서는 콘텐츠/하단 바를 중앙 폭으로 제한한다.
      body: ResponsiveCenter(
        child: Stack(
          children: <Widget>[
            // 미연결 시 탭 내용은 포인터 차단 + 흐리게 처리해 비활성화한다.
            IgnorePointer(
              ignoring: !mqttConnected,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: mqttConnected ? 1 : 0.35,
                child: IndexedStack(index: index, children: _tabs),
              ),
            ),
            if (!mqttConnected)
              Positioned.fill(
                child: _DisconnectedOverlay(
                  status: mqttStatus,
                  onConnect: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const PairingScreen()),
                  ),
                ),
              ),
          ],
        ),
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

/// MQTT 미연결 시 탭 위를 덮는 안내 오버레이. 연결될 때까지 대시보드에서 매번 표시된다.
/// 상태(연결 전/연결 중)를 보여주고 '기기 연결하기' → 페어링(등록·연결)으로 이동한다.
class _DisconnectedOverlay extends StatelessWidget {
  const _DisconnectedOverlay({
    required this.status,
    required this.onConnect,
  });

  final MqttStatus status;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final bool connecting = status == MqttStatus.connecting;
    final Color statusColor =
        connecting ? AppColors.orange : AppColors.textTertiary;
    return Container(
      color: AppColors.background.withValues(alpha: 0.86),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                  connecting
                      ? Icons.cloud_sync_rounded
                      : Icons.cloud_off_rounded,
                  color: statusColor,
                  size: 48),
            ),
            const SizedBox(height: 22),
            const Text(
              'MQTT 연결이 필요합니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              '기기를 등록하고 연결하기 전까지\n대시보드 기능이 비활성화됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            StatusPill(
              label: status.label,
              color: statusColor,
              icon: connecting
                  ? Icons.cloud_sync_outlined
                  : Icons.cloud_off_outlined,
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onConnect,
              child: const Text('기기 연결하기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
