import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/trend_chart.dart';

/// 통계(6.4): 온도·습도·CO₂ 추이 + 통합 통계.
///
/// 데이터는 전부 monitorProvider.sensorHistory(활성 소스의 실측 스트림 —
/// 시리얼 연결 시 savein/{serial}/telemetry)에서 온다. 주/월 집계 이력이
/// 없으므로 목업 없이 실제 수신 값만 표시한다.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: <Widget>[
          const Text(
            '타임라인',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          _MetricTrendCard(
            title: '온도 추이',
            select: (SensorReading r) => r.temperatureC,
            color: AppColors.teal,
            unit: '°C',
            digits: 1,
            minY: 0,
            maxY: 60,
            leftInterval: 20,
          ),
          const SizedBox(height: 16),
          _MetricTrendCard(
            title: '습도 추이',
            select: (SensorReading r) => r.humidity,
            color: AppColors.blue,
            unit: '%',
            digits: 0,
            minY: 0,
            maxY: 100,
            leftInterval: 25,
          ),
          const SizedBox(height: 16),
          const _Co2TrendCard(),
          const SizedBox(height: 16),
          const _CombinedStatsCard(),
        ],
      ),
    );
  }
}

/// 단일 지표 실측 추이(꺾은선). sensorHistory 를 그대로 그린다.
class _MetricTrendCard extends ConsumerWidget {
  const _MetricTrendCard({
    required this.title,
    required this.select,
    required this.color,
    required this.unit,
    required this.digits,
    required this.minY,
    required this.maxY,
    required this.leftInterval,
  });

  final String title;
  final double Function(SensorReading) select;
  final Color color;
  final String unit;
  final int digits;
  final double minY;
  final double maxY;
  final double leftInterval;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SensorReading> sh = ref.watch(monitorProvider).sensorHistory;
    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < sh.length; i++) FlSpot(i.toDouble(), select(sh[i])),
    ];
    final double current = sh.isEmpty ? 0 : select(sh.last);
    final String metric = title.replaceAll(' 추이', '');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(title: title),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _LegendDot(color: color, label: '$metric $unit'),
              const Spacer(),
              Text('현재 ${current.toStringAsFixed(digits)}$unit',
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          if (spots.length < 2)
            const _EmptyChartState()
          else
            TrendChart(
              series: <TrendSeries>[TrendSeries(spots: spots, color: color)],
              minY: minY,
              maxY: maxY,
              leftInterval: leftInterval,
            ),
        ],
      ),
    );
  }
}

/// CO2 실측 추이(전용 ppm 축 + 등급 색상).
class _Co2TrendCard extends ConsumerWidget {
  const _Co2TrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SensorReading> sh = ref.watch(monitorProvider).sensorHistory;
    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < sh.length; i++) FlSpot(i.toDouble(), sh[i].co2),
    ];
    final double current = sh.isEmpty ? 0 : sh.last.co2;

    double peak = 0;
    for (final FlSpot s in spots) {
      if (s.y > peak) peak = s.y;
    }
    // y축 상단: 최소 1600, 그 이상이면 400 단위로 올림.
    final double maxY = peak < 1600 ? 1600 : (peak / 400).ceil() * 400;
    final AirQuality quality = current.airQuality;
    final Color color = quality.color;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(title: 'CO₂ 추이'),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _LegendDot(color: color, label: 'CO₂ ppm'),
              const Spacer(),
              Text(
                '현재 ${current.toStringAsFixed(0)} ppm · ${quality.label}',
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (spots.length < 2)
            const _EmptyChartState()
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

/// 통합 통계: 온도·습도·CO₂ 각각의 평균/최고/최저(실측).
class _CombinedStatsCard extends ConsumerWidget {
  const _CombinedStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SensorReading> sh = ref.watch(monitorProvider).sensorHistory;
    final List<double> temp = <double>[
      for (final SensorReading r in sh) r.temperatureC,
    ];
    final List<double> hum = <double>[
      for (final SensorReading r in sh) r.humidity,
    ];
    final List<double> co2 = <double>[
      for (final SensorReading r in sh) r.co2,
    ];

    // 시간대별 감지 횟수: 실측 알림 이벤트를 4시간 구간(00·04·08·12·16·20)으로 집계.
    final List<AlertEvent> alerts = ref.watch(alertsProvider);
    final List<int> hourly = List<int>.filled(6, 0);
    for (final AlertEvent a in alerts) {
      hourly[(a.time.hour ~/ 4).clamp(0, 5)]++;
    }
    final int total = alerts.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(title: '통계'),
          const SizedBox(height: 12),
          // 그래프: 시간대별 감지 횟수(막대). 아래 숫자 통계와 함께 표시.
          Text('시간대별 감지 횟수 · 총 $total회',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (total == 0)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text('감지 기록이 없어요',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            _DetectionBarChart(counts: hourly),
          const Divider(height: 28, color: AppColors.divider),
          Row(
            children: const <Widget>[
              Expanded(flex: 5, child: SizedBox.shrink()),
              Expanded(
                  flex: 4,
                  child: Text('평균',
                      textAlign: TextAlign.center, style: _statHeaderStyle)),
              Expanded(
                  flex: 4,
                  child: Text('최고',
                      textAlign: TextAlign.center, style: _statHeaderStyle)),
              Expanded(
                  flex: 4,
                  child: Text('최저',
                      textAlign: TextAlign.center, style: _statHeaderStyle)),
            ],
          ),
          const Divider(height: 18, color: AppColors.divider),
          _StatRow(
              name: '온도',
              unit: '°C',
              digits: 1,
              color: AppColors.teal,
              data: temp),
          const SizedBox(height: 14),
          _StatRow(
              name: '습도',
              unit: '%',
              digits: 0,
              color: AppColors.blue,
              data: hum),
          const SizedBox(height: 14),
          _StatRow(
              name: 'CO₂',
              unit: 'ppm',
              digits: 0,
              color: AppColors.green,
              data: co2),
        ],
      ),
    );
  }
}

const TextStyle _statHeaderStyle = TextStyle(
    color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600);

/// 시간대별 감지 횟수 막대 차트(4시간 구간 6개). 라인 차트와 동일한 다크 스타일.
class _DetectionBarChart extends StatelessWidget {
  const _DetectionBarChart({required this.counts});

  final List<int> counts;

  static const List<String> _labels = <String>[
    '00', '04', '08', '12', '16', '20',
  ];

  @override
  Widget build(BuildContext context) {
    int peak = 0;
    for (final int c in counts) {
      if (c > peak) peak = c;
    }
    final double maxY = (peak < 4 ? 4 : peak + 1).toDouble();
    final double interval = maxY <= 6 ? 1 : (maxY / 5).ceilToDouble();

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: 0,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (double v) =>
                const FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 28,
                getTitlesWidget: (double value, TitleMeta meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int i = value.round();
                  if (i < 0 || i >= _labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_labels[i],
                        style: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          barGroups: <BarChartGroupData>[
            for (int i = 0; i < counts.length; i++)
              BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: counts[i].toDouble(),
                    color: AppColors.primary,
                    width: 14,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 통계 1행: 지표명 + 평균/최고/최저 값.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.name,
    required this.unit,
    required this.digits,
    required this.color,
    required this.data,
  });

  final String name;
  final String unit;
  final int digits;
  final Color color;
  final List<double> data;

  @override
  Widget build(BuildContext context) {
    final bool empty = data.isEmpty;
    double avg = 0;
    double mx = 0;
    double mn = 0;
    if (!empty) {
      mx = data.first;
      mn = data.first;
      for (final double v in data) {
        avg += v;
        if (v > mx) mx = v;
        if (v < mn) mn = v;
      }
      avg /= data.length;
    }

    Widget cell(double v) => Expanded(
          flex: 4,
          child: Text(
            empty ? '—' : '${v.toStringAsFixed(digits)}$unit',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
        );

    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        cell(avg),
        cell(mx),
        cell(mn),
      ],
    );
  }
}

/// 데이터가 없을 때의 안내(수집 중 대신 '연결 전' 계열 — 실제 링크 상태 반영).
class _EmptyChartState extends ConsumerWidget {
  const _EmptyChartState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MqttStatus status = ref.watch(mqttStatusProvider);
    final link = ref.watch(mqttLinkProvider).value;
    final bool broker = link?.brokerConnected ?? false;
    final bool podOnline = link?.pod == PodConnection.online;
    final String label = status == MqttStatus.idle
        ? 'MQTT 연결 전'
        : (broker
            ? (podOnline ? '데이터 수신 대기' : '기기 연결 전')
            : '브로커 연결 중…');
    return SizedBox(
      height: 170,
      child: Center(
        child: Text(label,
            style: const TextStyle(color: AppColors.textSecondary)),
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
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
