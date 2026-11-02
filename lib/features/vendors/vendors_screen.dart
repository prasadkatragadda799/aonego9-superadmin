import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/app_links.dart';
import '../../core/utils/file_saver.dart';
import '../../core/utils/launch_util.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_errors.dart';
import '../../data/models/models.dart';
import '../../data/models/status_ui.dart';
import '../../data/repositories/admin_repository.dart';

class VendorsScreen extends StatefulWidget {
  final String initialQuery;
  final String initialStatus;
  const VendorsScreen({super.key, this.initialQuery = '', this.initialStatus = ''});
  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  final _repo = AdminRepository();
  List<Vendor> _all = [];
  bool _loading = true;
  String? _error;
  late String _query = widget.initialQuery;
  late ApprovalStatus? _filter = _statusFrom(widget.initialStatus);
  bool _kycPendingOnly = false;
  final Set<String> _busy = {};

  static ApprovalStatus? _statusFrom(String s) =>
      ApprovalStatus.values.where((v) => v.name == s).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VendorsScreen old) {
    super.didUpdateWidget(old);
    if (old.initialQuery != widget.initialQuery || old.initialStatus != widget.initialStatus) {
      setState(() {
        _query = widget.initialQuery;
        _filter = _statusFrom(widget.initialStatus);
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = _all.isEmpty;
      _error = null;
    });
    try {
      final v = await _repo.vendors();
      if (!mounted) return;
      v.sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
      setState(() {
        _all = v;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e, fallback: 'Could not load vendors.');
        });
      }
    }
  }

  List<Vendor> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((v) {
      if (_filter != null && v.status != _filter) return false;
      if (_kycPendingOnly && v.kycVerified) return false;
      if (q.isEmpty) return true;
      return '${v.name} ${v.company} ${v.city} ${v.email} ${v.phone} ${v.category}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _setStatus(Vendor v, ApprovalStatus s) async {
    if (s == ApprovalStatus.rejected || s == ApprovalStatus.suspended) {
      final ok = await confirmAction(
        context,
        title: s == ApprovalStatus.rejected ? 'Reject ${v.displayName}?' : 'Suspend ${v.displayName}?',
        message: s == ApprovalStatus.rejected
            ? 'They will not be listed on the marketplace. They can still sign in and request another review.'
            : 'Their listing is hidden from the marketplace immediately. Existing bookings are not cancelled.',
        confirmLabel: s == ApprovalStatus.rejected ? 'Reject' : 'Suspend',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    final m = Toast.of(context);
    final idx = _all.indexWhere((x) => x.id == v.id);
    if (idx != -1) setState(() => _all[idx] = _all[idx].copyWith(status: s));
    setState(() => _busy.add(v.id));
    try {
      await _repo.setVendorStatus(v.id, s);
      Toast.ok(m, '${v.displayName} → ${StatusUi.approval(s).$1}');
    } catch (e) {
      if (idx != -1 && mounted) setState(() => _all[idx] = v);
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not update the vendor.'));
    } finally {
      if (mounted) setState(() => _busy.remove(v.id));
    }
  }

  void _replace(Vendor v) {
    final i = _all.indexWhere((x) => x.id == v.id);
    if (i != -1) setState(() => _all[i] = v);
  }

  Future<void> _export() async {
    final m = Toast.of(context);
    final rows = _filtered;
    if (rows.isEmpty) return Toast.info(m, 'No vendors in this view to export.');
    final df = DateFormat('yyyy-MM-dd');
    final csv = toCsv(
      ['ID', 'Business', 'Contact', 'Email', 'Phone', 'City', 'Category', 'Status', 'KYC', 'Plan', 'Rating', 'Bookings', 'Lifetime earnings', 'Joined'],
      [
        for (final v in rows)
          [v.id, v.company, v.name, v.email, v.phone, v.city, v.category, v.status.name, v.kycVerified ? 'verified' : 'pending', v.plan, v.rating, v.totalBookings, v.totalEarnings, df.format(v.joinedAt)],
      ],
    );
    final dl = await saveTextFile('aonego9-vendors-${df.format(DateTime.now())}.csv', csv);
    Toast.ok(m, dl ? 'Exported ${rows.length} vendors' : 'CSV copied to clipboard');
  }

  Future<void> _invite() async {
    await showAdaptiveSheet<void>(context, builder: (_) => const _InviteVendorSheet());
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _all.isEmpty) return ErrorView(message: _error!, onRetry: _load);
    final counts = {for (final s in ApprovalStatus.values) s: _all.where((v) => v.status == s).length};
    final list = _filtered;
    final mobile = Responsive.isMobile(context);

    return PageBody(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'Vendors',
          subtitle: 'Approve, verify and oversee every vendor on the platform',
          actions: [
            OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Export CSV')),
            ElevatedButton.icon(onPressed: _invite, icon: const Icon(Icons.person_add_alt, size: 18), label: const Text('Invite vendor')),
          ],
        ),
        const SizedBox(height: 18),
        PillBar(children: [
          FilterPill(label: 'All', count: _all.length, selected: _filter == null, onTap: () => setState(() => _filter = null)),
          FilterPill(label: 'Pending', count: counts[ApprovalStatus.pending], color: AppColors.warning, selected: _filter == ApprovalStatus.pending, onTap: () => setState(() => _filter = ApprovalStatus.pending)),
          FilterPill(label: 'Approved', count: counts[ApprovalStatus.approved], selected: _filter == ApprovalStatus.approved, onTap: () => setState(() => _filter = ApprovalStatus.approved)),
          FilterPill(label: 'Suspended', count: counts[ApprovalStatus.suspended], selected: _filter == ApprovalStatus.suspended, onTap: () => setState(() => _filter = ApprovalStatus.suspended)),
          FilterPill(label: 'Rejected', count: counts[ApprovalStatus.rejected], selected: _filter == ApprovalStatus.rejected, onTap: () => setState(() => _filter = ApprovalStatus.rejected)),
          FilterPill(
            label: 'KYC pending',
            count: _all.where((v) => !v.kycVerified).length,
            color: AppColors.info,
            selected: _kycPendingOnly,
            onTap: () => setState(() => _kycPendingOnly = !_kycPendingOnly),
          ),
        ]),
        const SizedBox(height: 14),
        SectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SearchField(
              key: ValueKey('vq-${widget.initialQuery}'),
              initial: _query,
              hint: 'Search by business, contact, city, email or phone…',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const LoadingView()
            else if (list.isEmpty)
              EmptyView(
                icon: Icons.storefront_outlined,
                message: _all.isEmpty ? 'No vendors yet' : 'No vendors match your filters',
                detail: _all.isEmpty ? 'Vendors who register in the vendor console appear here for approval.' : null,
              )
            else if (mobile)
              for (final v in list) Padding(padding: const EdgeInsets.only(top: 10), child: _mobileCard(v))
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(children: [
                  _hdr('Vendor', 4),
                  _hdr('Category', 2),
                  _hdr('City', 2),
                  _hdr('KYC', 1),
                  _hdr('Status', 2),
                  _hdr('Actions', 3),
                ]),
              ),
              const Divider(height: 1),
              for (var i = 0; i < list.length; i++) ...[
                _row(list[i]),
                if (i < list.length - 1) const Divider(height: 1),
              ],
            ],
          ]),
        ),
      ],
    );
  }

  Widget _hdr(String label, int flex) =>
      Expanded(flex: flex, child: Text(label.toUpperCase(), style: AppType.eyebrow(size: 10.5, color: AppColors.textMuted)));

  Widget _kycIcon(Vendor v) => Tooltip(
        message: v.kycVerified ? 'KYC verified' : 'KYC pending',
        child: Icon(v.kycVerified ? Icons.verified_rounded : Icons.pending_outlined,
            size: 18, color: v.kycVerified ? AppColors.success : AppColors.warning),
      );

  Widget _row(Vendor v) {
    final (statusLabel, statusColor) = StatusUi.approval(v.status);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openDetail(v),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            flex: 4,
            child: Row(children: [
              InitialsAvatar(name: v.displayName, size: 36, imageUrl: v.avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v.displayName, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13.5, weight: FontWeight.w600)),
                  Text(v.email.isEmpty ? v.name : v.email, overflow: TextOverflow.ellipsis, style: AppType.body(size: 12, color: AppColors.textMuted)),
                ]),
              ),
            ]),
          ),
          Expanded(flex: 2, child: Text(v.category.isEmpty ? '—' : v.category, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13))),
          Expanded(flex: 2, child: Text(v.city.isEmpty ? '—' : v.city, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13, color: AppColors.textSecondary))),
          Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: _kycIcon(v))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: StatusChip(label: statusLabel, color: statusColor))),
          Expanded(flex: 3, child: _rowActions(v)),
        ]),
      ),
    );
  }

  Widget _mobileCard(Vendor v) {
    final (statusLabel, statusColor) = StatusUi.approval(v.status);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openDetail(v),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: v.status == ApprovalStatus.pending ? AppColors.warning.withValues(alpha: .4) : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            InitialsAvatar(name: v.displayName, size: 42, imageUrl: v.avatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.displayName, overflow: TextOverflow.ellipsis, style: AppType.body(size: 14, weight: FontWeight.w700)),
                Text([if (v.category.isNotEmpty) v.category, if (v.city.isNotEmpty) v.city].join(' · '),
                    overflow: TextOverflow.ellipsis, style: AppType.body(size: 12, color: AppColors.textMuted)),
              ]),
            ),
            _kycIcon(v),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            StatusChip(label: statusLabel, color: statusColor),
            const Spacer(),
            Flexible(child: _rowActions(v)),
          ]),
        ]),
      ),
    );
  }

  Widget _rowActions(Vendor v) {
    if (_busy.contains(v.id)) return Align(alignment: Alignment.centerLeft, child: ButtonSpinner(color: AppColors.gold));
    return Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: [
      if (v.status == ApprovalStatus.pending) ...[
        _miniBtn('Approve', AppColors.success, () => _setStatus(v, ApprovalStatus.approved)),
        _miniBtn('Reject', AppColors.danger, () => _setStatus(v, ApprovalStatus.rejected)),
      ] else if (v.status == ApprovalStatus.approved)
        _miniBtn('Suspend', AppColors.warning, () => _setStatus(v, ApprovalStatus.suspended))
      else if (v.status == ApprovalStatus.suspended)
        _miniBtn('Reinstate', AppColors.success, () => _setStatus(v, ApprovalStatus.approved))
      else
        _miniBtn('Reconsider', AppColors.info, () => _setStatus(v, ApprovalStatus.pending)),
    ]);
  }

  Widget _miniBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: AppType.body(size: 12, weight: FontWeight.w600, color: color)),
      ),
    );
  }

  Future<void> _openDetail(Vendor v) async {
    await showAdaptiveSheet<void>(
      context,
      maxWidth: 640,
      builder: (ctx) => _VendorDetailSheet(
        vendor: v,
        repo: _repo,
        onChanged: _replace,
        onStatusChange: (vendor, status) {
          Navigator.pop(ctx);
          _setStatus(vendor, status);
        },
      ),
    );
  }
}

class _InviteVendorSheet extends StatefulWidget {
  const _InviteVendorSheet();
  @override
  State<_InviteVendorSheet> createState() => _InviteVendorSheetState();
}

class _InviteVendorSheetState extends State<_InviteVendorSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  String get _link => AppLinks.vendorApp.value;

  String _body() {
    final first = _name.text.trim().split(' ').first;
    return 'Hi${first.isEmpty ? '' : ' $first'},\n\n'
        'We would love to have you on AOneGo9 — the marketplace where clients book verified talent, crews, venues and event services.\n\n'
        '${_link.isEmpty ? 'Create your free vendor account on the AOneGo9 vendor console.' : 'Create your free vendor account here: $_link/#/login'}\n\n'
        'Once you sign up and add your portfolio and packages, our team will review and approve your listing.\n\n'
        '— The AOneGo9 team';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Invite a vendor', style: AppType.display(size: 20)),
        const SizedBox(height: 6),
        Text('Vendors create their own account in the vendor console; this sends them the invitation and link.',
            style: AppType.body(size: 12.5, color: AppColors.textSecondary, height: 1.45)),
        const SizedBox(height: 16),
        if (_link.isEmpty) ...[
          InlineNotice(
            icon: Icons.link_off,
            color: AppColors.warning,
            message: 'Add the vendor console URL in Settings → App links so invitations include a sign-up link.',
          ),
          const SizedBox(height: 14),
        ],
        LabeledField(label: 'Vendor or business name', child: TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Spotlight Talent Co.'))),
        LabeledField(label: 'Email', child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'owner@business.com'))),
        const SizedBox(height: 6),
        ListenableBuilder(
          listenable: Listenable.merge([_email, _name]),
          builder: (context, _) {
            final email = _email.text.trim();
            final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email);
            return Wrap(spacing: 10, runSpacing: 10, children: [
              ElevatedButton.icon(
                onPressed: !valid
                    ? null
                    : () {
                        openExternal(context, mailUri(email, subject: 'Join AOneGo9 as a vendor', body: _body()));
                        Navigator.pop(context);
                      },
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Compose invitation'),
              ),
              OutlinedButton.icon(
                onPressed: () => copyToClipboard(context, _body(), label: 'Invitation copied'),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy message'),
              ),
              if (_link.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => copyToClipboard(context, '$_link/#/login', label: 'Sign-up link copied'),
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Copy link'),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}

class _VendorDetailSheet extends StatefulWidget {
  final Vendor vendor;
  final AdminRepository repo;
  final ValueChanged<Vendor> onChanged;
  final void Function(Vendor vendor, ApprovalStatus status) onStatusChange;
  const _VendorDetailSheet({required this.vendor, required this.repo, required this.onChanged, required this.onStatusChange});

  @override
  State<_VendorDetailSheet> createState() => _VendorDetailSheetState();
}

class _VendorDetailSheetState extends State<_VendorDetailSheet> {
  late Vendor _v = widget.vendor;
  List<Map<String, dynamic>>? _portfolio;
  Map<String, dynamic>? _details;
  List<SubscriptionPlan> _plans = [];
  String? _selectedPlanId;
  bool _assigning = false;
  bool _kycBusy = false;
  late String _planLabel = widget.vendor.plan;

  static final _cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    widget.repo.vendorPortfolio(_v.id).then((p) {
      if (mounted) setState(() => _portfolio = p);
    }).catchError((_) {
      if (mounted) setState(() => _portfolio = []);
    });
    widget.repo.vendorProfileDetails(_v.id).then((d) {
      if (mounted) setState(() => _details = d);
    }).catchError((_) {
      if (mounted) setState(() => _details = {});
    });
    widget.repo.subscriptionPlans().then((plans) {
      if (!mounted) return;
      final vp = plans.where((p) => p.audience == 'vendor' || p.audience == 'both').toList();
      final match = vp.where((p) => p.name.toLowerCase() == _v.plan.toLowerCase()).firstOrNull;
      setState(() {
        _plans = vp;
        _selectedPlanId = match?.id ?? (vp.isNotEmpty ? vp.first.id : null);
      });
    }).catchError((_) {});
  }

  Future<void> _toggleKyc(bool value) async {
    final m = Toast.of(context);
    setState(() => _kycBusy = true);
    try {
      await widget.repo.setVendorKyc(_v.id, value);
      setState(() => _v = _v.copyWith(kycVerified: value));
      widget.onChanged(_v);
      Toast.ok(m, value ? '${_v.displayName} is KYC verified' : 'KYC verification removed');
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not update KYC.'));
    } finally {
      if (mounted) setState(() => _kycBusy = false);
    }
  }

  Future<void> _assignPlan() async {
    final id = _selectedPlanId;
    if (id == null || _assigning) return;
    final m = Toast.of(context);
    setState(() => _assigning = true);
    try {
      await widget.repo.assignVendorPlan(_v.id, id);
      final plan = _plans.firstWhere((p) => p.id == id);
      if (!mounted) return;
      setState(() => _planLabel = plan.name);
      Toast.ok(m, '${_v.displayName} is now on ${plan.name}');
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not assign the plan.'));
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Widget _kv(String k, String v, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(k, style: AppType.body(size: 12.5, color: AppColors.textMuted))),
          Expanded(child: SelectableText(v.isEmpty ? '—' : v, style: AppType.body(size: 13.5, weight: FontWeight.w500))),
          if (trailing != null) trailing,
        ]),
      );

  List<Widget> _statusActions() {
    void act(ApprovalStatus s) => widget.onStatusChange(_v, s);
    Widget primary(String l, IconData i, ApprovalStatus s) =>
        ElevatedButton.icon(onPressed: () => act(s), icon: Icon(i, size: 18), label: Text(l));
    Widget danger(String l, IconData i, ApprovalStatus s, Color c) => OutlinedButton.icon(
          onPressed: () => act(s),
          style: OutlinedButton.styleFrom(foregroundColor: c, side: BorderSide(color: c.withValues(alpha: .5))),
          icon: Icon(i, size: 18),
          label: Text(l),
        );
    return switch (_v.status) {
      ApprovalStatus.pending => [primary('Approve', Icons.check, ApprovalStatus.approved), danger('Reject', Icons.close, ApprovalStatus.rejected, AppColors.danger)],
      ApprovalStatus.approved => [danger('Suspend', Icons.block, ApprovalStatus.suspended, AppColors.warning), danger('Reject', Icons.close, ApprovalStatus.rejected, AppColors.danger)],
      ApprovalStatus.suspended => [primary('Reinstate', Icons.check, ApprovalStatus.approved), danger('Reject', Icons.close, ApprovalStatus.rejected, AppColors.danger)],
      ApprovalStatus.rejected => [primary('Reconsider', Icons.refresh, ApprovalStatus.pending)],
    };
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    final details = _details;
    List list(String k) => (details?[k] as List?) ?? const [];
    String str(String k) => '${details?[k] ?? ''}'.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InitialsAvatar(name: v.displayName, size: 56, imageUrl: v.avatarUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.displayName, style: AppType.display(size: 19)),
              Text([v.name, if (v.category.isNotEmpty) v.category].join(' · '), style: AppType.body(size: 12.5, color: AppColors.textSecondary)),
            ]),
          ),
          StatusChip(label: StatusUi.approval(v.status).$1, color: StatusUi.approval(v.status).$2),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (v.email.isNotEmpty)
            OutlinedButton.icon(onPressed: () => openExternal(context, mailUri(v.email, subject: 'Your AOneGo9 vendor account')), icon: const Icon(Icons.mail_outline, size: 16), label: const Text('Email')),
          if (v.phone.isNotEmpty)
            OutlinedButton.icon(onPressed: () => openExternal(context, telUri(v.phone)), icon: const Icon(Icons.call_outlined, size: 16), label: const Text('Call')),
          if (v.phone.isNotEmpty)
            OutlinedButton.icon(onPressed: () => openExternal(context, whatsappUri(v.phone)), icon: const Icon(Icons.chat_outlined, size: 16), label: const Text('WhatsApp')),
        ]),
        const SizedBox(height: 14),
        _kv('Email', v.email),
        _kv('Phone', v.phone),
        _kv('City', v.city),
        _kv('Rating', v.rating == 0 ? '' : '${v.rating.toStringAsFixed(1)} ★'),
        _kv('Bookings', '${v.totalBookings}'),
        _kv('Lifetime earnings', _cur.format(v.totalEarnings)),
        _kv('Joined', DateFormat('d MMM yyyy').format(v.joinedAt)),
        if (v.lastLoginAt != null) _kv('Last sign-in', formatIstDateTime(v.lastLoginAt!)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Icon(v.kycVerified ? Icons.verified_rounded : Icons.shield_outlined, color: v.kycVerified ? AppColors.success : AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('KYC verification', style: AppType.body(size: 13.5, weight: FontWeight.w700)),
                Text(v.kycVerified ? 'Verified — shows a badge on the marketplace' : 'Not verified — check documents in Leads → KYC',
                    style: AppType.body(size: 12, color: AppColors.textMuted)),
              ]),
            ),
            _kycBusy ? ButtonSpinner(color: AppColors.gold) : Switch(value: v.kycVerified, onChanged: _toggleKyc),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Subscription', style: AppType.body(size: 14, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Current plan: $_planLabel', style: AppType.body(size: 12.5, color: AppColors.textSecondary)),
        if (_plans.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedPlanId,
                isExpanded: true,
                dropdownColor: AppColors.surfaceAlt,
                items: [
                  for (final p in _plans)
                    DropdownMenuItem(value: p.id, child: Text('${p.name} · ${p.price == 0 ? 'Free' : _cur.format(p.price)}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: _assigning ? null : (x) => setState(() => _selectedPlanId = x),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(onPressed: _assigning ? null : _assignPlan, child: _assigning ? const ButtonSpinner() : const Text('Apply')),
          ]),
        ],
        const SizedBox(height: 18),
        Text('Portfolio', style: AppType.body(size: 14, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (_portfolio == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_portfolio!.isEmpty)
          Text('No portfolio works uploaded yet.', style: AppType.body(size: 13, color: AppColors.textMuted))
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _portfolio!.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final item = _portfolio![i];
                final imgs = (item['images'] as List?)?.map((e) => '$e').where((s) => s.isNotEmpty).toList() ?? [];
                final cover = imgs.isNotEmpty ? imgs.first : '${item['image_url'] ?? ''}';
                return Container(
                  width: 150,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Stack(fit: StackFit.expand, children: [
                    if (cover.startsWith('http'))
                      Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())
                    else
                      Center(child: Text('${item['emoji'] ?? '🖼️'}', style: const TextStyle(fontSize: 30))),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
                        child: Text('${item['headline'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: AppType.body(size: 11.5, weight: FontWeight.w600, color: AppColors.posterInk)),
                      ),
                    ),
                    if (item['featured'] == true)
                      const Positioned(top: 6, right: 6, child: Icon(Icons.star, size: 16, color: AppColors.marigold)),
                  ]),
                );
              },
            ),
          ),
        const SizedBox(height: 18),
        Text('Profile details', style: AppType.body(size: 14, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (details == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (str('overview').isEmpty && list('services').isEmpty && list('spaces').isEmpty && list('equipment').isEmpty)
          Text('No extended profile details filled in yet.', style: AppType.body(size: 13, color: AppColors.textMuted))
        else ...[
          if (str('overview').isNotEmpty) _kv('Overview', str('overview')),
          if (str('experience').isNotEmpty) _kv('Experience', str('experience')),
          if (list('services').isNotEmpty) _kv('Services', list('services').join(', ')),
          if (list('spaces').isNotEmpty) _kv('Spaces', '${list('spaces').length} listed'),
          if (list('equipment').isNotEmpty) _kv('Equipment', '${list('equipment').length} items'),
        ],
        const SizedBox(height: 22),
        Wrap(spacing: 10, runSpacing: 10, children: _statusActions()),
      ]),
    );
  }
}
