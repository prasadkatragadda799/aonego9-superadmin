import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/file_saver.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/responsive_table.dart';
import '../../data/api/api_errors.dart';
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
  String? _error;
  String _typeFilter = 'all';
  String _query = '';

  static final _cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static const _types = ['all', 'booking', 'advance', 'payout', 'refund', 'commission', 'subscription'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _all.isEmpty;
      _error = null;
    });
    try {
      final p = await _repo.payments();
      if (!mounted) return;
      setState(() {
        _all = p;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e, fallback: 'Could not load payments.');
        });
      }
    }
  }

  List<PaymentTxn> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((p) {
      if (_typeFilter != 'all' && p.type != _typeFilter) return false;
      return q.isEmpty || '${p.id} ${p.party} ${p.method} ${p.reference}'.toLowerCase().contains(q);
    }).toList();
  }

  double _sum(String type) => _all.where((p) => p.type == type).fold<double>(0, (s, p) => s + p.amount);

  /// Completed bookings at full value, plus advances on bookings not yet
  /// completed — an advance is part of its booking's value, so counting both
  /// would double it.
  double get _grossVolume {
    final completed = {for (final p in _all) if (p.type == 'booking' && p.reference.isNotEmpty) p.reference};
    return _sum('booking') +
        _all.where((p) => p.type == 'advance' && !completed.contains(p.reference)).fold<double>(0, (s, p) => s + p.amount);
  }

  Future<void> _export() async {
    final m = Toast.of(context);
    final rows = _filtered;
    if (rows.isEmpty) return Toast.info(m, 'No transactions in this view to export.');
    final df = DateFormat('yyyy-MM-dd');
    final csv = toCsv(
      ['Transaction ID', 'Date', 'Party', 'Type', 'Method', 'Reference', 'Status', 'Amount (INR)'],
      [for (final p in rows) [p.id, df.format(p.date), p.party, p.type, p.method, p.reference, p.status.name, p.amount]],
    );
    final dl = await saveTextFile('aonego9-payments-${df.format(DateTime.now())}.csv', csv);
    Toast.ok(m, dl ? 'Exported ${rows.length} transactions' : 'CSV copied to clipboard');
  }

  Future<void> _recordPayout() async {
    final done = await showAdaptiveSheet<String>(context, builder: (_) => _PayoutForm(repo: _repo));
    if (done == null || !mounted) return;
    Toast.ok(Toast.of(context), done);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _all.isEmpty) return ErrorView(message: _error!, onRetry: _load);
    final list = _filtered;
    return PageBody(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'Payments',
          subtitle: 'Transactions, vendor payouts, refunds and platform commission',
          actions: [
            OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Export CSV')),
            ElevatedButton.icon(onPressed: _recordPayout, icon: const Icon(Icons.account_balance, size: 18), label: const Text('Record payout')),
          ],
        ),
        const SizedBox(height: 20),
        if (_loading)
          const LoadingView()
        else ...[
          ResponsiveGrid(minTileWidth: 180, maxColumns: 5, children: [
            StatCard(label: 'Gross volume', value: money(_grossVolume), icon: Icons.trending_up, color: AppColors.gold),
            StatCard(label: 'Vendor payouts', value: money(_sum('payout')), icon: Icons.account_balance_outlined, color: AppColors.info),
            StatCard(label: 'Refunds', value: money(_sum('refund')), icon: Icons.replay, color: AppColors.danger),
            StatCard(label: 'Commission', value: money(_sum('commission')), icon: Icons.percent, color: AppColors.success),
            StatCard(label: 'Subscriptions', value: money(_sum('subscription')), icon: Icons.workspace_premium_outlined, color: AppColors.warning),
          ]),
          const SizedBox(height: 18),
          SectionCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PillBar(children: [
                for (final t in _types)
                  FilterPill(
                    label: t == 'all' ? 'All' : t[0].toUpperCase() + t.substring(1),
                    count: t == 'all' ? _all.length : _all.where((p) => p.type == t).length,
                    selected: _typeFilter == t,
                    onTap: () => setState(() => _typeFilter = t),
                  ),
              ]),
              const SizedBox(height: 10),
              SearchField(hint: 'Search party, transaction ID, method or reference…', onChanged: (v) => setState(() => _query = v)),
              const SizedBox(height: 8),
              if (list.isEmpty)
                EmptyView(icon: Icons.payments_outlined, message: _all.isEmpty ? 'No transactions yet' : 'Nothing in this view')
              else
                ResponsiveTable(
                  columns: const [
                    TableColumn('Date', flex: 2),
                    TableColumn('Party', flex: 3),
                    TableColumn('Type', flex: 2),
                    TableColumn('Method', flex: 2),
                    TableColumn('Amount', flex: 2, numeric: true),
                    TableColumn('Status', flex: 2),
                  ],
                  rowCount: list.length,
                  mobileCardBuilder: (i) => _mobile(list[i]),
                  cellsBuilder: (i) {
                    final p = list[i];
                    final (label, color) = StatusUi.payment(p.status);
                    return [
                      tcell(DateFormat('d MMM yyyy').format(p.date)),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(p.party.isEmpty ? '—' : p.party, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13.5, weight: FontWeight.w600)),
                        Text(p.id, style: AppType.mono(size: 11)),
                      ]),
                      tcell(p.type.isEmpty ? '—' : p.type[0].toUpperCase() + p.type.substring(1)),
                      tcell(p.method.isEmpty ? '—' : p.method),
                      tcell(_cur.format(p.amount), numeric: true, weight: FontWeight.w600),
                      StatusChip(label: label, color: color),
                    ];
                  },
                ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _mobile(PaymentTxn p) {
    final (label, color) = StatusUi.payment(p.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.party.isEmpty ? p.id : p.party, style: AppType.body(size: 13.5, weight: FontWeight.w700))),
          Text(_cur.format(p.amount), style: AppType.mono(size: 13.5, weight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          StatusChip(label: label, color: color),
          const SizedBox(width: 8),
          Text([if (p.type.isNotEmpty) p.type, if (p.method.isNotEmpty) p.method].join(' · '), style: AppType.body(size: 12, color: AppColors.textMuted)),
          const Spacer(),
          Text(DateFormat('d MMM').format(p.date), style: AppType.mono(size: 11.5)),
        ]),
      ]),
    );
  }
}

class _PayoutForm extends StatefulWidget {
  final AdminRepository repo;
  const _PayoutForm({required this.repo});
  @override
  State<_PayoutForm> createState() => _PayoutFormState();
}

class _PayoutFormState extends State<_PayoutForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  List<Vendor>? _vendors;
  String? _vendorId;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    widget.repo.vendors(status: 'approved').then((v) {
      if (mounted) setState(() => _vendors = v..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase())));
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _vendors = [];
          _error = apiErrorMessage(e, fallback: 'Could not load vendors.');
        });
      }
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _vendorId == null) return;
    final v = _vendors!.firstWhere((x) => x.id == _vendorId);
    final amount = double.parse(_amount.text.trim());
    final ok = await confirmAction(
      context,
      title: 'Record payout?',
      message: 'Record a payout of ₹${amount.toStringAsFixed(0)} to ${v.displayName}. Only confirm after the bank / UPI transfer is complete.',
      confirmLabel: 'Record payout',
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await widget.repo.triggerPayout(v.id, amount);
      if (mounted) Navigator.pop(context, 'Payout of ₹${amount.toStringAsFixed(0)} recorded for ${v.displayName}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiErrorMessage(e, fallback: 'Could not record the payout.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Record a vendor payout', style: AppType.display(size: 20)),
          const SizedBox(height: 6),
          Text('Use after transferring a vendor\'s settled earnings. Vendor payout requests arrive in Leads → Payouts.',
              style: AppType.body(size: 12.5, color: AppColors.textSecondary, height: 1.45)),
          const SizedBox(height: 16),
          if (_error.isNotEmpty) ...[
            InlineNotice(message: _error, icon: Icons.error_outline, color: AppColors.danger),
            const SizedBox(height: 12),
          ],
          LabeledField(
            label: 'Vendor',
            child: _vendors == null
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    initialValue: _vendorId,
                    isExpanded: true,
                    menuMaxHeight: 400,
                    dropdownColor: AppColors.surfaceAlt,
                    hint: const Text('Choose an approved vendor'),
                    items: [
                      for (final v in _vendors!)
                        DropdownMenuItem(value: v.id, child: Text('${v.displayName}${v.city.isEmpty ? '' : ' · ${v.city}'}', overflow: TextOverflow.ellipsis)),
                    ],
                    validator: (v) => v == null ? 'Choose a vendor' : null,
                    onChanged: (v) => setState(() => _vendorId = v),
                  ),
          ),
          LabeledField(
            label: 'Amount (₹)',
            child: TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(prefixText: '₹ ', hintText: '25000'),
              validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) <= 0 ? 'Enter an amount' : null,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const ButtonSpinner() : const Text('Record payout')),
          ),
        ]),
      ),
    );
  }
}
