import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
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
  List<KpiPoint>? _revenue;
  List<Booking>? _recent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _repo.dashboardSummary();
    final a = await _repo.analytics();
    final b = await _repo.bookings();
    if (!mounted) return;
    setState(() {
      _summary = s;
      _revenue = a['revenue'];
      _recent = b.take(5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_summary == null) return const LoadingView();
    final cur = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);

    final cards = [
      StatCard(label: 'Total Vendors', value: '${_summary!['totalVendors']}', icon: Icons.storefront_outlined, color: AppColors.gold, delta: '+12%'),
      StatCard(label: 'Pending Approvals', value: '${_summary!['pendingVendors']}', icon: Icons.pending_actions_outlined, color: AppColors.warning, delta: '+3', deltaUp: false),
      StatCard(label: 'Talent & Users', value: '${_summary!['totalUsers']}', icon: Icons.people_outline, color: AppColors.info, delta: '+8%'),
      StatCard(label: 'Active Bookings', value: '${_summary!['activeBookings']}', icon: Icons.event_available_outlined, color: AppColors.success, delta: '+5%'),
      StatCard(label: 'Total Revenue', value: cur.format(_summary!['revenue']), icon: Icons.payments_outlined, color: AppColors.goldLight, delta: '+18%'),
      StatCard(label: 'Open Disputes', value: '${_summary!['disputes']}', icon: Icons.gavel_outlined, color: AppColors.danger, delta: '-1', deltaUp: true),
    ];

    final cols = responsiveValue(context, mobile: 1, tablet: 2, desktop: 3);

    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        FadeUp(
          child: PageHeader(
            eyebrow: 'Platform Control',
            title: 'Dashboard',
            subtitle: 'Platform overview · ${DateFormat('EEE, d MMM yyyy').format(DateTime(2026, 6, 16))}',
            actions: [
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 18), label: const Text('Export')),
              ElevatedButton.icon(onPressed: () => context.go('/vendors'), icon: const Icon(Icons.add, size: 18), label: const Text('Review Vendors')),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: responsiveValue(context, mobile: 1.9, tablet: 1.7, desktop: 1.75),
          children: [
            for (var i = 0; i < cards.length; i++)
              FadeUp(delay: Duration(milliseconds: 60 + i * 55), child: cards[i]),
          ],
        ),
        const SizedBox(height: 24),
        FadeUp(
          delay: const Duration(milliseconds: 220),
          child: ResponsiveLayout(
            mobile: (_) => Column(children: [
              _revenueCard(),
              const SizedBox(height: 16),
              _quickActions(),
            ]),
            desktop: (_) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _revenueCard()),
                const SizedBox(width: 16),
                Expanded(child: _quickActions()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FadeUp(delay: const Duration(milliseconds: 300), child: _recentBookings()),
      ],
    );
  }

  Widget _revenueCard() {
    final pts = _revenue ?? [];
    return SectionCard(
      title: 'Revenue Trend (₹ Cr)',
      actions: [StatusChip(label: 'Last 6 months', color: AppColors.info)],
      child: SizedBox(
        height: 240,
        child: LineChart(
          LineChartData(
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
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].value)],
                isCurved: true,
                color: AppColors.gold,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.gold.withValues(alpha: 0.25), AppColors.gold.withValues(alpha: 0.0)])),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActions() {
    final actions = [
      ('Review pending vendors', Icons.verified_user_outlined, '/vendors'),
      ('Resolve disputes', Icons.gavel_outlined, '/bookings'),
      ('Process payouts', Icons.account_balance_outlined, '/payments'),
      ('Moderate reviews', Icons.flag_outlined, '/reviews'),
    ];
    return SectionCard(
      title: 'Quick Actions',
      child: Column(
        children: [
          for (final a in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.go(a.$3),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Icon(a.$2, size: 18, color: AppColors.gold),
                    const SizedBox(width: 12),
                    Expanded(child: Text(a.$1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500))),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recentBookings() {
    final cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return SectionCard(
      title: 'Recent Bookings',
      actions: [TextButton(onPressed: () => context.go('/bookings'), child: const Text('View all'))],
      child: Column(
        children: [
          for (final b in _recent ?? [])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                InitialsAvatar(name: b.vendorName, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.service, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text('${b.clientName} · ${b.vendorName}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ]),
                ),
                if (!Responsive.isMobile(context)) ...[
                  Text(cur.format(b.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                ],
                StatusChip(label: StatusUi.booking(b.status).$1, color: StatusUi.booking(b.status).$2),
              ]),
            ),
        ],
      ),
    );
  }
}
