import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/models/status_ui.dart';
import '../../data/repositories/admin_repository.dart';

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});
  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  final _repo = AdminRepository();
  List<Vendor> _all = [];
  bool _loading = true;
  String _query = '';
  ApprovalStatus? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final v = await _repo.vendors();
    if (!mounted) return;
    setState(() {
      _all = v;
      _loading = false;
    });
  }

  List<Vendor> get _filtered => _all.where((v) {
        final matchesQuery = _query.isEmpty ||
            v.name.toLowerCase().contains(_query.toLowerCase()) ||
            v.company.toLowerCase().contains(_query.toLowerCase()) ||
            v.city.toLowerCase().contains(_query.toLowerCase());
        final matchesFilter = _filter == null || v.status == _filter;
        return matchesQuery && matchesFilter;
      }).toList();

  Future<void> _setStatus(Vendor v, ApprovalStatus s) async {
    // Optimistic update — swap status in local list immediately
    final idx = _all.indexWhere((x) => x.id == v.id);
    if (idx != -1) {
      setState(() => _all[idx] = _all[idx].copyWith(status: s));
    }
    try {
      await _repo.setVendorStatus(v.id, s);
      // Confirm by reloading from backend
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${v.company} → ${StatusUi.approval(s).$1}'),
            backgroundColor: AppColors.surfaceAlt,
          ),
        );
      }
    } catch (e) {
      // Roll back the optimistic update on failure
      if (idx != -1) setState(() => _all[idx] = v);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().replaceFirst('ApiException', '').replaceAll(RegExp(r'^\(\d+\):\s*'), '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);
    final counts = {
      for (final s in ApprovalStatus.values) s: _all.where((v) => v.status == s).length,
    };

    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          title: 'Vendors',
          subtitle: 'Approve, manage and oversee every vendor on the platform',
          actions: [
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 18), label: const Text('Export')),
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 18), label: const Text('Invite Vendor')),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _statusTab('All', null, _all.length),
            _statusTab('Pending', ApprovalStatus.pending, counts[ApprovalStatus.pending]!),
            _statusTab('Approved', ApprovalStatus.approved, counts[ApprovalStatus.approved]!),
            _statusTab('Suspended', ApprovalStatus.suspended, counts[ApprovalStatus.suspended]!),
            _statusTab('Rejected', ApprovalStatus.rejected, counts[ApprovalStatus.rejected]!),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Responsive.isMobile(context)
                    ? SearchField(hint: 'Search vendors…', onChanged: (v) => setState(() => _query = v))
                    : Row(children: [
                        Expanded(child: SearchField(hint: 'Search by name, company or city…', onChanged: (v) => setState(() => _query = v))),
                      ]),
              ),
              if (_loading)
                const LoadingView()
              else if (_filtered.isEmpty)
                const EmptyView(message: 'No vendors match your filters')
              else
                Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        _hdr('Vendor', flex: 4),
                        _hdr('Category', flex: 2),
                        _hdr('City', flex: 2),
                        _hdr('KYC', flex: 1),
                        _hdr('Status', flex: 2),
                        _hdr('Actions', flex: 3),
                      ]),
                    ),
                    const Divider(height: 1),
                    for (var i = 0; i < _filtered.length; i++) ...[
                      _vendorRow(_filtered[i], cur),
                      if (i < _filtered.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hdr(String label, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(label.toUpperCase(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      );

  Widget _vendorRow(Vendor v, NumberFormat cur) {
    final (statusLabel, statusColor) = StatusUi.approval(v.status);
    final isApproved = v.status == ApprovalStatus.approved;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openDetail(v),
      child: Container(
        decoration: isApproved
            ? const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.success, width: 3)),
              )
            : null,
        padding: EdgeInsets.only(
          left: isApproved ? 13 : 16,
          right: 16,
          top: 14,
          bottom: 14,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Vendor
          Expanded(flex: 4, child: Row(children: [
            InitialsAvatar(name: v.name, size: 34),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.company.isEmpty ? v.name : v.company,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis),
              Text(v.name, style: const TextStyle(color: AppColors.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
            ])),
          ])),
          // Category
          Expanded(flex: 2, child: Text(v.category.isEmpty ? '—' : v.category,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          // City
          Expanded(flex: 2, child: Text(v.city.isEmpty ? '—' : v.city,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
          // KYC
          Expanded(flex: 1, child: Tooltip(
            message: v.kycVerified ? 'KYC Verified' : 'KYC Pending',
            child: Icon(
              v.kycVerified ? Icons.verified_rounded : Icons.pending_outlined,
              size: 18,
              color: v.kycVerified ? AppColors.success : AppColors.warning,
            ),
          )),
          // Status
          Expanded(flex: 2, child: StatusChip(label: statusLabel, color: statusColor)),
          // Actions
          Expanded(flex: 3, child: _rowActions(v)),
        ]),
      ),
    );
  }

  Widget _rowActions(Vendor v) {
    return Wrap(
      spacing: 6,
      children: [
        if (v.status == ApprovalStatus.pending) ...[
          _miniBtn('Approve', AppColors.success, () => _setStatus(v, ApprovalStatus.approved)),
          _miniBtn('Reject', AppColors.danger, () => _setStatus(v, ApprovalStatus.rejected)),
        ] else if (v.status == ApprovalStatus.approved)
          _miniBtn('Suspend', AppColors.warning, () => _setStatus(v, ApprovalStatus.suspended))
        else if (v.status == ApprovalStatus.suspended)
          _miniBtn('Reinstate', AppColors.success, () => _setStatus(v, ApprovalStatus.approved))
        else
          _miniBtn('Reconsider', AppColors.info, () => _setStatus(v, ApprovalStatus.pending)),
      ],
    );
  }

  Widget _miniBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _statusTab(String label, ApprovalStatus? status, int count) {
    final selected = _filter == status;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filter = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.gold : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: selected ? AppColors.gold : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  void _openDetail(Vendor v) {
    final cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(maxWidth: Responsive.isMobile(context) ? double.infinity : 560),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _VendorDetailSheet(
        vendor: v,
        cur: cur,
        repo: _repo,
        onStatusChange: (vendor, status) {
          Navigator.pop(ctx);
          _setStatus(vendor, status);
        },
      ),
    );
  }
}

class _VendorDetailSheet extends StatefulWidget {
  final Vendor vendor;
  final NumberFormat cur;
  final AdminRepository repo;
  final void Function(Vendor vendor, ApprovalStatus status) onStatusChange;
  const _VendorDetailSheet({
    required this.vendor,
    required this.cur,
    required this.repo,
    required this.onStatusChange,
  });

  @override
  State<_VendorDetailSheet> createState() => _VendorDetailSheetState();
}

class _VendorDetailSheetState extends State<_VendorDetailSheet> {
  List<Map<String, dynamic>>? _portfolio;
  Map<String, dynamic>? _profileDetails;
  bool _loadingPortfolio = true;
  bool _loadingDetails = true;
  List<SubscriptionPlan> _plans = [];
  String? _selectedPlanId;
  bool _assigningPlan = false;
  late String _planLabel = widget.vendor.plan;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
    _loadProfileDetails();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await widget.repo.subscriptionPlans();
      if (!mounted) return;
      final vendorPlans = plans.where((p) => p.audience == 'vendor' || p.audience == 'both').toList();
      SubscriptionPlan? matched;
      for (final p in vendorPlans) {
        if (p.name.toLowerCase() == widget.vendor.plan.toLowerCase()) {
          matched = p;
          break;
        }
      }
      setState(() {
        _plans = vendorPlans;
        _selectedPlanId = matched?.id ?? (vendorPlans.isNotEmpty ? vendorPlans.first.id : null);
      });
    } catch (_) {}
  }

  Future<void> _assignPlan() async {
    final planId = _selectedPlanId;
    if (planId == null || _assigningPlan) return;
    setState(() => _assigningPlan = true);
    try {
      await widget.repo.assignVendorPlan(widget.vendor.id, planId);
      final plan = _plans.firstWhere((p) => p.id == planId);
      if (!mounted) return;
      setState(() {
        _planLabel = plan.name;
        _assigningPlan = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.vendor.company} is now on ${plan.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _assigningPlan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assign failed: ${e.toString().replaceFirst('ApiException', '').replaceAll(RegExp(r'^\\(\\d+\\):\\s*'), '')}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _loadProfileDetails() async {
    try {
      final data = await widget.repo.vendorProfileDetails(widget.vendor.id);
      if (!mounted) return;
      setState(() {
        _profileDetails = data;
        _loadingDetails = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDetails = false);
    }
  }

  Future<void> _loadPortfolio() async {
    try {
      final items = await widget.repo.vendorPortfolio(widget.vendor.id);
      if (!mounted) return;
      setState(() {
        _portfolio = items;
        _loadingPortfolio = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _portfolio = [];
        _loadingPortfolio = false;
      });
    }
  }

  List<Widget> _detailActions(Vendor v) {
    void act(ApprovalStatus s) => widget.onStatusChange(v, s);

    switch (v.status) {
      case ApprovalStatus.pending:
        return [
          Expanded(child: ElevatedButton.icon(
            onPressed: () => act(ApprovalStatus.approved),
            icon: const Icon(Icons.check, size: 18), label: const Text('Approve'),
          )),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => act(ApprovalStatus.rejected),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            icon: const Icon(Icons.close, size: 18), label: const Text('Reject'),
          )),
        ];
      case ApprovalStatus.approved:
        return [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => act(ApprovalStatus.suspended),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning, side: const BorderSide(color: AppColors.warning)),
            icon: const Icon(Icons.block, size: 18), label: const Text('Suspend'),
          )),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => act(ApprovalStatus.rejected),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Reject'),
          )),
        ];
      case ApprovalStatus.suspended:
        return [
          Expanded(child: ElevatedButton.icon(
            onPressed: () => act(ApprovalStatus.approved),
            icon: const Icon(Icons.check, size: 18), label: const Text('Reinstate'),
          )),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => act(ApprovalStatus.rejected),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            icon: const Icon(Icons.close, size: 18), label: const Text('Reject'),
          )),
        ];
      case ApprovalStatus.rejected:
        return [
          Expanded(child: ElevatedButton.icon(
            onPressed: () => act(ApprovalStatus.pending),
            icon: const Icon(Icons.refresh, size: 18), label: const Text('Reconsider'),
          )),
        ];
    }
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;
    final cur = widget.cur;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              InitialsAvatar(name: v.name, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v.company, style: Theme.of(context).textTheme.titleLarge),
                  Text('${v.name} · ${v.category}', style: const TextStyle(color: AppColors.textSecondary)),
                ]),
              ),
              StatusChip(label: StatusUi.approval(v.status).$1, color: StatusUi.approval(v.status).$2),
            ]),
            const SizedBox(height: 20),
            _kv('Email', v.email),
            _kv('Phone', v.phone),
            _kv('City', v.city),
            _kv('Plan', '$_planLabel subscription'),
            if (_plans.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Assign subscription', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedPlanId,
                    decoration: const InputDecoration(labelText: 'Vendor plan'),
                    dropdownColor: AppColors.surfaceAlt,
                    items: [
                      for (final p in _plans)
                        DropdownMenuItem(value: p.id, child: Text('${p.name} · ₹${p.price.toInt()}/${p.period}')),
                    ],
                    onChanged: _assigningPlan ? null : (v) => setState(() => _selectedPlanId = v),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _assigningPlan ? null : _assignPlan,
                  child: _assigningPlan
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1407)))
                      : const Text('Apply'),
                ),
              ]),
              const SizedBox(height: 8),
              const Text(
                'Vendor app updates immediately with this plan and upgrade options.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
            _kv('KYC', v.kycVerified ? 'Verified' : 'Not verified'),
            _kv('Rating', v.rating == 0 ? '—' : '${v.rating} ★'),
            _kv('Total bookings', '${v.totalBookings}'),
            _kv('Lifetime earnings', cur.format(v.totalEarnings)),
            _kv('Joined', DateFormat('d MMM yyyy').format(v.joinedAt)),
            const SizedBox(height: 18),
            Text('Portfolio', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (_loadingPortfolio)
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_portfolio == null || _portfolio!.isEmpty)
              const Text('No portfolio works uploaded yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
            else
              ..._portfolio!.take(6).map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['emoji'] as String? ?? '🖼️', style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item['headline'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          if ((item['tag'] as String? ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text((item['tag'] as String).toUpperCase(), style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                            ),
                          if ((item['description'] as String? ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(item['description'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
                            ),
                        ]),
                      ),
                      if (item['featured'] == true)
                        const Icon(Icons.star, size: 16, color: AppColors.gold),
                    ]),
                  )),
            if (!_loadingPortfolio && (_portfolio?.length ?? 0) > 6)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text('+ ${_portfolio!.length - 6} more works', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
            const SizedBox(height: 18),
            Text('Profile details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (_loadingDetails)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_profileDetails == null)
              const Text('Could not load profile details.', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
            else ...[
              if ((_profileDetails!['overview'] as String? ?? '').isNotEmpty)
                _kv('Overview', _profileDetails!['overview'] as String),
              if ((_profileDetails!['experience'] as String? ?? '').isNotEmpty)
                _kv('Experience', _profileDetails!['experience'] as String),
              if (((_profileDetails!['services'] as List?) ?? []).isNotEmpty)
                _kv('Services', ((_profileDetails!['services'] as List).join(', '))),
              if (((_profileDetails!['spaces'] as List?) ?? []).isNotEmpty)
                _kv('Spaces', '${(_profileDetails!['spaces'] as List).length} listed'),
              if (((_profileDetails!['equipment'] as List?) ?? []).isNotEmpty)
                _kv('Equipment', '${(_profileDetails!['equipment'] as List).length} items'),
              if (((_profileDetails!['scene_data'] as List?) ?? []).isNotEmpty)
                _kv('Scene items', '${(_profileDetails!['scene_data'] as List).length} listed'),
              if ((_profileDetails!['overview'] as String? ?? '').isEmpty &&
                  ((_profileDetails!['services'] as List?) ?? []).isEmpty &&
                  ((_profileDetails!['spaces'] as List?) ?? []).isEmpty &&
                  ((_profileDetails!['equipment'] as List?) ?? []).isEmpty &&
                  ((_profileDetails!['scene_data'] as List?) ?? []).isEmpty)
                const Text('No extended profile details filled in yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            Row(children: _detailActions(v)),
          ],
        ),
      ),
    );
  }
}
