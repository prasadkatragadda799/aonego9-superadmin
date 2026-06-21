import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/responsive_table.dart';
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
    await _repo.setVendorStatus(v.id, s);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${v.company} → ${StatusUi.approval(s).$1}'), backgroundColor: AppColors.surfaceAlt),
      );
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
                ResponsiveTable(
                  columns: const [
                    TableColumn('Vendor', flex: 3),
                    TableColumn('Category', flex: 2),
                    TableColumn('City', flex: 2),
                    TableColumn('KYC', flex: 1),
                    TableColumn('Earnings', flex: 2, numeric: true),
                    TableColumn('Status', flex: 2),
                    TableColumn('Actions', flex: 2),
                  ],
                  rowCount: _filtered.length,
                  onRowTap: (i) => _openDetail(_filtered[i]),
                  cellsBuilder: (i) {
                    final v = _filtered[i];
                    final (label, color) = StatusUi.approval(v.status);
                    return [
                      Row(children: [
                        InitialsAvatar(name: v.name, size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(v.company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5), overflow: TextOverflow.ellipsis),
                            Text(v.name, style: const TextStyle(color: AppColors.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      ]),
                      tcell(v.category),
                      tcell(v.city),
                      Icon(v.kycVerified ? Icons.verified : Icons.error_outline, size: 18, color: v.kycVerified ? AppColors.success : AppColors.warning),
                      tcell(cur.format(v.totalEarnings), numeric: true, weight: FontWeight.w600),
                      StatusChip(label: label, color: color),
                      _rowActions(v),
                    ];
                  },
                ),
            ],
          ),
        ),
      ],
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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
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
            _kv('Plan', '${v.plan} subscription'),
            _kv('KYC', v.kycVerified ? 'Verified' : 'Not verified'),
            _kv('Rating', v.rating == 0 ? '—' : '${v.rating} ★'),
            _kv('Total bookings', '${v.totalBookings}'),
            _kv('Lifetime earnings', cur.format(v.totalEarnings)),
            _kv('Joined', DateFormat('d MMM yyyy').format(v.joinedAt)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _setStatus(v, ApprovalStatus.approved); }, icon: const Icon(Icons.check, size: 18), label: const Text('Approve'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); _setStatus(v, ApprovalStatus.suspended); }, icon: const Icon(Icons.block, size: 18), label: const Text('Suspend'))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5))),
        ]),
      );
}
