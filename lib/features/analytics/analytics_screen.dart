import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/admin_repository.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _repo = AdminRepository();
  Map<String, List<KpiPoint>>? _data;

  @override
  void initState() {
    super.initState();
    _repo.analytics().then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) return const LoadingView();
    final revenue = _data!['revenue']!;
    final signups = _data!['signups']!;
    final share = _data!['categoryShare']!;

    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          title: 'Analytics',
          subtitle: 'Growth, revenue and category insights',
          actions: [
            FilterDropdown<String>(value: 'Last 6 months', items: const ['Last 7 days', 'Last 30 days', 'Last 6 months', 'This year'], label: (s) => s, onChanged: (_) {}),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 18), label: const Text('Report')),
          ],
        ),
        const SizedBox(height: 24),
        ResponsiveLayout(
          mobile: (_) => Column(children: [
            _revenueBars(revenue),
            const SizedBox(height: 16),
            _signupsLine(signups),
            const SizedBox(height: 16),
            _categoryPie(share),
          ]),
          desktop: (_) => Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _revenueBars(revenue)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _categoryPie(share)),
            ]),
            const SizedBox(height: 16),
            _signupsLine(signups),
          ]),
        ),
      ],
    );
  }

  Widget _revenueBars(List<KpiPoint> pts) {
    final maxY = pts.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.3;
    return SectionCard(
      title: 'Monthly Revenue (₹ Cr)',
      child: SizedBox(
        height: 260,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= pts.length) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(pts[i].label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)));
              })),
            ),
            barGroups: [
              for (var i = 0; i < pts.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: pts[i].value, width: 22, borderRadius: BorderRadius.circular(6), gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.goldDark, AppColors.gold])),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signupsLine(List<KpiPoint> pts) {
    return SectionCard(
      title: 'New Signups',
      child: SizedBox(
        height: 240,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= pts.length) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(pts[i].label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)));
              })),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].value)],
                isCurved: true,
                color: AppColors.info,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: true, color: AppColors.info.withValues(alpha: 0.12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryPie(List<KpiPoint> share) {
    return SectionCard(
      title: 'Category Share',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 48,
                sections: [
                  for (var i = 0; i < share.length; i++)
                    PieChartSectionData(
                      value: share[i].value,
                      title: '${share[i].value.toInt()}%',
                      color: AppColors.chartPalette[i % AppColors.chartPalette.length],
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF14161C)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (var i = 0; i < share.length; i++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.chartPalette[i % AppColors.chartPalette.length], borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text(share[i].label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}
