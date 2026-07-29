import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PlatformRevenueChart extends StatelessWidget {
  const PlatformRevenueChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Monthly GMV (in ₹)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                        if (value.toInt() < 0 || value.toInt() >= months.length) return const SizedBox();
                        return Text(months[value.toInt()], style: const TextStyle(fontSize: 10, color: Colors.grey));
                      },
                    ),
                  ),
                ),
                barGroups: [
                  _buildGroup(0, 45000),
                  _buildGroup(1, 52000),
                  _buildGroup(2, 48000),
                  _buildGroup(3, 61000),
                  _buildGroup(4, 75000),
                  _buildGroup(5, 89000),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: Colors.indigo,
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}
