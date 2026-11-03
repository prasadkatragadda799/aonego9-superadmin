import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/file_saver.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_errors.dart';
import '../../data/models/models.dart';
import '../../data/models/status_ui.dart';
import '../../data/repositories/admin_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = AdminRepository();
  Map<String, num>? _summary;
  List<KpiPoint> _revenue = [];
  List<KpiPoint> _signups = [];
  List<Booking> _recent = [];
  String? _error;

  static final _cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait<Object?>([
        _repo.dashboardSummary(),
        _repo.analytics().catchError((_) => <String, List<KpiPoint>>{}),
        _repo.bookings().catchError((_) => <Booking>[]),
      ]);
      AdminBadges.refresh(force: true);
      if (!mounted) return;
      final a = r[1] as Map<String, List<KpiPoint>>;
      setState(() {
        _summary = r[0] as Map<String, num>;
        _revenue = a['revenue'] ?? [];
        _signups = a['signups'] ?? [];
        _recent = (r[2] as List<Booking>).take(6).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, fallback: 'Could not load the dashboard.'));
    }
  }

  Future<void> _export() async {
    final m = Toast.of(context);
    final s = _summary!;
    final rows = <List<Object?>>[
      ['Total vendors', s['totalVendors']],
      ['Pending vendor approvals', s['pendingVendors']],
      ['Talent & users', s['totalUsers']],
      ['Active bookings', s['activeBookings']],
      ['Total revenue (INR)', s['revenue']],
      ['Revenue this month (INR)', s['monthRevenue']],
      ['Commission earned (INR)', s['commission']],
      ['Open disputes', s['disputes']],
      for (final p in _revenue) ['Revenue ${p.label} (INR)', p.value],
      for (final p in _signups) ['Signups ${p.label}', p.value],
    ];
    final csv = toCsv(['Metric', 'Value'], rows);
    final dl = await saveTextFile('aonego9-platform-summary-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv', csv);
    Toast.ok(m, dl ? 'Platform summary exported' : 'CSV copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _summary == null) return ErrorView(message: _error!, onRetry: _load);
    if (_summary == null) return const LoadingView();
    final s = _summary!;

    final cards = [
      StatCard(label: 'Total vendors', value: '${s['totalVendors']}', icon: Icons.storefront_outlined, color: AppColors.gold, onTap: () => context.go('/vendors')),
      StatCard(label: 'Pending approvals', value: '${s['pendingVendors']}', icon: Icons.pending_actions_outlined, color: AppColors.warning, onTap: () => context.go('/vendors?status=pending')),
      StatCard(label: 'Talent & users', value: '${s['totalUsers']}', icon: Icons.people_outline, color: AppColors.info, onTap: () => context.go('/users')),
      StatCard(label: 'Active bookings', value: '${s['activeBookings']}', icon: Icons.event_available_outlined, color: AppColors.success, onTap: () => context.go('/bookings')),
      StatCard(label: 'Total revenue', value: money(s['revenue'] ?? 0), icon: Icons.payments_outlined, color: AppColors.goldLight, onTap: () => context.go('/payments')),
      StatCard(label: 'Revenue this month', value: money(s['monthRevenue'] ?? 0), icon: Icons.calendar_month_outlined, color: AppColors.gold, onTap: () => context.go('/payments')),
      StatCard(label: 'Commission earned', value: money(s['commission'] ?? 0), icon: Icons.percent, color: AppColors.success, onTap: () => context.go('/payments')),
      StatCard(label: 'Open disputes', value: '${s['disputes']}', icon: Icons.gavel_outlined, color: AppColors.danger, onTap: () => context.go('/bookings?status=disputed')),
    ];

    return PageBody(
      onRefresh: _load,
      children: [
        FadeUp(
          child: PageHeader(
            eyebrow: 'Platform control',
            title: 'Dashboard',
            subtitle: 'Platform overview · ${DateFormat('EEE, d MMM yyyy').format(DateTime.now())}',
            actions: [
              OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Export')),
              ElevatedButton.icon(onPressed: () => context.go('/vendors?status=pending'), icon: const Icon(Icons.how_to_reg_outlined, size: 18), label: const Text('Review vendors')),
            ],
          ),
        ),
        const SizedBox(height: 22),
        ResponsiveGrid(minTileWidth: 200, maxColumns: 4, children: [
          for (var i = 0; i < cards.length; i++) FadeUp(delay: Duration(milliseconds: 60 + i * 50), child: cards[i]),
        ]),
        const SizedBox(height: 20),
        FadeUp(
          delay: const Duration(milliseconds: 220),
          child: ResponsiveLayout(
            mobile: (_) => Column(children: [_attentionCard(), const SizedBox(height: 16), _revenueCard()]),
            tablet: (_) => Column(children: [_attentionCard(), const SizedBox(height: 16), _revenueCard()]),
            desktop: (_) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _revenueCard()),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _attentionCard()),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        FadeUp(delay: const Duration(milliseconds: 300), child: _recentBookings()),
      ],
    );
  }

  Widget _revenueCard() {
    final pts = _revenue;
    final has = pts.any((p) => p.value > 0);
    final maxV = pts.fold<double>(0, (m, p) => p.value > m ? p.value : m);
    return SectionCard(
      title: 'Revenue trend',
      actions: [
        if (pts.isNotEmpty) StatusChip(label: 'Last ${pts.length} months', color: AppColors.info),
        TextButton(onPressed: () => context.go('/analytics'), child: const Text('Analytics')),
      ],
      child: SizedBox(
        height: 240,
        child: !has
            ? const EmptyView(icon: Icons.show_chart, message: 'No revenue recorded yet')
            : LineChart(LineChartData(
                minY: 0,
                maxY: maxV * 1.15,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceAlt,
                    getTooltipItems: (spots) => [
                      for (final sp in spots) LineTooltipItem('${pts[sp.x.toInt()].label}\n${_cur.format(sp.y)}', AppType.body(size: 12, weight: FontWeight.w600)),
                    ],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (v, meta) => v == meta.max
                          ? const SizedBox()
                          : Text(NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v), style: AppType.mono(size: 10.5)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= pts.length || v != i.toDouble()) return const SizedBox();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(pts[i].label, style: AppType.mono(size: 10.5)));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].value)],
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: AppColors.gold,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.gold.withValues(alpha: 0.25), AppColors.gold.withValues(alpha: 0.0)],
                      ),
                    ),
                  ),
                ],
              )),
      ),
    );
  }

  /// The same live queue as the bell, so the first screen an admin sees says
  /// what is waiting on them.
  Widget _attentionCard() {
    return ValueListenableBuilder<List<AttentionItem>>(
      valueListenable: AdminBadges.items,
      builder: (context, items, _) {
        final total = items.fold<int>(0, (s, i) => s + i.count);
        return SectionCard(
          title: 'Needs attention',
          actions: [if (items.isNotEmpty) StatusChip(label: total == 0 ? 'All clear' : '$total pending', color: total == 0 ? AppColors.success : AppColors.warning)],
          child: items.isEmpty
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : Column(children: [
                  for (final i in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => context.go(i.route),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: i.count > 0 ? i.color().withValues(alpha: .35) : AppColors.border),
                          ),
                          child: Row(children: [
                            Icon(i.icon, size: 18, color: i.count > 0 ? i.color() : AppColors.textMuted),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(i.label,
                                  style: AppType.body(size: 13, weight: FontWeight.w500, color: i.count > 0 ? AppColors.textPrimary : AppColors.textMuted)),
                            ),
                            Text('${i.count}',
                                style: AppType.mono(size: 13, weight: FontWeight.w700, color: i.count > 0 ? i.color() : AppColors.textMuted)),
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                          ]),
                        ),
                      ),
                    ),
                ]),
        );
      },
    );
  }

  Widget _recentBookings() {
    return SectionCard(
      title: 'Recent bookings',
      actions: [TextButton(onPressed: () => context.go('/bookings'), child: const Text('View all'))],
      child: _recent.isEmpty
          ? const EmptyView(icon: Icons.event_note_outlined, message: 'No bookings yet')
          : Column(children: [
              for (final b in _recent)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => context.go('/bookings?q=${Uri.encodeQueryComponent(b.inquiryRef ?? b.id)}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(children: [
                      InitialsAvatar(name: b.vendorName.isEmpty ? '?' : b.vendorName, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(b.service, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13.5, weight: FontWeight.w600)),
                          Text('${b.clientName} · ${b.vendorName} · ${DateFormat('d MMM').format(b.date)}',
                              overflow: TextOverflow.ellipsis, style: AppType.body(size: 12, color: AppColors.textMuted)),
                        ]),
                      ),
                      if (!Responsive.isMobile(context)) ...[
                        Text(_cur.format(b.amount), style: AppType.mono(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(width: 14),
                      ],
                      StatusChip(label: StatusUi.booking(b.status).$1, color: StatusUi.booking(b.status).$2),
                    ]),
                  ),
                ),
            ]),
    );
  }
}
