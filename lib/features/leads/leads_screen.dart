import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/admin_form.dart';
import '../../core/widgets/common.dart';
import '../../core/utils/file_saver.dart';
import '../../core/utils/launch_util.dart';
import '../../data/models/directory_models.dart';
import '../../data/api/api_errors.dart';
import '../../data/repositories/admin_repository.dart';

/// Leads & Applications — every submission from the marketplace's Contact us,
/// Join us and Apply forms, plus partnership notes and session signups.
///
/// Before this the forms had nowhere to land in the console: the desk had no
/// way to see an artist application, let alone act on one.
class LeadsScreen extends StatefulWidget {
  final String initialQuery;
  const LeadsScreen({super.key, this.initialQuery = ''});
  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _repo = AdminRepository();
  List<Lead> _leads = [];
  bool _loading = true;
  String? _error;
  String _kind = 'all';
  String _status = 'all';
  late String _search = widget.initialQuery;
  Lead? _selected;

  static const _kinds = [
    ('all', 'All'),
    ('apply_artist', 'Artists'),
    ('apply_vendor', 'Vendors'),
    ('contact', 'Contact'),
    ('join', 'Join us'),
    ('partner', 'Partners'),
    ('session_register', 'Sessions'),
    ('vendor', 'Vendor requests'),
    ('payout_request', 'Payouts'),
    ('kyc_document', 'KYC'),
    ('password_reset', 'Password resets'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final l = await _repo.leads();
      if (!mounted) return;
      setState(() {
        _leads = l;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e, fallback: 'Could not load this page.');
        });
      }
    }
  }

  Future<void> _export() async {
    final m = Toast.of(context);
    final rows = _visible;
    if (rows.isEmpty) return Toast.info(m, 'Nothing to export in this view.');
    final csv = toCsv(
      ['Date', 'Type', 'Status', 'Name', 'Email', 'Phone', 'City', 'Message'],
      [
        for (final l in rows)
          [l.createdAt == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(l.createdAt!), l.kindLabel, l.status, l.name, l.email, l.phone, l.city, l.message],
      ],
    );
    final dl = await saveTextFile('aonego9-leads-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv', csv);
    Toast.ok(m, dl ? 'Exported ${rows.length} leads' : 'CSV copied to clipboard');
  }

  List<Lead> get _visible {
    var list = _leads;
    if (_kind == 'vendor') {
      list = list.where((l) => l.isVendorRequest).toList();
    } else if (_kind != 'all') {
      list = list.where((l) => l.kind == _kind).toList();
    }
    if (_status != 'all') list = list.where((l) => l.status == _status).toList();
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((l) {
        return '${l.name} ${l.email} ${l.phone} ${l.city} ${l.message}'.toLowerCase().contains(q);
      }).toList();
    }
    final sorted = [...list]..sort((a, b) {
        final x = a.createdAt, y = b.createdAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x); // newest first
      });
    return sorted;
  }

  Future<void> _setStatus(Lead l, String status) async {
    final i = _leads.indexWhere((x) => x.id == l.id);
    if (i != -1) setState(() => _leads[i] = _leads[i].copyWith(status: status));
    if (_selected?.id == l.id) setState(() => _selected = _selected!.copyWith(status: status));
    try {
      await _repo.setLeadStatus(l.id, status);
    } catch (err) {
      if (i != -1 && mounted) setState(() => _leads[i] = l);
      if (mounted) showAdminError(context, err);
    }
  }

  Future<void> _verifyKyc(Lead l) async {
    final ok = await confirmAction(
      context,
      title: 'Mark KYC verified?',
      message: 'Confirm you have checked the ${l.details['document_type'] ?? 'document'} for ${l.details['company'] ?? l.name}. '
          'The vendor gets a verified badge on the marketplace.',
      confirmLabel: 'Mark verified',
    );
    if (!ok || !mounted) return;
    final m = Toast.of(context);
    try {
      await _repo.setVendorKyc(l.vendorId, true);
      Toast.ok(m, '${l.details['company'] ?? l.name} is now KYC verified');
      await _setStatus(l, 'closed');
    } catch (e) {
      showAdminErrorOn(m, e);
    }
  }

  Future<void> _recordPayout(Lead l) async {
    final ok = await confirmAction(
      context,
      title: 'Record payout of ₹${l.amount.toStringAsFixed(0)}?',
      message: 'Only confirm after the transfer to ${l.details['company'] ?? l.name} has been made'
          '${(l.details['payout_to'] ?? '').toString().isEmpty ? '' : ' (${l.details['payout_to']})'}. '
          'It appears in their earnings as a payout.',
      confirmLabel: 'Record payout',
    );
    if (!ok || !mounted) return;
    final m = Toast.of(context);
    try {
      await _repo.triggerPayout(l.vendorId, l.amount);
      Toast.ok(m, 'Payout recorded');
      await _setStatus(l, 'closed');
    } catch (e) {
      showAdminErrorOn(m, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_loading) return const LoadingView();
    final newCount = _leads.where((l) => l.status == 'new').length;
    final applications = _leads.where((l) => l.isApplication).length;

    return PageBody(
      onRefresh: _load,
      children: [
        PageHeader(
          eyebrow: 'Inbound',
          title: 'Leads & Applications',
          subtitle: 'Applications, contact forms, session signups and requests from vendors',
          actions: [
            OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Export CSV')),
          ],
        ),
        const SizedBox(height: 24),
        ResponsiveGrid(minTileWidth: 180, children: [
          StatCard(label: 'Total', value: '${_leads.length}', icon: Icons.inbox_outlined, color: AppColors.gold),
          StatCard(label: 'Unactioned', value: '$newCount', icon: Icons.mark_email_unread_outlined, color: AppColors.warning),
          StatCard(label: 'Applications', value: '$applications', icon: Icons.badge_outlined, color: AppColors.info),
          StatCard(
            label: 'Closed',
            value: '${_leads.where((l) => l.status == 'closed').length}',
            icon: Icons.task_alt,
            color: AppColors.success,
          ),
        ]),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Inbox',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchField(initial: _search, hint: 'Search name, email, phone, city…', onChanged: (v) => setState(() => _search = v)),
              const SizedBox(height: 14),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in _kinds)
                  _Chip(
                    label: k.$2,
                    count: k.$1 == 'all'
                        ? _leads.length
                        : k.$1 == 'vendor'
                            ? _leads.where((l) => l.isVendorRequest).length
                            : _leads.where((l) => l.kind == k.$1).length,
                    active: _kind == k.$1,
                    onTap: () => setState(() => _kind = k.$1),
                  ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in const [('all', 'Any status'), ('new', 'New'), ('in_progress', 'In progress'), ('closed', 'Closed')])
                  _Chip(label: s.$2, active: _status == s.$1, onTap: () => setState(() => _status = s.$1)),
              ]),
              const SizedBox(height: 16),
              if (_visible.isEmpty)
                const EmptyView(message: 'Nothing matches these filters', icon: Icons.filter_alt_off_outlined)
              else
                for (final l in _visible) _row(l),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(Lead l) {
    final color = switch (l.status) {
      'closed' => AppColors.success,
      'in_progress' => AppColors.info,
      _ => AppColors.warning,
    };
    final narrow = Responsive.isMobile(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: l.status == 'new' ? AppColors.warning.withValues(alpha: .35) : AppColors.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InitialsAvatar(name: l.name.isEmpty ? '?' : l.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  StatusChip(label: l.kindLabel, color: l.isApplication ? AppColors.info : AppColors.gold),
                  const SizedBox(width: 8),
                  if (l.fromVerifiedVendor) ...[
                    Tooltip(message: 'Sent by a signed-in vendor', child: Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success)),
                    const SizedBox(width: 8),
                  ],
                  StatusChip(label: l.status.replaceAll('_', ' '), color: color),
                ]),
                const SizedBox(height: 6),
                Text(l.name.isEmpty ? '(no name given)' : l.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(size: 14, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  [l.email, l.phone, if (l.city.isNotEmpty) l.city].where((s) => s.isNotEmpty).join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 12, color: AppColors.textSecondary),
                ),
              ]),
            ),
            if (!narrow && l.createdAt != null) ...[
              const SizedBox(width: 12),
              Text(DateFormat('d MMM, HH:mm').format(l.createdAt!),
                  style: AppType.body(size: 11, color: AppColors.textMuted)),
              const SizedBox(width: 12),
            ],
            IconButton(
              onPressed: () => setState(() => _selected = _selected?.id == l.id ? null : l),
              icon: Icon(_selected?.id == l.id ? Icons.expand_less : Icons.expand_more, size: 20),
              tooltip: 'Details',
              color: AppColors.textSecondary,
            ),
          ]),
          if (_selected?.id == l.id) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            if (l.message.isNotEmpty) ...[
              Text('MESSAGE',
                  style: AppType.body(size: 10, weight: FontWeight.w700, color: AppColors.textMuted)
                      .copyWith(letterSpacing: 1.3)),
              const SizedBox(height: 5),
              Text(l.message, style: AppType.body(size: 13, color: AppColors.textPrimary, height: 1.6)),
              const SizedBox(height: 14),
            ],
            if (l.details.isNotEmpty) ...[
              Text('SUBMITTED FIELDS',
                  style: AppType.body(size: 10, weight: FontWeight.w700, color: AppColors.textMuted)
                      .copyWith(letterSpacing: 1.3)),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in l.details.entries)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${_pretty(e.key)}: ',
                            style: AppType.body(size: 11, color: AppColors.textMuted)),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text('${e.value}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.body(size: 11, weight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (l.email.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => openExternal(
                    context,
                    mailUri(l.email, subject: 'Re: your ${l.kindLabel.toLowerCase()} — AOneGo9', body: 'Hi ${l.name.split(' ').first},\n\n'),
                  ),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Reply by email'),
                ),
              if (l.phone.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => openExternal(context, telUri(l.phone)),
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: const Text('Call'),
                ),
              if (l.documentUrl.startsWith('http'))
                OutlinedButton.icon(
                  onPressed: () => openExternal(context, Uri.parse(l.documentUrl)),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open document'),
                ),
              if (l.kind == 'kyc_document' && l.vendorId.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _verifyKyc(l),
                  icon: const Icon(Icons.verified_outlined, size: 16),
                  label: const Text('Mark vendor KYC verified'),
                ),
              if (l.kind == 'payout_request' && l.vendorId.isNotEmpty && l.amount > 0)
                OutlinedButton.icon(
                  onPressed: () => _recordPayout(l),
                  icon: const Icon(Icons.account_balance_outlined, size: 16),
                  label: Text('Record payout ₹${l.amount.toStringAsFixed(0)}'),
                ),
              for (final s in const [('new', 'Mark new'), ('in_progress', 'In progress'), ('closed', 'Close')])
                OutlinedButton(
                  onPressed: l.status == s.$1 ? null : () => _setStatus(l, s.$1),
                  child: Text(s.$2),
                ),
            ]),
          ],
        ],
      ),
    );
  }

  /// snake_case payload keys read badly as labels; this is the cheapest
  /// readable form without maintaining a translation table per form.
  String _pretty(String key) {
    final words = key.split('_').where((w) => w.isNotEmpty);
    return words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.gold.withValues(alpha: .14) : Colors.transparent,
            border: Border.all(color: active ? AppColors.gold : AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: AppType.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: active ? AppColors.gold : AppColors.textSecondary)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text('$count',
                  style: AppType.body(size: 11, color: active ? AppColors.gold : AppColors.textMuted)),
            ],
          ]),
        ),
      );
}
