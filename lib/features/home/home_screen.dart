import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_shell.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/stat_card.dart';

/// 홈 대시보드(6.3, F-02/03). 센서 값 + 열사병 확률을 실시간으로 표시한다.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MonitorState monitor = ref.watch(monitorProvider);
    final SettingsState settings = ref.watch(settingsProvider);
    final int unread = ref.watch(unacknowledgedCountProvider);

    final double risk = monitor.heatstroke; // 열사병 확률(0~1, 토픽 수신)
    final int pct = (risk * 100).round();
    final double temp = monitor.temperatureC;
    final double humidity = monitor.humidity;
    final double co2 = monitor.co2;
    final bool hot = temp >= settings.tempThresholdC;

    final List<Widget> statCards = <Widget>[
      StatCard(
        title: '실내 온도',
        value: temp.toStringAsFixed(1),
        unit: '°C',
        icon: Icons.thermostat_rounded,
        accent: hot ? AppColors.orange : AppColors.teal,
      ),
      StatCard(
        title: '습도',
        value: humidity.toStringAsFixed(0),
        unit: '%',
        icon: Icons.water_drop_rounded,
        accent: AppColors.blue,
      ),
      StatCard(
        title: 'CO₂',
        value: co2.toStringAsFixed(0),
        unit: 'ppm',
        icon: Icons.co2_rounded,
        accent: co2.airQuality.color,
      ),
      StatCard(
        title: '열사병 확률',
        value: '$pct',
        unit: '%',
        icon: Icons.local_fire_department_rounded,
        accent: heatstrokeColor(risk),
      ),
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: <Widget>[
          _Header(
            unread: unread,
            onBell: () => ref.read(navIndexProvider.notifier).set(2),
          ),
          const SizedBox(height: 22),
          // 상단 상태: '차주 하차' → '내부 사람 감지' 순으로 전체 폭 카드를 세로로 쌓는다.
          _OwnerAlightCard(
            monitor: monitor,
            onToggle: (bool v) =>
                ref.read(monitorProvider.notifier).setOccupied(v),
          ),
          const SizedBox(height: 12),
          _PersonDetectionCard(
            detected: monitor.detected,
          ),
          const SizedBox(height: 16),
          // 기종 반응형: 넓은 화면은 한 줄, 좁은 화면은 2열.
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              if (c.maxWidth >= Breakpoints.wideStats) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (int i = 0; i < statCards.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: statCards[i]),
                      ],
                    ],
                  ),
                );
              }
              final List<Widget> rows = <Widget>[];
              for (int i = 0; i < statCards.length; i += 2) {
                if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
                rows.add(
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(child: statCards[i]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: i + 1 < statCards.length
                              ? statCards[i + 1]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(children: rows);
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.unread,
    required this.onBell,
  });

  final int unread;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    const Widget bell = Icon(Icons.notifications_none_rounded,
        color: AppColors.textPrimary, size: 28);
    final DateTime now = DateTime.now();
    return Row(
      children: <Widget>[
        Expanded(
          // 인사말 제거 — 연도 포함 현재 날짜만 표시(예: 2026년 7월 14일 화요일).
          child: Text(
            '${now.year}년 ${formatKoreanDate(now)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
        ),
        IconButton(
          onPressed: onBell,
          icon: unread > 0
              ? Badge(
                  label: Text('$unread'),
                  backgroundColor: AppColors.red,
                  child: bell,
                )
              : bell,
        ),
      ],
    );
  }
}

/// 카드: 내부 사람 감지 — 감지됨(위험/빨강) vs 감지되지 않음(안전/초록).
/// 감지 신호는 POD 재실(occ) 실측값을 사용한다(없으면 추론 폴백). 제목(좌) + 상태(우).
class _PersonDetectionCard extends StatelessWidget {
  const _PersonDetectionCard({required this.detected});

  final bool detected;

  @override
  Widget build(BuildContext context) {
    final Color color = detected ? AppColors.red : AppColors.green;
    final String label = detected ? '사람 감지됨' : '사람 감지되지 않음';
    final IconData icon =
        detected ? Icons.person_rounded : Icons.person_off_rounded;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('내부 사람 감지',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드: 차주 하차 — 제목(좌) + ON/OFF 토글(우) + 가운데 경과시간 패널.
/// ON=하차, OFF=차량 내부.
class _OwnerAlightCard extends StatelessWidget {
  const _OwnerAlightCard({
    required this.monitor,
    required this.onToggle,
  });

  final MonitorState monitor;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final bool occupied = monitor.occupied;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Flexible(
                child: Text('차주 하차',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(occupied ? '하차 ON' : '하차 OFF',
                      style: TextStyle(
                        color: occupied
                            ? AppColors.green
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      )),
                  Switch(
                    value: occupied,
                    activeThumbColor: AppColors.green,
                    onChanged: onToggle,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 하차 경과 시간(가운데 정렬 — 별도 박스로 감싸지 않음).
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.timer_outlined, size: 17, color: AppColors.blue),
              SizedBox(width: 6),
              Text('하차 경과 시간',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _LiveDuration(
                since: monitor.occupiedSince,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    height: 1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1초마다 갱신되는 경과시간 표시(6.9).
class _LiveDuration extends StatefulWidget {
  const _LiveDuration({required this.since, this.style});
  final DateTime? since;
  final TextStyle? style;

  @override
  State<_LiveDuration> createState() => _LiveDurationState();
}

class _LiveDurationState extends State<_LiveDuration> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? since = widget.since;
    final String text =
        since == null ? '00:00' : _fmt(DateTime.now().difference(since));
    return Text(text, style: widget.style);
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00';
    final int h = d.inHours;
    final int m = d.inMinutes.remainder(60);
    final int s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
