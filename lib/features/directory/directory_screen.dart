import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/admin_form.dart';
import '../../core/widgets/common.dart';
import '../../data/models/directory_models.dart';
import '../../data/repositories/admin_repository.dart';

/// Partners & Team — the two logo/roster walls the marketplace renders.
///
/// One screen with two tabs rather than two nav entries: they are curated by
/// the same desk, in the same sitting, and both are "who stands behind the
/// floor" content.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _repo = AdminRepository();
  List<LogoPartner> _partners = [];
  List<TeamMember> _team = [];
  bool _loading = true;
  String _tab = 'partners';
  String _tier = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([_repo.partners(), _repo.team()]);
    if (!mounted) return;
    setState(() {
      _partners = results[0] as List<LogoPartner>;
      _team = results[1] as List<TeamMember>;
      _loading = false;
    });
  }

  List<LogoPartner> get _visiblePartners => _tier == 'all'
      ? _partners
      : _partners.where((p) => p.tier.name == _tier).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final isPartners = _tab == 'partners';

    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          eyebrow: 'Who stands behind the floor',
          title: 'Partners & Team',
          subtitle: 'Academic and brand partner walls, plus the AOneGo9 desk roster',
          actions: [
            ElevatedButton.icon(
              onPressed: isPartners ? () => _editPartner() : () => _editMember(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(isPartners ? 'New partner' : 'New member'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(spacing: 14, runSpacing: 14, children: [
          StatCard(
            label: 'Brand partners',
            value: '${_partners.where((p) => p.tier != PartnerTier.academic).length}',
            icon: Icons.handshake_outlined,
            color: AppColors.gold,
          ),
          StatCard(
            label: 'Academic partners',
            value: '${_partners.where((p) => p.tier == PartnerTier.academic).length}',
            icon: Icons.school_outlined,
            color: AppColors.info,
          ),
          StatCard(label: 'Team members', value: '${_team.length}', icon: Icons.groups_outlined, color: AppColors.success),
          StatCard(
            label: 'Missing logos',
            value: '${_partners.where((p) => p.logoUrl.isEmpty).length}',
            icon: Icons.image_not_supported_outlined,
            color: AppColors.warning,
          ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          _Tab(label: 'Partners', active: isPartners, onTap: () => setState(() => _tab = 'partners')),
          const SizedBox(width: 8),
          _Tab(label: 'Team', active: !isPartners, onTap: () => setState(() => _tab = 'team')),
        ]),
        const SizedBox(height: 16),
        if (isPartners) _partnersCard() else _teamCard(),
      ],
    );
  }

  Widget _partnersCard() => SectionCard(
        title: 'Partner walls',
        actions: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.bg,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final o in const [('all', 'All'), ('brand', 'Brand'), ('academic', 'Academic'), ('institutional', 'Bodies')])
                InkWell(
                  onTap: () => setState(() => _tier = o.$1),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: _tier == o.$1 ? AppColors.gold.withValues(alpha: .16) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(o.$2,
                        style: AppType.body(
                            size: 12,
                            weight: FontWeight.w700,
                            color: _tier == o.$1 ? AppColors.gold : AppColors.textMuted)),
                  ),
                ),
            ]),
          ),
        ],
        child: _visiblePartners.isEmpty
            ? const EmptyView(message: 'No partners published yet', icon: Icons.handshake_outlined)
            : Column(children: [for (final p in _visiblePartners) _partnerRow(p)]),
      );

  Widget _partnerRow(LogoPartner p) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(children: [
          _LogoThumb(name: p.name, url: p.logoUrl),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(
                  child: Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(size: 14, weight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                StatusChip(
                  label: p.tierLabel,
                  color: p.tier == PartnerTier.academic ? AppColors.info : AppColors.gold,
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                [if (p.division.isNotEmpty) p.division, if (p.city.isNotEmpty) p.city].join('  ·  '),
                style: AppType.body(size: 12, color: AppColors.textSecondary),
              ),
              if (p.logoUrl.isEmpty) ...[
                const SizedBox(height: 4),
                Text('No logo uploaded — the wall falls back to a monogram',
                    style: AppType.body(size: 11, color: AppColors.warning)),
              ],
            ]),
          ),
          AdminToggle(value: p.published, onChanged: (v) => _togglePartner(p, v)),
          IconButton(
            onPressed: () => _editPartner(p),
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit',
            color: AppColors.textSecondary,
          ),
        ]),
      );

  Widget _teamCard() {
    final byDesk = <String, List<TeamMember>>{};
    for (final m in _team) {
      byDesk.putIfAbsent(m.desk, () => []).add(m);
    }
    final ordered = [
      ...adminTeamDesks.where(byDesk.containsKey),
      ...byDesk.keys.where((d) => !adminTeamDesks.contains(d)),
    ];

    return SectionCard(
      title: 'The desk',
      child: _team.isEmpty
          ? const EmptyView(message: 'No team members added yet', icon: Icons.groups_outlined)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final desk in ordered) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 10),
                    child: Row(children: [
                      Eyebrow(desk),
                      const SizedBox(width: 10),
                      Expanded(child: Container(height: 1, color: AppColors.border)),
                    ]),
                  ),
                  for (final m in byDesk[desk]!) _memberRow(m),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  Widget _memberRow(TeamMember m) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(children: [
          InitialsAvatar(name: m.name, size: 42),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 14, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                [m.role, if (m.city.isNotEmpty) m.city].where((s) => s.isNotEmpty).join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body(size: 12, color: AppColors.textSecondary),
              ),
            ]),
          ),
          AdminToggle(value: m.published, onChanged: (v) => _toggleMember(m, v)),
          IconButton(
            onPressed: () => _editMember(m),
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit',
            color: AppColors.textSecondary,
          ),
        ]),
      );

  Future<void> _togglePartner(LogoPartner p, bool v) async {
    final i = _partners.indexWhere((x) => x.id == p.id);
    if (i != -1) setState(() => _partners[i] = _partners[i].copyWith(published: v));
    try {
      await _repo.setPartnerPublished(p.id, v);
    } catch (err) {
      if (i != -1 && mounted) setState(() => _partners[i] = p);
      if (mounted) showAdminError(context, err);
    }
  }

  Future<void> _toggleMember(TeamMember m, bool v) async {
    final i = _team.indexWhere((x) => x.id == m.id);
    if (i != -1) setState(() => _team[i] = _team[i].copyWith(published: v));
    try {
      await _repo.setTeamPublished(m.id, v);
    } catch (err) {
      if (i != -1 && mounted) setState(() => _team[i] = m);
      if (mounted) showAdminError(context, err);
    }
  }

  void _editPartner([LogoPartner? existing]) {
    showDialog<void>(
      context: context,
      builder: (_) => _PartnerEditor(
        existing: existing,
        onSaved: () {
          _load();
          if (mounted) showAdminOk(context, existing == null ? 'Partner added' : 'Partner updated');
        },
      ),
    );
  }

  void _editMember([TeamMember? existing]) {
    showDialog<void>(
      context: context,
      builder: (_) => _MemberEditor(
        existing: existing,
        onSaved: () {
          _load();
          if (mounted) showAdminOk(context, existing == null ? 'Member added' : 'Member updated');
        },
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.gold.withValues(alpha: .14) : AppColors.surface,
            border: Border.all(color: active ? AppColors.gold : AppColors.border),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              style: AppType.body(
                  size: 13,
                  weight: FontWeight.w700,
                  color: active ? AppColors.gold : AppColors.textSecondary)),
        ),
      );
}

/// Small logo preview. Falls back to a monogram exactly as the marketplace
/// wall does, so the desk sees what visitors will see.
class _LogoThumb extends StatelessWidget {
  final String name;
  final String url;
  const _LogoThumb({required this.name, required this.url});

  String get _initials {
    final w = name.replaceAll(RegExp(r'[^\w\s]'), ' ').split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (w.isEmpty) return '?';
    if (w.length == 1) return (w.first.length >= 2 ? w.first.substring(0, 2) : w.first).toUpperCase();
    return (w[0][0] + w[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: url.trim().isEmpty
            ? Center(child: Text(_initials, style: AppType.display(size: 15, weight: FontWeight.w600, color: AppColors.gold)))
            : Padding(
                padding: const EdgeInsets.all(6),
                child: Image.network(
                  url.trim(),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(_initials, style: AppType.display(size: 15, weight: FontWeight.w600, color: AppColors.gold)),
                  ),
                ),
              ),
      );
}

class _PartnerEditor extends StatefulWidget {
  final LogoPartner? existing;
  final VoidCallback onSaved;
  const _PartnerEditor({this.existing, required this.onSaved});
  @override
  State<_PartnerEditor> createState() => _PartnerEditorState();
}

class _PartnerEditorState extends State<_PartnerEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _tagline = TextEditingController(text: widget.existing?.tagline ?? '');
  late final _logo = TextEditingController(text: widget.existing?.logoUrl ?? '');
  late final _division = TextEditingController(text: widget.existing?.division ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _website = TextEditingController(text: widget.existing?.website ?? '');
  late PartnerTier _tier = widget.existing?.tier ?? PartnerTier.brand;

  @override
  void dispose() {
    for (final c in [_name, _tagline, _logo, _division, _city, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEditor(
      title: widget.existing == null ? 'New partner' : 'Edit partner',
      subtitle: 'Appears on the marketplace partner wall',
      saveLabel: widget.existing == null ? 'Add' : 'Save',
      fields: (c) => [
        AdminRow(
          left: AdminField(
            label: 'Tier',
            child: AdminSelect<PartnerTier>(
              options: const [
                (value: PartnerTier.brand, label: 'Brand partner'),
                (value: PartnerTier.academic, label: 'Academic partner'),
                (value: PartnerTier.institutional, label: 'Industry body'),
              ],
              value: _tier,
              onChanged: (v) => setState(() => _tier = v),
            ),
          ),
          right: AdminField(
            label: 'Division',
            hint: _tier == PartnerTier.academic
                ? 'The stream they teach, e.g. Film & Media'
                : 'One of the brand divisions, e.g. Fashion & Apparel',
            child: AdminInput(
              controller: _division,
              placeholder: _tier == PartnerTier.academic ? 'Film & Media' : adminBrandDivisions.first,
            ),
          ),
        ),
        AdminField(label: 'Name', child: AdminInput(controller: _name, placeholder: 'Lakmé Fashion Week')),
        AdminField(label: 'Tagline', child: AdminInput(controller: _tagline, placeholder: 'One line on what they do with us', minLines: 2)),
        AdminField(
          label: 'Logo URL',
          hint: 'Leave blank and the wall renders a typographic monogram instead',
          child: AdminInput(controller: _logo, placeholder: 'https://…/logo.png'),
        ),
        AdminRow(
          left: AdminField(label: 'City', child: AdminInput(controller: _city, placeholder: 'Mumbai')),
          right: AdminField(label: 'Website', child: AdminInput(controller: _website, placeholder: 'https://…')),
        ),
      ],
      onSave: () async {
        final messenger = ScaffoldMessenger.of(context);
        if (_name.text.trim().isEmpty) {
          showAdminErrorOn(messenger, 'A partner name is required');
          return false;
        }
        try {
          await AdminRepository().savePartner(LogoPartner(
            id: widget.existing?.id ?? '',
            name: _name.text.trim(),
            tagline: _tagline.text.trim(),
            logoUrl: _logo.text.trim(),
            tier: _tier,
            division: _division.text.trim(),
            city: _city.text.trim(),
            website: _website.text.trim(),
            published: widget.existing?.published ?? true,
          ));
          widget.onSaved();
          return true;
        } catch (err) {
          showAdminErrorOn(messenger, err);
          return false;
        }
      },
    );
  }
}

class _MemberEditor extends StatefulWidget {
  final TeamMember? existing;
  final VoidCallback onSaved;
  const _MemberEditor({this.existing, required this.onSaved});
  @override
  State<_MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends State<_MemberEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _role = TextEditingController(text: widget.existing?.role ?? '');
  late final _bio = TextEditingController(text: widget.existing?.bio ?? '');
  late final _photo = TextEditingController(text: widget.existing?.photoUrl ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late String _desk = widget.existing?.desk ?? adminTeamDesks.first;

  @override
  void dispose() {
    for (final c in [_name, _role, _bio, _photo, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A desk that came from the backend but isn't in the canonical list must
    // still be selectable, or editing that member would silently move them.
    final desks = {..._deskOptions(), _desk}.toList();
    return AdminEditor(
      title: widget.existing == null ? 'New team member' : 'Edit team member',
      subtitle: 'Appears on the marketplace “Our team” page, grouped by desk',
      saveLabel: widget.existing == null ? 'Add' : 'Save',
      fields: (c) => [
        AdminRow(
          left: AdminField(label: 'Name', child: AdminInput(controller: _name, placeholder: 'Full name')),
          right: AdminField(
            label: 'Desk',
            child: AdminSelect<String>(
              options: [for (final d in desks) (value: d, label: d)],
              value: _desk,
              onChanged: (v) => setState(() => _desk = v),
            ),
          ),
        ),
        AdminField(label: 'Role', child: AdminInput(controller: _role, placeholder: 'Head of Casting')),
        AdminField(label: 'Bio', child: AdminInput(controller: _bio, placeholder: 'One or two lines', minLines: 3)),
        AdminRow(
          left: AdminField(label: 'Photo URL', child: AdminInput(controller: _photo, placeholder: 'https://…')),
          right: AdminField(label: 'City', child: AdminInput(controller: _city, placeholder: 'Mumbai')),
        ),
      ],
      onSave: () async {
        final messenger = ScaffoldMessenger.of(context);
        if (_name.text.trim().isEmpty) {
          showAdminErrorOn(messenger, 'A name is required');
          return false;
        }
        try {
          await AdminRepository().saveTeamMember(TeamMember(
            id: widget.existing?.id ?? '',
            name: _name.text.trim(),
            role: _role.text.trim(),
            desk: _desk,
            bio: _bio.text.trim(),
            photoUrl: _photo.text.trim(),
            city: _city.text.trim(),
            published: widget.existing?.published ?? true,
          ));
          widget.onSaved();
          return true;
        } catch (err) {
          showAdminErrorOn(messenger, err);
          return false;
        }
      },
    );
  }

  List<String> _deskOptions() => adminTeamDesks;
}
