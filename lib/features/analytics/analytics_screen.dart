import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/file_saver.dart';
import '../../data/api/api_errors.dart';
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
  String? _error;
  int _months = 6; // 0 = all available

  static final _compact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);
  static final _cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  List<KpiPoint> _window(List<KpiPoint> pts) => _months == 0 || pts.length <= _months ? pts : pts.sublist(pts.length - _months);

  Future<void> _report() async {
    final m = Toast.of(context);
    final d = _data;
    if (d == null) return;
    final rows = <List<Object?>>[
      for (final p in _window(d['revenue'] ?? [])) ['Revenue (INR)', p.label, p.value],
      for (final p in _window(d['signups'] ?? [])) ['Signups', p.label, p.value],
      for (final p in d['categoryShare'] ?? []) ['Category share (%)', p.label, p.value],
    ];
    if (rows.isEmpty) return Toast.info(m, 'There is no analytics data to export yet.');
    final dl = await saveTextFile('aonego9-analytics-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv', toCsv(['Series', 'Period', 'Value'], rows));
    Toast.ok(m, dl ? 'Analytics report downloaded' : 'CSV copied to clipboard');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _repo.analytics();
      if (mounted) setState(() { _data = d; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _data = null; _error = apiErrorMessage(e, fallback: 'Could not load analytics.'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_data == null) return const LoadingView();
    final revenue = _window(_data!['revenue'] ?? []);
    final signups = _window(_data!['signups'] ?? []);
    final share = _data!['categoryShare'] ?? [];
    final totalRev = revenue.fold<double>(0, (s, p) => s + p.value);
    final totalSign = signups.fold<double>(0, (s, p) => s + p.value);

    return PageBody(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'Analytics',
          subtitle: 'Growth, revenue and category insights',
          actions: [
            FilterDropdown<int>(
              value: _months,
              items: const [3, 6, 12, 0],
              label: (m) => m == 0 ? 'All available' : 'Last $m months',
              onChanged: (v) => setState(() => _months = v ?? _months),
            ),
            OutlinedButton.icon(onPressed: _report, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Report (CSV)')),
          ],
        ),
        const SizedBox(height: 20),
        ResponsiveGrid(minTileWidth: 200, children: [
          StatCard(label: 'Revenue in period', value: _compact.format(totalRev), icon: Icons.payments_outlined, color: AppColors.gold),
          StatCard(label: 'Signups in period', value: NumberFormat.decimalPattern('en_IN').format(totalSign), icon: Icons.person_add_alt, color: AppColors.info),
          StatCard(
            label: 'Avg revenue / month',
            value: revenue.isEmpty ? '—' : _compact.format(totalRev / revenue.length),
            icon: Icons.trending_up,
            color: AppColors.success,
          ),
        ]),
        const SizedBox(height: 20),
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
    if (pts.isEmpty) {
      return const SectionCard(title: 'Monthly revenue', child: EmptyView(icon: Icons.bar_chart, message: 'No revenue data yet'));
    }
    final peak = pts.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxY = peak <= 0 ? 1.0 : peak * 1.3;
    return SectionCard(
      title: 'Monthly revenue',
      child: SizedBox(
        height: 260,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox() : Text(NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v), style: AppType.mono(size: 10.5)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= pts.length) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(pts[i].label, style: AppType.mono(size: 10.5)));
              })),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.surfaceAlt,
                getTooltipItem: (g, _, rod, __) => BarTooltipItem('${pts[g.x].label}\n${_cur.format(rod.toY)}', AppType.body(size: 12, weight: FontWeight.w600)),
              ),
            ),
            barGroups: [
              for (var i = 0; i < pts.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: pts[i].value, width: pts.length > 8 ? 12 : 22, borderRadius: BorderRadius.circular(6), gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.goldDark, AppColors.gold])),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signupsLine(List<KpiPoint> pts) {
    if (pts.isEmpty) {
      return const SectionCard(title: 'New signups', child: EmptyView(icon: Icons.show_chart, message: 'No signup data yet'));
    }
    return SectionCard(
      title: 'New signups',
      child: SizedBox(
        height: 240,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox() : Text(v.toInt().toString(), style: AppType.mono(size: 10.5)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= pts.length || v != i.toDouble()) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(pts[i].label, style: AppType.mono(size: 10.5)));
              })),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].value)],
                isCurved: true,
                preventCurveOverShooting: true,
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
    if (share.isEmpty) {
      return const SectionCard(title: 'Category share', child: EmptyView(icon: Icons.pie_chart_outline, message: 'No category data yet'));
    }
    return SectionCard(
      title: 'Category share',
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
                      titleStyle: AppType.mono(size: 11, weight: FontWeight.w700, color: AppColors.onAccent(AppColors.chartPalette[i % AppColors.chartPalette.length])),
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
                  Text('${share[i].label} · ${share[i].value.toStringAsFixed(0)}%', style: AppType.body(size: 12, color: AppColors.textSecondary)),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}
