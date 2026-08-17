import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class RevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;
  const RevenueChart({super.key, this.weeklyData = const []});

  @override
  Widget build(BuildContext context) {
    final data = weeklyData.length == 7 ? weeklyData : _emptyWeek();
    double maxAmount = 0;
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      final amount = (data[i]['amount'] ?? 0).toDouble();
      if (amount > maxAmount) maxAmount = amount;
      spots.add(FlSpot(i.toDouble(), amount));
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) return const SizedBox();
                  return Text(
                    data[index]['day'].toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.secondaryColor,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _emptyWeek() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => {'day': d, 'amount': 0.0}).toList();
  }
}
