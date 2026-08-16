import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/receipt_image.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/admin_repository.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});
  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> with SingleTickerProviderStateMixin {
  final _repo = AdminRepository();
  late final TabController _tab = TabController(length: 3, vsync: this);

  // Plans
  List<SubscriptionPlan> _plans = [];
  bool _plansLoading = true;

  // Requests
  List<SubscriptionRequest> _requests = [];
  bool _requestsLoading = true;
  String _requestFilter = 'pending';

  // Payment settings
  bool _settingsLoading = true;
  bool _savingSettings = false;
  final _upiCtrl = TextEditingController();
  final _payeeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadRequests();
    _loadSettings();
  }

  @override
  void dispose() {
    _tab.dispose();
    _upiCtrl.dispose();
    _payeeCtrl.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppColors.danger : AppColors.surfaceAlt),
    );
  }

  String _errText(Object e) => e.toString().replaceFirst('ApiException', '').replaceAll(RegExp(r'^\(\d+\):\s*'), '');

  // ── Loaders ──────────────────────────────────────────────────

  Future<void> _loadPlans() async {
    setState(() => _plansLoading = true);
    try {
      final p = await _repo.subscriptionPlans();
      if (!mounted) return;
      setState(() {
        _plans = p;
        _plansLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _plansLoading = false);
      _snack('Failed to load plans: ${_errText(e)}', error: true);
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _requestsLoading = true);
    try {
      final status = _requestFilter == 'all' ? null : _requestFilter;
      final r = await _repo.subscriptionRequests(status: status);
      if (!mounted) return;
      setState(() {
        _requests = r;
        _requestsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _requestsLoading = false);
      _snack('Failed to load requests: ${_errText(e)}', error: true);
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _settingsLoading = true);
    try {
      final s = await _repo.paymentSettings();
      if (!mounted) return;
      setState(() {
        _upiCtrl.text = s.upiId;
        _payeeCtrl.text = s.payeeName;
        _settingsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _settingsLoading = false);
      _snack('Failed to load payment settings: ${_errText(e)}', error: true);
    }
  }

  // ── Plan actions ─────────────────────────────────────────────

  Future<void> _deletePlan(SubscriptionPlan p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete plan?'),
        content: Text('This will permanently remove "${p.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.deletePlan(p.id);
      _snack('Plan deleted');
      _loadPlans();
    } catch (e) {
      _snack('Delete failed: ${_errText(e)}', error: true);
    }
  }

  Future<void> _openPlanForm({SubscriptionPlan? existing}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PlanFormDialog(existing: existing),
    );
    if (result == true) _loadPlans();
  }

  // ── Request actions ──────────────────────────────────────────

  Future<void> _openRequestDialog(SubscriptionRequest r) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _RequestReviewDialog(request: r, repo: _repo),
    );
    if (result == true) _loadRequests();
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            responsiveValue(context, mobile: 16, desktop: 28),
            responsiveValue(context, mobile: 16, desktop: 28),
            responsiveValue(context, mobile: 16, desktop: 28),
            0,
          ),
          child: const PageHeader(
            title: 'Subscriptions',
            subtitle: 'Pricing plans, payment requests and UPI settings',
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsiveValue(context, mobile: 16, desktop: 28)),
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.gold,
            labelStyle: AppType.body(size: 13.5, weight: FontWeight.w700),
            unselectedLabelStyle: AppType.body(size: 13.5, weight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Plans'),
              Tab(text: 'Payment Requests'),
              Tab(text: 'UPI Settings'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _plansTab(context),
              _requestsTab(context),
              _settingsTab(context),
            ],
          ),
        ),
      ],
    );
  }

  // ── Plans tab ────────────────────────────────────────────────

  Widget _plansTab(BuildContext context) {
    final pad = responsiveValue<double>(context, mobile: 16, desktop: 28);
    return ListView(
      padding: EdgeInsets.all(pad),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pricing Tiers',
                    style: AppType.display(size: 18, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Plans with audience Vendors or Both appear instantly in the vendor app for upgrade.',
                    style: AppType.body(size: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openPlanForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Plan'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_plansLoading)
          const LoadingView()
        else if (_plans.isEmpty)
          const EmptyView(message: 'No subscription plans yet', icon: Icons.workspace_premium_outlined)
        else
          _plansGrid(context),
      ],
    );
  }

  Widget _plansGrid(BuildContext context) {
    final cols = responsiveValue(context, mobile: 1, tablet: 2, desktop: 3);
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childAspectRatio: cols == 1 ? 1.5 : 0.82,
      children: [for (final p in _plans) _planCard(p)],
    );
  }

  Widget _planCard(SubscriptionPlan p) {
    final cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final highlighted = p.recommended;
    return Container(
      decoration: BoxDecoration(
        gradient: highlighted
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x33C9A86C), AppColors.surface],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.surface, Color(0xFF181B22)],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlighted ? AppColors.gold : AppColors.border, width: highlighted ? 1.6 : 1),
        boxShadow: highlighted
            ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 14))]
            : null,
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.name, style: AppType.display(size: 19, weight: FontWeight.w600)),
              ),
              if (highlighted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
                  child: const Text('RECOMMENDED', style: TextStyle(color: Color(0xFF1A1407), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _audienceChip(p.audience),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(cur.format(p.price), style: AppType.display(size: 30, weight: FontWeight.w700, color: highlighted ? AppColors.gold : AppColors.textPrimary)),
              const SizedBox(width: 6),
              Text('/ ${p.period}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          for (final f in p.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                ],
              ),
            ),
          const Spacer(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openPlanForm(existing: p),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => _deletePlan(p),
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                tooltip: 'Delete plan',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _audienceChip(String audience) {
    final label = switch (audience) {
      'vendor' => 'Vendors',
      'user' => 'Users',
      _ => 'Vendors & Users',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
    );
  }

  // ── Requests tab ─────────────────────────────────────────────

  Widget _requestsTab(BuildContext context) {
    final pad = responsiveValue<double>(context, mobile: 16, desktop: 28);
    return ListView(
      padding: EdgeInsets.all(pad),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final s in ['pending', 'approved', 'rejected', 'all']) _requestFilterChip(s),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: const EdgeInsets.all(16),
          child: _requestsLoading
              ? const LoadingView()
              : _requests.isEmpty
                  ? const EmptyView(message: 'No subscription requests', icon: Icons.receipt_long_outlined)
                  : Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: Row(children: [
                            Expanded(flex: 3, child: _Hdr('Requester')),
                            Expanded(flex: 2, child: _Hdr('Plan')),
                            Expanded(flex: 2, child: _Hdr('Amount')),
                            Expanded(flex: 2, child: _Hdr('Submitted')),
                            Expanded(flex: 2, child: _Hdr('Status')),
                            Expanded(flex: 2, child: _Hdr('')),
                          ]),
                        ),
                        const Divider(height: 1),
                        for (var i = 0; i < _requests.length; i++) ...[
                          _requestRow(_requests[i]),
                          if (i < _requests.length - 1) const Divider(height: 1),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _requestFilterChip(String s) {
    final selected = _requestFilter == s;
    final label = s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() => _requestFilter = s);
        _loadRequests();
      },
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

  Widget _requestRow(SubscriptionRequest r) {
    final cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final (label, color) = switch (r.status) {
      'approved' => ('Approved', AppColors.success),
      'rejected' => ('Rejected', AppColors.danger),
      _ => ('Pending', AppColors.warning),
    };
    final requesterId = r.requesterType == 'vendor' ? (r.vendorId ?? '—') : (r.userId ?? '—');
    return InkWell(
      onTap: () => _openRequestDialog(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.requesterType == 'vendor' ? 'Vendor' : 'User', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  Text(requesterId, style: const TextStyle(color: AppColors.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(r.planName, style: const TextStyle(fontSize: 13.5))),
            Expanded(flex: 2, child: Text(cur.format(r.amount), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
            Expanded(flex: 2, child: Text(DateFormat('d MMM yyyy').format(r.createdAt), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            Expanded(flex: 2, child: StatusChip(label: label, color: color)),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => _openRequestDialog(r), child: const Text('View receipt')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Settings tab ─────────────────────────────────────────────

  Widget _settingsTab(BuildContext context) {
    final pad = responsiveValue<double>(context, mobile: 16, desktop: 28);
    return ListView(
      padding: EdgeInsets.all(pad),
      children: [
        SectionCard(
          title: 'UPI Payment Settings',
          child: _settingsLoading
              ? const LoadingView()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shown to vendors and users when they pay for a subscription.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _upiCtrl,
                      decoration: const InputDecoration(labelText: 'UPI ID', hintText: 'name@bank'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _payeeCtrl,
                      decoration: const InputDecoration(labelText: 'Payee name'),
                    ),
                    const SizedBox(height: 22),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: _savingSettings ? null : _saveSettings,
                        icon: _savingSettings
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1407)))
                            : const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    try {
      await _repo.setPaymentSettings(_upiCtrl.text.trim(), _payeeCtrl.text.trim());
      _snack('Payment settings saved');
      await _loadSettings();
    } catch (e) {
      _snack('Save failed: ${_errText(e)}', error: true);
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }
}

class _Hdr extends StatelessWidget {
  final String label;
  const _Hdr(this.label);
  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      );
}

// ── Plan form dialog ──────────────────────────────────────────

class _PlanFormDialog extends StatefulWidget {
  final SubscriptionPlan? existing;
  const _PlanFormDialog({this.existing});

  @override
  State<_PlanFormDialog> createState() => _PlanFormDialogState();
}

class _PlanFormDialogState extends State<_PlanFormDialog> {
  final _repo = AdminRepository();
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _priceCtrl = TextEditingController(text: widget.existing?.price.toString() ?? '');
  late final _periodCtrl = TextEditingController(text: widget.existing?.period ?? 'monthly');
  late final _featuresCtrl = TextEditingController(text: widget.existing?.features.join('\n') ?? '');
  late bool _recommended = widget.existing?.recommended ?? false;
  late String _audience = widget.existing?.audience ?? 'both';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _periodCtrl.dispose();
    _featuresCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final plan = SubscriptionPlan(
      id: widget.existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
      period: _periodCtrl.text.trim(),
      features: _featuresCtrl.text.split('\n').map((f) => f.trim()).where((f) => f.isNotEmpty).toList(),
      recommended: _recommended,
      audience: _audience,
    );
    try {
      if (widget.existing == null) {
        await _repo.createPlan(plan);
      } else {
        await _repo.updatePlan(widget.existing!.id, plan);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: ${e.toString().replaceFirst('ApiException', '')}'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(isEdit ? 'Edit Plan' : 'Add Plan'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Plan name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(labelText: 'Price (₹)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (double.tryParse(v?.trim() ?? '') == null) ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _periodCtrl,
                      decoration: const InputDecoration(labelText: 'Period', hintText: 'monthly / yearly'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _featuresCtrl,
                  decoration: const InputDecoration(labelText: 'Features (one per line)'),
                  maxLines: 5,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  decoration: const InputDecoration(labelText: 'Audience'),
                  dropdownColor: AppColors.surfaceAlt,
                  items: const [
                    DropdownMenuItem(value: 'vendor', child: Text('Vendors')),
                    DropdownMenuItem(value: 'user', child: Text('Users')),
                    DropdownMenuItem(value: 'both', child: Text('Vendors & Users')),
                  ],
                  onChanged: (v) => setState(() => _audience = v ?? 'both'),
                ),
                CheckboxListTile(
                  value: _recommended,
                  onChanged: (v) => setState(() => _recommended = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.gold,
                  title: const Text('Mark as recommended'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1407)))
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

// ── Request review dialog ─────────────────────────────────────

class _RequestReviewDialog extends StatefulWidget {
  final SubscriptionRequest request;
  final AdminRepository repo;
  const _RequestReviewDialog({required this.request, required this.repo});

  @override
  State<_RequestReviewDialog> createState() => _RequestReviewDialogState();
}

class _RequestReviewDialogState extends State<_RequestReviewDialog> {
  final _noteCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _act(bool approve) async {
    setState(() => _busy = true);
    try {
      if (approve) {
        await widget.repo.approveRequest(widget.request.id, adminNote: _noteCtrl.text.trim());
      } else {
        await widget.repo.rejectRequest(widget.request.id, adminNote: _noteCtrl.text.trim());
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: ${e.toString().replaceFirst('ApiException', '')}'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isPending = r.status == 'pending';
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('${r.requesterType == 'vendor' ? 'Vendor' : 'User'} · ${r.planName}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _kv('Amount', cur.format(r.amount)),
              _kv('Submitted', DateFormat('d MMM yyyy, h:mm a').format(r.createdAt)),
              _kv('Status', r.status[0].toUpperCase() + r.status.substring(1)),
              if (r.adminNote.isNotEmpty) _kv('Admin note', r.adminNote),
              const SizedBox(height: 12),
              const Text('Receipt', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                clipBehavior: Clip.antiAlias,
                child: ReceiptImage(source: r.receiptImage),
              ),
              if (isPending) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(labelText: 'Admin note (optional)'),
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: isPending
          ? [
              TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Close')),
              OutlinedButton(
                onPressed: _busy ? null : () => _act(false),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                child: const Text('Reject'),
              ),
              ElevatedButton(
                onPressed: _busy ? null : () => _act(true),
                child: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1407)))
                    : const Text('Approve'),
              ),
            ]
          : [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close')),
            ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      );
}
