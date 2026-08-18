import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class WasteChartPlaceholder extends StatelessWidget {
  final List<Map<String, dynamic>> disposalHistory;
  
  const WasteChartPlaceholder({super.key, this.disposalHistory = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Process data for the last 7 days
    final now = DateTime.now();
    final Map<String, int> dailyCounts = {};
    
    // Initialize last 7 days with 0
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('E').format(date); // Mon, Tue, etc.
      dailyCounts[dayKey] = 0;
    }

    // Populate with real data
    for (var record in disposalHistory) {
      if (record['created_at'] != null) {
        final date = DateTime.parse(record['created_at']);
        if (date.isAfter(now.subtract(const Duration(days: 7)))) {
          final dayKey = DateFormat('E').format(date);
          if (dailyCounts.containsKey(dayKey)) {
            dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
          }
        }
      }
    }

    final days = dailyCounts.keys.toList();
    final counts = dailyCounts.values.toList();
    double maxCount = counts.fold(0, (max, e) => e > max ? e.toDouble() : max);
    if (maxCount < 5) maxCount = 5;

    return Container(
      height: 300,
      padding: const EdgeInsets.only(top: 20),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount + 1,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: theme.colorScheme.primary.withValues(alpha: 0.8),
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${days[group.x]}\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  children: [
                    TextSpan(
                      text: (rod.toY - 1).toInt().toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < days.length) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 8,
                      child: Text(
                        days[value.toInt()],
                        style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.dividerColor.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(days.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: counts[index].toDouble(),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.5),
                      AppTheme.primaryGreen,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxCount + 1,
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
