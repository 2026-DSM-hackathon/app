import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_shell.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/ring_gauge.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/trend_chart.dart';

/// 홈 대시보드(6.3, F-02/03). 센서→추론 결과를 실시간으로 표시한다.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MonitorState monitor = ref.watch(monitorProvider);
    final SpaceProfile profile = ref.watch(profileProvider);
    final SettingsState settings = ref.watch(settingsProvider);
    final int unread = ref.watch(unacknowledgedCountProvider);

    final int pct = (monitor.probability * 100).round();
    final bool occupied = monitor.occupied;
    final double temp = monitor.temperatureC;
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
        title: '탑승 상태',
        value: occupied ? '탑승' : '비어있음',
        icon: occupied ? Icons.event_seat_rounded : Icons.chair_outlined,
        accent: occupied ? AppColors.green : AppColors.textTertiary,
      ),
      _ElapsedCard(since: monitor.occupiedSince),
      StatCard(
        title: '감지 확률',
        value: '$pct',
        unit: '%',
        icon: Icons.query_stats_rounded,
        accent: AppColors.primary,
      ),
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: <Widget>[
          _Header(
            userName: profile.userName,
            unread: unread,
            onBell: () => ref.read(navIndexProvider.notifier).set(2),
          ),
          const SizedBox(height: 22),
          _PrimaryCard(
              monitor: monitor, occupied: occupied, pct: pct, temp: temp, hot: hot),
          const SizedBox(height: 16),
          // 기종 반응형: 넓은 화면은 4열 한 줄, 좁은 화면은 2x2.
          // 세로가 unbounded인 ListView 안이므로, 카드 높이를 맞추는
          // CrossAxisAlignment.stretch 는 반드시 IntrinsicHeight 로 감싼다.
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
              return Column(
                children: <Widget>[
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(child: statCards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: statCards[1]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(child: statCards[2]),
                        const SizedBox(width: 12),
                        Expanded(child: statCards[3]),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          _TrendCard(monitor: monitor),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.userName,
    required this.unread,
    required this.onBell,
  });

  final String userName;
  final int unread;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    const Widget bell = Icon(Icons.notifications_none_rounded,
        color: AppColors.textPrimary, size: 28);
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('안녕하세요, $userName님!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                formatKoreanDate(DateTime.now()),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
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

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({
    required this.monitor,
    required this.occupied,
    required this.pct,
    required this.temp,
    required this.hot,
  });

  final MonitorState monitor;
  final bool occupied;
  final int pct;
  final double temp;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final InferenceResult? inf = monitor.inference;

    final Widget info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('탑승 감지',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        StatusPill(
          label: occupied ? '탑승 중' : '비어있음',
          color: occupied ? AppColors.green : AppColors.textSecondary,
          icon: occupied ? Icons.event_seat_rounded : Icons.chair_outlined,
        ),
        const SizedBox(height: 16),
        Text('실내 온도 ${temp.toStringAsFixed(1)}°C',
            style: TextStyle(
                color: hot ? AppColors.orange : AppColors.textSecondary,
                fontSize: 13)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('경과 ',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            _LiveDuration(
              since: monitor.occupiedSince,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (inf != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            '추론: ${inf.source == InferenceSource.model ? '모델' : '폴백(휴리스틱)'}',
            style:
                const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ],
    );

    final Widget gauge = RingGauge(
      value: monitor.probability,
      size: 116,
      stroke: 12,
      color: occupied ? AppColors.green : AppColors.blue,
      centerText: '$pct%',
      centerSubtext: '감지 확률',
    );

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          // 기종 반응형: 초소형 화면에서는 게이지를 아래로 내린다.
          if (c.maxWidth < Breakpoints.narrowCard) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                info,
                const SizedBox(height: 16),
                Center(child: gauge),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: info),
              const SizedBox(width: 12),
              gauge,
            ],
          );
        },
      ),
    );
  }
}

class _ElapsedCard extends StatelessWidget {
  const _ElapsedCard({required this.since});
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('경과 시간',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Icon(Icons.timer_outlined, size: 18, color: AppColors.blue),
            ],
          ),
          const SizedBox(height: 14),
          _LiveDuration(
            since: since,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.monitor});
  final MonitorState monitor;

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < monitor.history.length; i++)
        FlSpot(i.toDouble(), monitor.history[i].probability * 100),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(
            title: '탑승 확률 추이',
            trailing: StatusPill(label: '실시간', color: AppColors.teal),
          ),
          const SizedBox(height: 16),
          if (spots.length < 2)
            const SizedBox(
              height: 170,
              child: Center(
                child: Text('데이터 수집 중…',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            TrendChart(
              series: <TrendSeries>[
                TrendSeries(spots: spots, color: AppColors.teal),
              ],
              minY: 0,
              maxY: 100,
              leftInterval: 25,
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
        since == null ? '—' : _fmt(DateTime.now().difference(since));
    return Text(text, style: widget.style);
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '0:00';
    final int h = d.inHours;
    final int m = d.inMinutes.remainder(60);
    final int s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
