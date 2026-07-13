import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 추이 차트의 한 계열.
class TrendSeries {
  const TrendSeries({required this.spots, required this.color});
  final List<FlSpot> spots;
  final Color color;
}

/// 참조 디자인의 곡선 라인 차트(예: Blood Sugar). 1~2개 계열을 부드러운 곡선으로.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.series,
    this.minY,
    this.maxY,
    this.height = 170,
    this.bottomLabels,
    this.leftInterval,
  });

  final List<TrendSeries> series;
  final double? minY;
  final double? maxY;
  final double height;
  final List<String>? bottomLabels;
  final double? leftInterval;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineTouchData: const LineTouchData(enabled: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: leftInterval,
            getDrawingHorizontalLine: (double value) => const FlLine(
              color: AppColors.divider,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: leftInterval != null,
                interval: leftInterval,
                reservedSize: 30,
                getTitlesWidget: (double value, TitleMeta meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: bottomLabels != null,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final List<String>? labels = bottomLabels;
                  final int i = value.round();
                  if (labels == null || i < 0 || i >= labels.length) {
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
          lineBarsData: <LineChartBarData>[
            for (final TrendSeries s in series)
              LineChartBarData(
                spots: s.spots,
                isCurved: true,
                curveSmoothness: 0.32,
                color: s.color,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}
