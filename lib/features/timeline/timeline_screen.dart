import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/trend_chart.dart';

/// 타임라인 기간 필터 인덱스(0=일, 1=주, 2=월)를 보관한다.
class _PeriodNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final _periodProvider =
    NotifierProvider<_PeriodNotifier, int>(_PeriodNotifier.new);

// ---------------------------------------------------------------------------
// 기간별 목업 데이터(6.4). 일(day)의 확률 추이는 실측 이력을 사용하므로 비워 둔다.
// ---------------------------------------------------------------------------

const List<String> _weekdayLabels = <String>[
  '월', '화', '수', '목', '금', '토', '일',
];
const List<String> _weekOfMonthLabels = <String>['1주', '2주', '3주', '4주'];
const List<String> _dayHourLabels = <String>['00', '04', '08', '12', '16', '20'];

/// 기간별(일/주/월) 탑승 확률(%) 추이 목업.
const List<List<double>> _mockProbabilityTrend = <List<double>>[
  <double>[],
  <double>[58, 62, 74, 80, 55, 40, 68],
  <double>[55, 62, 70, 65],
];

const List<List<String>> _trendLabelsByPeriod = <List<String>>[
  <String>[],
  _weekdayLabels,
  _weekOfMonthLabels,
];

/// 기간별 이벤트 발생 건수 목업.
const List<List<double>> _mockEventCounts = <List<double>>[
  <double>[1, 0, 2, 4, 3, 1],
  <double>[2, 1, 3, 5, 2, 4, 1],
  <double>[4, 7, 5, 6],
];

const List<List<String>> _eventLabelsByPeriod = <List<String>>[
  _dayHourLabels,
  _weekdayLabels,
  _weekOfMonthLabels,
];

/// 타임라인(6.4): 기간(일/주/월) 필터 + 탑승 확률 추이 + 이벤트 통계 + 이벤트 로그.
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
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _PeriodFilter(period: period),
          const SizedBox(height: 20),
          _ProbabilityTrendCard(period: period),
          const SizedBox(height: 16),
          _EventStatsCard(period: period),
          const SizedBox(height: 16),
          const _EventLogCard(),
        ],
      ),
    );
  }
}

/// 기간 필터 칩(일/주/월).
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
              color: period == i ? AppColors.primary : AppColors.divider,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
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

/// 탑승 확률 추이 카드. 일(0)은 실측 이력, 주/월은 목업 데이터를 사용한다.
class _ProbabilityTrendCard extends ConsumerWidget {
  const _ProbabilityTrendCard({required this.period});

  final int period;

  static const List<String> _pillLabels = <String>['실시간', '주간', '월간'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<FlSpot> spots;
    final List<String>? bottomLabels;

    if (period == 0) {
      final List<InferenceResult> history =
          ref.watch(monitorProvider).history;
      spots = <FlSpot>[
        for (int i = 0; i < history.length; i++)
          FlSpot(i.toDouble(), history[i].probability * 100),
      ];
      bottomLabels = null;
    } else {
      final List<double> mock = _mockProbabilityTrend[period];
      spots = <FlSpot>[
        for (int i = 0; i < mock.length; i++) FlSpot(i.toDouble(), mock[i]),
      ];
      bottomLabels = _trendLabelsByPeriod[period];
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(
            title: '탑승 확률 추이',
            trailing:
                StatusPill(label: _pillLabels[period], color: AppColors.teal),
          ),
          const SizedBox(height: 16),
          if (spots.length < 2)
            const SizedBox(
              height: 170,
              child: Center(
                child: Text(
                  '데이터 수집 중…',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
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
              bottomLabels: bottomLabels,
            ),
        ],
      ),
    );
  }
}

/// 이벤트 통계 카드: 기간별 이벤트 발생 건수 막대 그래프(피크는 강조색).
class _EventStatsCard extends StatelessWidget {
  const _EventStatsCard({required this.period});

  final int period;

  @override
  Widget build(BuildContext context) {
    final List<double> data = _mockEventCounts[period];
    final List<String> labels = _eventLabelsByPeriod[period];

    double maxVal = 0;
    int peakIndex = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i] > maxVal) {
        maxVal = data[i];
        peakIndex = i;
      }
    }
    final double maxY = maxVal <= 0 ? 4 : maxVal + 1;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(title: '이벤트 통계'),
          const SizedBox(height: 16),
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
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
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
                          child: Text(
                            labels[i],
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: <BarChartGroupData>[
                  for (int i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: data[i],
                          color: i == peakIndex
                              ? AppColors.orange
                              : AppColors.green,
                          width: 14,
                          borderRadius: BorderRadius.circular(6),
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

/// 이벤트 로그 카드: 알림 이력을 최신순으로 나열한다.
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
                child: Text(
                  '기록된 이벤트가 없어요',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
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

/// 이벤트 한 건: 심각도 점 + 제목 + 시각.
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          DateFormat('a h:mm', 'en').format(alert.time),
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
        ),
      ],
    );
  }
}
