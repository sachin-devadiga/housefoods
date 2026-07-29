import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class UserDistributionChart extends StatelessWidget {
  final int totalCustomers;
  final int totalChefs;

  const UserDistributionChart({
    super.key,
    required this.totalCustomers,
    required this.totalChefs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    value: totalCustomers.toDouble(),
                    color: AppTheme.primaryColor,
                    title: '',
                    radius: 20,
                  ),
                  PieChartSectionData(
                    value: totalChefs.toDouble(),
                    color: AppTheme.secondaryColor,
                    title: '',
                    radius: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegend(AppTheme.primaryColor, "Customers ($totalCustomers)"),
              const SizedBox(height: 8),
              _buildLegend(AppTheme.secondaryColor, "Chefs ($totalChefs)"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
