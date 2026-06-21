import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/responsive_table.dart';
import '../../data/models/models.dart';
import '../../data/models/status_ui.dart';
import '../../data/repositories/admin_repository.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _repo = AdminRepository();
  List<AppUser> _all = [];
  bool _loading = true;
  String _query = '';
  UserRole? _role;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final u = await _repo.users();
    if (!mounted) return;
    setState(() {
      _all = u;
      _loading = false;
    });
  }

  List<AppUser> get _filtered => _all.where((u) {
        final q = _query.isEmpty || u.name.toLowerCase().contains(_query.toLowerCase()) || u.email.toLowerCase().contains(_query.toLowerCase());
        final r = _role == null || u.role == _role;
        return q && r;
      }).toList();

  Future<void> _setStatus(AppUser u, ApprovalStatus s) async {
    await _repo.setUserStatus(u.id, s);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${u.name} → ${StatusUi.approval(s).$1}'), backgroundColor: AppColors.surfaceAlt));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          title: 'Talent & Users',
          subtitle: 'Models, photographers, videographers, venues, event services and clients',
          actions: [OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 18), label: const Text('Export'))],
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _roleChip('All', null),
          for (final r in UserRole.values) _roleChip(StatusUi.role(r), r),
        ]),
        const SizedBox(height: 16),
        SectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SearchField(hint: 'Search talent or users…', onChanged: (v) => setState(() => _query = v)),
            ),
            if (_loading)
              const LoadingView()
            else if (_filtered.isEmpty)
              const EmptyView(message: 'No users match your filters')
            else
              ResponsiveTable(
                columns: const [
                  TableColumn('Name', flex: 3),
                  TableColumn('Role', flex: 2),
                  TableColumn('City', flex: 2),
                  TableColumn('Rating', flex: 1, numeric: true),
                  TableColumn('Jobs', flex: 1, numeric: true),
                  TableColumn('Status', flex: 2),
                  TableColumn('Actions', flex: 2),
                ],
                rowCount: _filtered.length,
                cellsBuilder: (i) {
                  final u = _filtered[i];
                  final (label, color) = StatusUi.approval(u.status);
                  return [
                    Row(children: [
                      InitialsAvatar(name: u.name, size: 34),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                          if (u.verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: AppColors.info)),
                        ]),
                        Text(u.email, style: const TextStyle(color: AppColors.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ])),
                    ]),
                    tcell(StatusUi.role(u.role)),
                    tcell(u.city),
                    tcell(u.rating == 0 ? '—' : '${u.rating}', numeric: true),
                    tcell('${u.jobsDone}', numeric: true),
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

  Widget _actions(AppUser u) {
    return Wrap(spacing: 6, children: [
      if (u.status == ApprovalStatus.pending)
        _mini('Verify', AppColors.success, () => _setStatus(u, ApprovalStatus.approved))
      else if (u.status == ApprovalStatus.approved)
        _mini('Suspend', AppColors.warning, () => _setStatus(u, ApprovalStatus.suspended))
      else
        _mini('Reinstate', AppColors.success, () => _setStatus(u, ApprovalStatus.approved)),
    ]);
  }

  Widget _mini(String l, Color c, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.4))),
          child: Text(l, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _roleChip(String label, UserRole? role) {
    final selected = _role == role;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _role = role),
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
