import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/admin_form.dart';
import '../../core/widgets/common.dart';
import '../../data/models/directory_models.dart';
import '../../data/repositories/admin_repository.dart';

/// Leads & Applications — every submission from the marketplace's Contact us,
/// Join us and Apply forms, plus partnership notes and session signups.
///
/// Before this the forms had nowhere to land in the console: the desk had no
/// way to see an artist application, let alone act on one.
class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});
  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _repo = AdminRepository();
  List<Lead> _leads = [];
  bool _loading = true;
  String _kind = 'all';
  String _status = 'all';
  String _search = '';
  Lead? _selected;

  static const _kinds = [
    ('all', 'All'),
    ('apply_artist', 'Artists'),
    ('apply_vendor', 'Vendors'),
    ('contact', 'Contact'),
    ('join', 'Join us'),
    ('partner', 'Partners'),
    ('session_register', 'Sessions'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await _repo.leads();
    if (!mounted) return;
    setState(() {
      _leads = l;
      _loading = false;
    });
  }

  List<Lead> get _visible {
    var list = _leads;
    if (_kind != 'all') list = list.where((l) => l.kind == _kind).toList();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final newCount = _leads.where((l) => l.status == 'new').length;
    final applications = _leads.where((l) => l.isApplication).length;

    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        const PageHeader(
          eyebrow: 'Inbound',
          title: 'Leads & Applications',
          subtitle: 'Contact, join us, artist and vendor applications, partnerships and session signups',
        ),
        const SizedBox(height: 24),
        Wrap(spacing: 14, runSpacing: 14, children: [
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
              SearchField(hint: 'Search name, email, phone, city…', onChanged: (v) => setState(() => _search = v)),
              const SizedBox(height: 14),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in _kinds)
                  _Chip(
                    label: k.$2,
                    count: k.$1 == 'all' ? _leads.length : _leads.where((l) => l.kind == k.$1).length,
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
