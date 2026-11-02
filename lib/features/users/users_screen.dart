import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/file_saver.dart';
import '../../core/utils/launch_util.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/responsive_table.dart';
import '../../data/api/api_errors.dart';
import '../../data/models/models.dart';
import '../../data/models/status_ui.dart';
import '../../data/repositories/admin_repository.dart';

class UsersScreen extends StatefulWidget {
  final String initialQuery;
  const UsersScreen({super.key, this.initialQuery = ''});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _repo = AdminRepository();
  List<AppUser> _all = [];
  bool _loading = true;
  String? _error;
  late String _query = widget.initialQuery;
  UserRole? _role;
  ApprovalStatus? _status;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UsersScreen old) {
    super.didUpdateWidget(old);
    if (old.initialQuery != widget.initialQuery) setState(() => _query = widget.initialQuery);
  }

  Future<void> _load() async {
    setState(() {
      _loading = _all.isEmpty;
      _error = null;
    });
    try {
      final u = await _repo.users();
      if (!mounted) return;
      u.sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
      setState(() {
        _all = u;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e, fallback: 'Could not load users.');
        });
      }
    }
  }

  List<AppUser> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((u) {
      if (_role != null && u.role != _role) return false;
      if (_status != null && u.status != _status) return false;
      return q.isEmpty || '${u.name} ${u.email} ${u.phone} ${u.city}'.toLowerCase().contains(q);
    }).toList();
  }

  void _replace(AppUser u) {
    final i = _all.indexWhere((x) => x.id == u.id);
    if (i != -1) setState(() => _all[i] = u);
  }

  Future<void> _setStatus(AppUser u, ApprovalStatus s) async {
    if (s == ApprovalStatus.suspended) {
      final ok = await confirmAction(
        context,
        title: 'Suspend ${u.name}?',
        message: 'They will not be able to sign in or send inquiries until reinstated.',
        confirmLabel: 'Suspend',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    final m = Toast.of(context);
    _replace(u.copyWith(status: s));
    setState(() => _busy.add(u.id));
    try {
      await _repo.setUserStatus(u.id, s);
      Toast.ok(m, '${u.name} → ${StatusUi.approval(s).$1}');
    } catch (e) {
      _replace(u);
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not update the user.'));
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  Future<void> _verify(AppUser u) async {
    final m = Toast.of(context);
    setState(() => _busy.add(u.id));
    try {
      await _repo.verifyUser(u.id);
      _replace(u.copyWith(verified: true));
      Toast.ok(m, '${u.name} is verified');
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not verify the user.'));
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  Future<void> _export() async {
    final m = Toast.of(context);
    final rows = _filtered;
    if (rows.isEmpty) return Toast.info(m, 'No users in this view to export.');
    final df = DateFormat('yyyy-MM-dd');
    final csv = toCsv(
      ['ID', 'Name', 'Email', 'Phone', 'City', 'Role', 'Status', 'Verified', 'Rating', 'Jobs', 'Joined'],
      [
        for (final u in rows)
          [u.id, u.name, u.email, u.phone, u.city, StatusUi.role(u.role), u.status.name, u.verified ? 'yes' : 'no', u.rating, u.jobsDone, df.format(u.joinedAt)],
      ],
    );
    final dl = await saveTextFile('aonego9-users-${df.format(DateTime.now())}.csv', csv);
    Toast.ok(m, dl ? 'Exported ${rows.length} users' : 'CSV copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _all.isEmpty) return ErrorView(message: _error!, onRetry: _load);
    final list = _filtered;
    return PageBody(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'Talent & Users',
          subtitle: 'Clients, models, photographers, videographers, venues and event services',
          actions: [OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Export CSV'))],
        ),
        const SizedBox(height: 18),
        if (!_loading && _all.isNotEmpty) ...[
          ResponsiveGrid(minTileWidth: 170, children: [
            StatCard(label: 'Total', value: '${_all.length}', icon: Icons.people_outline, color: AppColors.gold),
            StatCard(label: 'Verified', value: '${_all.where((u) => u.verified).length}', icon: Icons.verified_outlined, color: AppColors.success),
            StatCard(label: 'Pending', value: '${_all.where((u) => u.status == ApprovalStatus.pending).length}', icon: Icons.hourglass_top, color: AppColors.warning),
            StatCard(
              label: 'Joined this month',
              value: '${_all.where((u) => u.joinedAt.year == DateTime.now().year && u.joinedAt.month == DateTime.now().month).length}',
              icon: Icons.person_add_alt,
              color: AppColors.info,
            ),
          ]),
          const SizedBox(height: 16),
        ],
        PillBar(children: [
          FilterPill(label: 'All roles', selected: _role == null, count: _all.length, onTap: () => setState(() => _role = null)),
          for (final r in UserRole.values)
            FilterPill(label: StatusUi.role(r), selected: _role == r, count: _all.where((u) => u.role == r).length, onTap: () => setState(() => _role = r)),
        ]),
        const SizedBox(height: 10),
        PillBar(children: [
          FilterPill(label: 'Any status', selected: _status == null, onTap: () => setState(() => _status = null)),
          for (final s in ApprovalStatus.values)
            FilterPill(label: StatusUi.approval(s).$1, selected: _status == s, color: StatusUi.approval(s).$2, onTap: () => setState(() => _status = s)),
        ]),
        const SizedBox(height: 14),
        SectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SearchField(key: ValueKey('uq-${widget.initialQuery}'), initial: _query, hint: 'Search name, email, phone or city…', onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 8),
            if (_loading)
              const LoadingView()
            else if (list.isEmpty)
              EmptyView(icon: Icons.people_outline, message: _all.isEmpty ? 'No users yet' : 'No users match your filters')
            else
              ResponsiveTable(
                columns: const [
                  TableColumn('Name', flex: 4),
                  TableColumn('Role', flex: 2),
                  TableColumn('City', flex: 2),
                  TableColumn('Joined', flex: 2),
                  TableColumn('Status', flex: 2),
                  TableColumn('Actions', flex: 2),
                ],
                rowCount: list.length,
                onRowTap: (i) => _openDetail(list[i]),
                mobileCardBuilder: (i) => _mobileCard(list[i]),
                cellsBuilder: (i) {
                  final u = list[i];
                  final (label, color) = StatusUi.approval(u.status);
                  return [
                    _nameCell(u),
                    tcell(StatusUi.role(u.role)),
                    tcell(u.city.isEmpty ? '—' : u.city),
                    tcell(DateFormat('d MMM yyyy').format(u.joinedAt)),
                    StatusChip(label: label, color: color),
                    _actions(u),
                  ];
                },
              ),
          ]),
        ),
      ],
    );
  }

  Widget _nameCell(AppUser u) => Row(children: [
        InitialsAvatar(name: u.name, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(u.name, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13.5, weight: FontWeight.w600))),
              if (u.verified) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: AppColors.info)),
            ]),
            Text(u.email, overflow: TextOverflow.ellipsis, style: AppType.body(size: 12, color: AppColors.textMuted)),
          ]),
        ),
      ]);

  Widget _mobileCard(AppUser u) {
    final (label, color) = StatusUi.approval(u.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _nameCell(u),
        const SizedBox(height: 10),
        Row(children: [
          StatusChip(label: label, color: color),
          const SizedBox(width: 6),
          Flexible(child: StatusChip(label: StatusUi.role(u.role), color: AppColors.info)),
          const Spacer(),
          _actions(u),
        ]),
      ]),
    );
  }

  Widget _actions(AppUser u) {
    if (_busy.contains(u.id)) return ButtonSpinner(color: AppColors.gold);
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (u.status == ApprovalStatus.pending)
        _mini('Approve', AppColors.success, () => _setStatus(u, ApprovalStatus.approved))
      else if (u.status == ApprovalStatus.approved)
        _mini('Suspend', AppColors.warning, () => _setStatus(u, ApprovalStatus.suspended))
      else
        _mini('Reinstate', AppColors.success, () => _setStatus(u, ApprovalStatus.approved)),
      if (!u.verified && u.status != ApprovalStatus.rejected) _mini('Verify', AppColors.info, () => _verify(u)),
    ]);
  }

  Widget _mini(String l, Color c, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.4))),
          child: Text(l, style: AppType.body(size: 12, weight: FontWeight.w600, color: c)),
        ),
      );

  Future<void> _openDetail(AppUser u) async {
    await showAdaptiveSheet<void>(
      context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            InitialsAvatar(name: u.name, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: AppType.display(size: 19)),
                Text(StatusUi.role(u.role), style: AppType.body(size: 12.5, color: AppColors.textSecondary)),
              ]),
            ),
            StatusChip(label: StatusUi.approval(u.status).$1, color: StatusUi.approval(u.status).$2),
          ]),
          const SizedBox(height: 16),
          for (final (k, v) in [
            ('Email', u.email),
            ('Phone', u.phone),
            ('City', u.city),
            ('Verified', u.verified ? 'Yes' : 'No'),
            ('Rating', u.rating == 0 ? '—' : u.rating.toStringAsFixed(1)),
            ('Jobs done', '${u.jobsDone}'),
            ('Joined', DateFormat('d MMM yyyy').format(u.joinedAt)),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 110, child: Text(k, style: AppType.body(size: 12.5, color: AppColors.textMuted))),
                Expanded(child: SelectableText(v.isEmpty ? '—' : v, style: AppType.body(size: 13.5, weight: FontWeight.w500))),
              ]),
            ),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (u.email.isNotEmpty)
              OutlinedButton.icon(onPressed: () => openExternal(ctx, mailUri(u.email, subject: 'Your AOneGo9 account')), icon: const Icon(Icons.mail_outline, size: 16), label: const Text('Email')),
            if (u.phone.isNotEmpty)
              OutlinedButton.icon(onPressed: () => openExternal(ctx, telUri(u.phone)), icon: const Icon(Icons.call_outlined, size: 16), label: const Text('Call')),
            if (!u.verified)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _verify(u);
                },
                icon: const Icon(Icons.verified_outlined, size: 16),
                label: const Text('Verify'),
              ),
          ]),
        ]),
      ),
    );
  }
}
