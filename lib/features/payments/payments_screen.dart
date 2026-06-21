import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/responsive_table.dart';
import '../../data/models/models.dart';
import '../../data/models/status_ui.dart';
import '../../data/repositories/admin_repository.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _repo = AdminRepository();
  List<PaymentTxn> _all = [];
  bool _loading = true;
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _repo.payments();
    if (!mounted) return;
    setState(() {
      _all = p;
      _loading = false;
    });
  }

  List<PaymentTxn> get _filtered => _typeFilter == 'all' ? _all : _all.where((p) => p.type == _typeFilter).toList();

  @override
  Widget build(BuildContext context) {
    final cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final compact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);

    final gross = _all.where((p) => p.type == 'booking').fold<double>(0, (s, p) => s + p.amount);
    final payouts = _all.where((p) => p.type == 'payout').fold<double>(0, (s, p) => s + p.amount);
    final refunds = _all.where((p) => p.type == 'refund').fold<double>(0, (s, p) => s + p.amount);
    final commission = _all.where((p) => p.type == 'commission').fold<double>(0, (s, p) => s + p.amount);
    final subscriptions = _all.where((p) => p.type == 'subscription').fold<double>(0, (s, p) => s + p.amount);

    final cols = responsiveValue(context, mobile: 2, tablet: 4, desktop: 4);

    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          title: 'Payments',
          subtitle: 'Transactions, payouts, refunds and platform commission',
          actions: [
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 18), label: const Text('Export')),
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.account_balance, size: 18), label: const Text('Run Payouts')),
          ],
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.75,
          children: [
            StatCard(label: 'Gross Volume', value: compact.format(gross), icon: Icons.trending_up, color: AppColors.gold),
            StatCard(label: 'Vendor Payouts', value: compact.format(payouts), icon: Icons.account_balance_outlined, color: AppColors.info),
            StatCard(label: 'Refunds', value: compact.format(refunds), icon: Icons.replay, color: AppColors.danger),
            StatCard(label: 'Commission', value: compact.format(commission), icon: Icons.percent, color: AppColors.success),
            StatCard(label: 'Subscriptions', value: compact.format(subscriptions), icon: Icons.workspace_premium_outlined, color: AppColors.goldLight),
          ],
        ),
        const SizedBox(height: 24),
        SectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                for (final t in ['all', 'booking', 'advance', 'payout', 'refund', 'commission', 'subscription']) _typeChip(t),
              ]),
            ),
            if (_loading)
              const LoadingView()
            else
              ResponsiveTable(
                columns: const [
                  TableColumn('Txn ID', flex: 2),
                  TableColumn('Party', flex: 3),
                  TableColumn('Type', flex: 2),
                  TableColumn('Method', flex: 2),
                  TableColumn('Date', flex: 2),
                  TableColumn('Amount', flex: 2, numeric: true),
                  TableColumn('Status', flex: 2),
                ],
                rowCount: _filtered.length,
                cellsBuilder: (i) {
                  final p = _filtered[i];
                  final (label, color) = StatusUi.payment(p.status);
                  return [
                    tcell(p.id, color: AppColors.textMuted),
                    tcell(p.party, weight: FontWeight.w600),
                    tcell(p.type[0].toUpperCase() + p.type.substring(1)),
                    tcell(p.method),
                    tcell(DateFormat('d MMM').format(p.date)),
                    tcell(cur.format(p.amount), numeric: true, weight: FontWeight.w600),
                    StatusChip(label: label, color: color),
                  ];
                },
              ),
          ]),
        ),
      ],
    );
  }

  Widget _typeChip(String t) {
    final selected = _typeFilter == t;
    final label = t == 'all' ? 'All' : t[0].toUpperCase() + t.substring(1);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _typeFilter = t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.gold : AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? AppColors.gold : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5)),
      ),
    );
  }
}
