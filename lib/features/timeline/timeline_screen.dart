import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/trend_chart.dart';

/// 타임라인 기간 필터 인덱스(0=일, 1=주, 2=월).
class _PeriodNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int index) => state = index;
}

final _periodProvider =
    NotifierProvider<_PeriodNotifier, int>(_PeriodNotifier.new);

// ---------------------------------------------------------------------------
// 기간별 라벨 및 온·습도 목업 (일=실측 사용).
// ---------------------------------------------------------------------------

const List<String> _weekdayLabels = <String>['월', '화', '수', '목', '금', '토', '일'];
const List<String> _weekOfMonthLabels = <String>['1주', '2주', '3주', '4주'];
const List<String> _dayHourLabels = <String>['00', '04', '08', '12', '16', '20'];

const List<List<String>> _labelsByPeriod = <List<String>>[
  _dayHourLabels,
  _weekdayLabels,
  _weekOfMonthLabels,
];

/// 기간별 온도(°C) 통계 목업.
const List<List<double>> _mockTemp = <List<double>>[
  <double>[24, 26, 30, 38, 34, 27],
  <double>[26, 28, 31, 35, 33, 29, 27],
  <double>[27, 30, 34, 31],
];

/// 기간별 습도(%) 통계 목업.
const List<List<double>> _mockHumidity = <List<double>>[
  <double>[60, 57, 52, 44, 48, 55],
  <double>[55, 52, 48, 45, 50, 58, 60],
  <double>[54, 49, 44, 51],
];

/// 기간별 CO2(ppm) 통계 목업(일=실측 사용, 주/월 목업).
const List<List<double>> _mockCo2 = <List<double>>[
  <double>[520, 610, 780, 1250, 900, 640],
  <double>[700, 820, 1100, 1500, 1300, 950, 780],
  <double>[760, 980, 1400, 1050],
];

/// 타임라인(6.4): 기간 필터 + 온·습도 추이 + 온·습도 통계 + 이벤트 로그.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int period = ref.watch(_periodProvider);

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
          _PeriodFilter(period: period),
          const SizedBox(height: 20),
          _TrendCard(period: period),
          const SizedBox(height: 16),
          _StatsCard(period: period),
          const SizedBox(height: 16),
          _Co2TrendCard(period: period),
          const SizedBox(height: 16),
          _Co2StatsCard(period: period),
          const SizedBox(height: 16),
          const _EventLogCard(),
        ],
      ),
    );
  }
}

class _PeriodFilter extends ConsumerWidget {
  const _PeriodFilter({required this.period});
  final int period;

  static const List<String> _labels = <String>['일', '주', '월'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < _labels.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          ChoiceChip(
            label: Text(_labels[i]),
            selected: period == i,
            showCheckmark: false,
            onSelected: (bool _) => ref.read(_periodProvider.notifier).set(i),
            backgroundColor: AppColors.surfaceAlt,
            selectedColor: AppColors.primary,
            side: BorderSide(
                color: period == i ? AppColors.primary : AppColors.divider),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.pill)),
            labelStyle: TextStyle(
              color: period == i ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

/// 온·습도 추이(라인). 일은 실측 이력, 주/월은 목업.
class _TrendCard extends ConsumerWidget {
  const _TrendCard({required this.period});
  final int period;

  static const List<String> _pill = <String>['실시간', '주간', '월간'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<FlSpot> tempSpots;
    List<FlSpot> humSpots;
    List<String>? bottomLabels;

    if (period == 0) {
      final List<SensorReading> sh = ref.watch(monitorProvider).sensorHistory;
      tempSpots = <FlSpot>[
        for (int i = 0; i < sh.length; i++)
          FlSpot(i.toDouble(), sh[i].temperatureC),
      ];
      humSpots = <FlSpot>[
        for (int i = 0; i < sh.length; i++) FlSpot(i.toDouble(), sh[i].humidity),
      ];
      bottomLabels = null;
    } else {
      final List<double> t = _mockTemp[period];
      final List<double> h = _mockHumidity[period];
      tempSpots = <FlSpot>[
        for (int i = 0; i < t.length; i++) FlSpot(i.toDouble(), t[i]),
      ];
      humSpots = <FlSpot>[
        for (int i = 0; i < h.length; i++) FlSpot(i.toDouble(), h[i]),
      ];
      bottomLabels = _labelsByPeriod[period];
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(
            title: '온·습도 추이',
            trailing: StatusPill(label: _pill[period], color: AppColors.teal),
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
              bottomLabels: bottomLabels,
            ),
        ],
      ),
    );
  }
}

/// 온·습도 통계(구간별 막대). 온도(teal)/습도(blue) 그룹 막대.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.period});
  final int period;

  @override
  Widget build(BuildContext context) {
    final List<double> temp = _mockTemp[period];
    final List<double> hum = _mockHumidity[period];
    final List<String> labels = _labelsByPeriod[period];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(title: '온·습도 통계'),
          const SizedBox(height: 10),
          Row(
            children: const <Widget>[
              _LegendDot(color: AppColors.teal, label: '온도 °C'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.blue, label: '습도 %'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: const BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double v, TitleMeta meta) {
                        final int i = v.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(labels[i],
                              style: const TextStyle(
                                  color: AppColors.textTertiary, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: <BarChartGroupData>[
                  for (int i = 0; i < labels.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: i < temp.length ? temp[i] : 0,
                          color: AppColors.teal,
                          width: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: i < hum.length ? hum[i] : 0,
                          color: AppColors.blue,
                          width: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CO2 추이(라인, 전용 ppm 축). 일은 실측 이력, 주/월은 목업.
class _Co2TrendCard extends ConsumerWidget {
  const _Co2TrendCard({required this.period});
  final int period;

  static const List<String> _pill = <String>['실시간', '주간', '월간'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<FlSpot> spots;
    List<String>? bottomLabels;
    double current;

    if (period == 0) {
      final List<SensorReading> sh = ref.watch(monitorProvider).sensorHistory;
      spots = <FlSpot>[
        for (int i = 0; i < sh.length; i++) FlSpot(i.toDouble(), sh[i].co2),
      ];
      current = sh.isEmpty ? 0 : sh.last.co2;
      bottomLabels = null;
    } else {
      final List<double> c = _mockCo2[period];
      spots = <FlSpot>[
        for (int i = 0; i < c.length; i++) FlSpot(i.toDouble(), c[i]),
      ];
      current = c.isEmpty ? 0 : c.last;
      bottomLabels = _labelsByPeriod[period];
    }

    double peak = 0;
    for (final FlSpot s in spots) {
      if (s.y > peak) peak = s.y;
    }
    final double maxY = peak < 1600 ? 1600 : (peak / 400).ceil() * 400;
    final AirQuality quality = current.airQuality;
    final Color color = quality.color;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(
            title: 'CO₂ 추이',
            trailing: StatusPill(label: _pill[period], color: AppColors.teal),
          ),
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
              bottomLabels: bottomLabels,
            ),
        ],
      ),
    );
  }
}

/// CO2 통계: 요약(평균/최고/최저) + 구간별 막대(등급별 색상).
class _Co2StatsCard extends StatelessWidget {
  const _Co2StatsCard({required this.period});
  final int period;

  @override
  Widget build(BuildContext context) {
    final List<double> co2 = _mockCo2[period];
    final List<String> labels = _labelsByPeriod[period];

    double peak = 0;
    double avg = 0;
    double mn = co2.isEmpty ? 0 : co2.first;
    for (final double v in co2) {
      avg += v;
      if (v > peak) peak = v;
      if (v < mn) mn = v;
    }
    avg = co2.isEmpty ? 0 : avg / co2.length;
    final double maxY = peak < 1600 ? 1600 : (peak / 400).ceil() * 400;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(title: 'CO₂ 통계'),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _SummaryStat(label: '평균', value: avg),
              _SummaryStat(label: '최고', value: peak),
              _SummaryStat(label: '최저', value: mn),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: const BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double v, TitleMeta meta) {
                        final int i = v.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(labels[i],
                              style: const TextStyle(
                                  color: AppColors.textTertiary, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: <BarChartGroupData>[
                  for (int i = 0; i < co2.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: co2[i],
                          color: co2[i].airQuality.color,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CO2 요약 통계 1칸(평균/최고/최저).
class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: <TextSpan>[
              TextSpan(
                text: value.toStringAsFixed(0),
                style: TextStyle(
                    color: value.airQuality.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
              const TextSpan(
                text: ' ppm',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 이벤트 로그: 알림 이력을 최신순으로.
class _EventLogCard extends ConsumerWidget {
  const _EventLogCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AlertEvent> alerts = <AlertEvent>[...ref.watch(alertsProvider)]
      ..sort((AlertEvent a, AlertEvent b) => b.time.compareTo(a.time));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(title: '이벤트'),
          const SizedBox(height: 16),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('기록된 이벤트가 없어요',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            for (int i = 0; i < alerts.length; i++) ...<Widget>[
              if (i > 0) const Divider(height: 20, color: AppColors.divider),
              _EventRow(alert: alerts[i]),
            ],
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.alert});
  final AlertEvent alert;

  Color get _dotColor => switch (alert.severity) {
        AlertSeverity.critical => AppColors.red,
        AlertSeverity.warning => AppColors.orange,
        AlertSeverity.info => AppColors.blue,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            alert.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Text(formatTimeKo(alert.time),
            style:
                const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
      ],
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
