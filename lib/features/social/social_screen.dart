import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/admin_form.dart';
import '../../core/widgets/common.dart';
import '../../data/models/directory_models.dart';
import '../../data/repositories/admin_repository.dart';

/// Social & Marketing — the AOneGo9 accounts the desk runs.
///
/// From the brief: "vendor admin profile managed to social media accounts
/// AOneGo9 — create admin profile section and marketing". This is the account
/// register: which handles exist, who on the desk owns each one, reach, and
/// where they point. Publishing itself stays in the platforms' own tools —
/// this console is the source of truth for what is ours, not a scheduler.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});
  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _repo = AdminRepository();
  List<SocialAccount> _accounts = [];
  bool _loading = true;

  /// The platforms AOneGo9 actually runs. Offering a free-text platform field
  /// would let two spellings of "Instagram" exist side by side.
  static const _platforms = [
    ('instagram', 'Instagram', '📸'),
    ('youtube', 'YouTube', '▶️'),
    ('linkedin', 'LinkedIn', '💼'),
    ('facebook', 'Facebook', '👥'),
    ('x', 'X', '𝕏'),
    ('pinterest', 'Pinterest', '📌'),
    ('threads', 'Threads', '🧵'),
    ('whatsapp', 'WhatsApp Business', '💬'),
  ];

  static String _icon(String platform) => _platforms
      .where((p) => p.$1 == platform.toLowerCase())
      .map((p) => p.$3)
      .firstOrNull ??
      '🔗';

  static String _label(String platform) => _platforms
      .where((p) => p.$1 == platform.toLowerCase())
      .map((p) => p.$2)
      .firstOrNull ??
      platform;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await _repo.socialAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = a;
      _loading = false;
    });
  }

  void _edit([SocialAccount? existing]) {
    showDialog<void>(
      context: context,
      builder: (_) => _AccountEditor(
        existing: existing,
        platforms: _platforms,
        onSaved: () {
          _load();
          if (mounted) showAdminOk(context, existing == null ? 'Account added' : 'Account updated');
        },
      ),
    );
  }

  Future<void> _delete(SocialAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove account?'),
        content: Text('${_label(a.platform)} (${a.handle}) will be removed from the register.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteSocialAccount(a.id);
      await _load();
      if (mounted) showAdminOk(context, 'Account removed');
    } catch (err) {
      if (mounted) showAdminError(context, err);
    }
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final reach = _accounts.fold<int>(0, (s, a) => s + a.followers);
    final unowned = _accounts.where((a) => a.owner.trim().isEmpty).length;

    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          eyebrow: 'Marketing',
          title: 'Social Accounts',
          subtitle: 'The AOneGo9 handles, who owns each one, and where they point',
          actions: [
            ElevatedButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add account'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(spacing: 14, runSpacing: 14, children: [
          StatCard(label: 'Accounts', value: '${_accounts.length}', icon: Icons.share_outlined, color: AppColors.gold),
          StatCard(label: 'Total reach', value: _fmt(reach), icon: Icons.people_outline, color: AppColors.info),
          StatCard(
            label: 'Connected',
            value: '${_accounts.where((a) => a.connected).length}',
            icon: Icons.link,
            color: AppColors.success,
          ),
          StatCard(
            label: 'No owner',
            value: '$unowned',
            icon: Icons.person_off_outlined,
            color: unowned > 0 ? AppColors.warning : AppColors.textMuted,
          ),
        ]),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Account register',
          child: _accounts.isEmpty
              ? const EmptyView(message: 'No social accounts registered yet', icon: Icons.share_outlined)
              : Column(children: [for (final a in _accounts) _row(a)]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'How this is used',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Accounts marked connected are the handles the marketplace footer and profile '
              'share sheets point at. An account with no owner has nobody on the desk '
              'accountable for replying to it — that is what the warning counter above tracks.',
              style: AppType.body(size: 13, color: AppColors.textSecondary, height: 1.65),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _row(SocialAccount a) {
    final narrow = Responsive.isMobile(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_icon(a.platform), style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(_label(a.platform), style: AppType.body(size: 14, weight: FontWeight.w700)),
              const SizedBox(width: 8),
              if (a.connected) const StatusChip(label: 'Connected', color: AppColors.success),
            ]),
            const SizedBox(height: 3),
            Text(
              [a.handle, if (a.owner.isNotEmpty) 'Owner: ${a.owner}'].where((s) => s.isNotEmpty).join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body(
                size: 12,
                color: a.owner.isEmpty ? AppColors.warning : AppColors.textSecondary,
              ),
            ),
          ]),
        ),
        if (!narrow) ...[
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(_fmt(a.followers), style: AppType.display(size: 16, weight: FontWeight.w600)),
            Text('followers', style: AppType.body(size: 10, color: AppColors.textMuted)),
          ]),
          const SizedBox(width: 16),
        ],
        IconButton(
          onPressed: () => _edit(a),
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Edit',
          color: AppColors.textSecondary,
        ),
        IconButton(
          onPressed: () => _delete(a),
          icon: const Icon(Icons.delete_outline, size: 18),
          tooltip: 'Remove',
          color: AppColors.textMuted,
        ),
      ]),
    );
  }
}

class _AccountEditor extends StatefulWidget {
  final SocialAccount? existing;
  final List<(String, String, String)> platforms;
  final VoidCallback onSaved;
  const _AccountEditor({this.existing, required this.platforms, required this.onSaved});

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  late final _handle = TextEditingController(text: widget.existing?.handle ?? '');
  late final _url = TextEditingController(text: widget.existing?.url ?? '');
  late final _owner = TextEditingController(text: widget.existing?.owner ?? '');
  late final _followers = TextEditingController(text: '${widget.existing?.followers ?? 0}');
  late String _platform = widget.existing?.platform ?? widget.platforms.first.$1;
  late bool _connected = widget.existing?.connected ?? false;

  @override
  void dispose() {
    for (final c in [_handle, _url, _owner, _followers]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep an unrecognised platform from the backend selectable.
    final values = {...widget.platforms.map((p) => p.$1), _platform}.toList();
    return AdminEditor(
      title: widget.existing == null ? 'Add social account' : 'Edit social account',
      subtitle: 'The register of handles AOneGo9 runs',
      saveLabel: widget.existing == null ? 'Add' : 'Save',
      fields: (c) => [
        AdminRow(
          left: AdminField(
            label: 'Platform',
            child: AdminSelect<String>(
              options: [
                for (final v in values)
                  (
                    value: v,
                    label: widget.platforms.where((p) => p.$1 == v).map((p) => '${p.$3}  ${p.$2}').firstOrNull ?? v,
                  ),
              ],
              value: _platform,
              onChanged: (v) => setState(() => _platform = v),
            ),
          ),
          right: AdminField(label: 'Handle', child: AdminInput(controller: _handle, placeholder: '@aonego9')),
        ),
        AdminField(label: 'Profile URL', child: AdminInput(controller: _url, placeholder: 'https://instagram.com/aonego9')),
        AdminRow(
          left: AdminField(
            label: 'Desk owner',
            hint: 'Who replies on this account',
            child: AdminInput(controller: _owner, placeholder: 'Name on the desk'),
          ),
          right: AdminField(
            label: 'Followers',
            child: AdminInput(controller: _followers, placeholder: '0', keyboardType: TextInputType.number),
          ),
        ),
        AdminField(
          label: 'Status',
          hint: 'Connected accounts are the ones the marketplace links to',
          child: AdminToggle(
            value: _connected,
            onLabel: 'Connected',
            offLabel: 'Not connected',
            onChanged: (v) => setState(() => _connected = v),
          ),
        ),
      ],
      onSave: () async {
        final messenger = ScaffoldMessenger.of(context);
        if (_handle.text.trim().isEmpty) {
          showAdminErrorOn(messenger, 'A handle is required');
          return false;
        }
        try {
          await AdminRepository().saveSocialAccount(SocialAccount(
            id: widget.existing?.id ?? '',
            platform: _platform,
            handle: _handle.text.trim(),
            url: _url.text.trim(),
            owner: _owner.text.trim(),
            followers: int.tryParse(_followers.text.trim()) ?? 0,
            connected: _connected,
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
