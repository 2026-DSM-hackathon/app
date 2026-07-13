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

    final double risk = monitor.heatstroke; // 열사병 확률(0~1, 토픽 수신)
    final int pct = (risk * 100).round();
    final bool occupied = monitor.occupied;
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
        title: '차주 하차',
        value: occupied ? '하차' : '대기',
        icon: occupied ? Icons.directions_walk_rounded : Icons.chair_outlined,
        accent: occupied ? AppColors.green : AppColors.textTertiary,
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
            userName: profile.userName,
            unread: unread,
            onBell: () => ref.read(navIndexProvider.notifier).set(2),
          ),
          const SizedBox(height: 22),
          _PrimaryCard(
            monitor: monitor,
            pct: pct,
            hot: hot,
            onToggle: (bool v) =>
                ref.read(monitorProvider.notifier).setOccupied(v),
          ),
          const SizedBox(height: 16),
          // 기종 반응형: 넓은 화면은 한 줄, 좁은 화면은 2열(홀수면 마지막 칸 비움).
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
          const SizedBox(height: 22),
          _TrendCard(monitor: monitor),
          const SizedBox(height: 16),
          _Co2TrendCard(monitor: monitor),
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

/// 주 카드: 차주 하차 토글 + 큰 경과시간 + 열사병 확률 게이지.
class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({
    required this.monitor,
    required this.pct,
    required this.hot,
    required this.onToggle,
  });

  final MonitorState monitor;
  final int pct;
  final bool hot;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final bool occupied = monitor.occupied;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Flexible(
                child: Text('차주 하차 감지',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              // 차주 하차 상태 수동 온/오프 버튼.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(occupied ? '차주 하차 ON' : '차주 하차 OFF',
                      style: TextStyle(
                        color: occupied
                            ? AppColors.green
                            : AppColors.textSecondary,
                        fontSize: 12,
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
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              label: occupied ? '차주 하차' : '감지 대기',
              color: occupied ? AppColors.green : AppColors.textSecondary,
              icon:
                  occupied ? Icons.directions_walk_rounded : Icons.chair_outlined,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.timer_outlined,
                            size: 16, color: AppColors.blue),
                        SizedBox(width: 6),
                        Text('차주 하차 경과 시간',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 경과시간 강조(큰 글씨).
                    _LiveDuration(
                      since: monitor.occupiedSince,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          height: 1.0),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '실내 ${monitor.temperatureC.toStringAsFixed(1)}°C · 습도 ${monitor.humidity.toStringAsFixed(0)}% · CO₂ ${monitor.co2.toStringAsFixed(0)}ppm',
                      style: TextStyle(
                          color:
                              hot ? AppColors.orange : AppColors.textTertiary,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RingGauge(
                value: monitor.heatstroke,
                size: 96,
                stroke: 11,
                color: heatstrokeColor(monitor.heatstroke),
                centerText: '$pct%',
                centerSubtext: '열사병 확률',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 온·습도 추이 카드.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.monitor});
  final MonitorState monitor;

  @override
  Widget build(BuildContext context) {
    final List<SensorReading> sh = monitor.sensorHistory;
    final List<FlSpot> tempSpots = <FlSpot>[
      for (int i = 0; i < sh.length; i++) FlSpot(i.toDouble(), sh[i].temperatureC),
    ];
    final List<FlSpot> humSpots = <FlSpot>[
      for (int i = 0; i < sh.length; i++) FlSpot(i.toDouble(), sh[i].humidity),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(
            title: '온·습도 추이',
            trailing: StatusPill(label: '실시간', color: AppColors.teal),
          ),
          const SizedBox(height: 10),
          Row(
            children: const <Widget>[
              _LegendDot(color: AppColors.teal, label: '온도 °C'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.blue, label: '습도 %'),
            ],
          ),
          const SizedBox(height: 12),
          if (tempSpots.length < 2)
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
                TrendSeries(spots: tempSpots, color: AppColors.teal),
                TrendSeries(spots: humSpots, color: AppColors.blue),
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

/// CO2 추이 카드(전용 ppm 축). 온·습도와 스케일이 달라 별도 차트로 분리.
class _Co2TrendCard extends StatelessWidget {
  const _Co2TrendCard({required this.monitor});
  final MonitorState monitor;

  @override
  Widget build(BuildContext context) {
    final List<SensorReading> sh = monitor.sensorHistory;
    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < sh.length; i++) FlSpot(i.toDouble(), sh[i].co2),
    ];
    double peak = 0;
    for (final FlSpot s in spots) {
      if (s.y > peak) peak = s.y;
    }
    // y축 상단: 최소 1600, 그 이상이면 400 단위로 올림.
    final double maxY = peak < 1600 ? 1600 : (peak / 400).ceil() * 400;
    final AirQuality quality = monitor.co2.airQuality;
    final Color color = quality.color;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(
            title: 'CO₂ 추이',
            trailing: StatusPill(label: quality.label, color: color),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _LegendDot(color: color, label: 'CO₂ ppm'),
              const Spacer(),
              Text(
                '현재 ${monitor.co2.toStringAsFixed(0)} ppm',
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              series: <TrendSeries>[TrendSeries(spots: spots, color: color)],
              minY: 400,
              maxY: maxY,
              leftInterval: 400,
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
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
