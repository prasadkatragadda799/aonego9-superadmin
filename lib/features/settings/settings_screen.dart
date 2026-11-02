import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_store.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/app_links.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_errors.dart';
import '../../data/repositories/admin_repository.dart';

/// Settings. Platform settings and the admin team are server-backed
/// (GET/PUT /settings/platform, GET /admins, POST /admins/invite); a backend
/// without those routes gets a clear notice instead of toggles that silently
/// reset on reload.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = AdminRepository();

  // Platform settings
  bool _platformLoading = true;
  String? _platformUnavailable;
  bool _savingPlatform = false;
  double _commission = 15;
  bool _autoApproveKyc = false;
  bool _emailAlerts = true;
  bool _payoutHold = true;
  Map<String, dynamic> _savedPlatform = {};

  // Team
  bool _teamLoading = true;
  String? _teamUnavailable;
  List<Map<String, dynamic>> _admins = [];

  // Account
  String _email = '';
  String _city = '';

  // Links
  late final _vendorUrl = TextEditingController(text: AppLinks.vendorApp.value);
  late final _userUrl = TextEditingController(text: AppLinks.userApp.value);

  @override
  void initState() {
    super.initState();
    _loadPlatform();
    _loadTeam();
    ApiClient.getEmail().then((e) => mounted ? setState(() => _email = e ?? '') : null);
    ApiClient.getCity().then((c) => mounted ? setState(() => _city = c) : null);
  }

  @override
  void dispose() {
    _vendorUrl.dispose();
    _userUrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _platformBody => {
        'commission_percent': _commission.round(),
        'auto_approve_kyc': _autoApproveKyc,
        'email_alerts': _emailAlerts,
        'payout_hold_hours': _payoutHold ? 48 : 0,
      };

  bool get _dirty => _platformBody.toString() != _savedPlatform.toString();

  void _applyPlatform(Map<String, dynamic> d) {
    _commission = ((d['commission_percent'] as num?) ?? _commission).toDouble().clamp(0, 30);
    _autoApproveKyc = d['auto_approve_kyc'] == true;
    _emailAlerts = d['email_alerts'] != false;
    _payoutHold = ((d['payout_hold_hours'] as num?) ?? 48) > 0;
    _savedPlatform = _platformBody;
  }

  Future<void> _loadPlatform() async {
    setState(() {
      _platformLoading = true;
      _platformUnavailable = null;
    });
    try {
      final d = await _repo.platformSettings();
      if (!mounted) return;
      setState(() {
        _applyPlatform(d);
        _platformLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _platformLoading = false;
        _platformUnavailable = e is ApiException && e.isMissingRoute
            ? 'Platform settings are not enabled on this backend yet. Add GET/PUT /api/v1/settings/platform to manage commission, KYC and payout rules here.'
            : apiErrorMessage(e, fallback: 'Could not load platform settings.');
      });
    }
  }

  Future<void> _savePlatform() async {
    final m = Toast.of(context);
    setState(() => _savingPlatform = true);
    try {
      final d = await _repo.savePlatformSettings(_platformBody);
      if (!mounted) return;
      setState(() => _applyPlatform(d.isEmpty ? _platformBody : d));
      Toast.ok(m, 'Platform settings saved');
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not save platform settings.'));
    } finally {
      if (mounted) setState(() => _savingPlatform = false);
    }
  }

  Future<void> _loadTeam() async {
    setState(() {
      _teamLoading = true;
      _teamUnavailable = null;
    });
    try {
      final a = await _repo.admins();
      if (!mounted) return;
      setState(() {
        _admins = a;
        _teamLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _teamLoading = false;
        _teamUnavailable = e is ApiException && e.isMissingRoute
            ? 'Admin team management is not enabled on this backend yet (GET /api/v1/admins, POST /api/v1/admins/invite).'
            : apiErrorMessage(e, fallback: 'Could not load the admin team.');
      });
    }
  }

  Future<void> _invite() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final city = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite an admin'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LabeledField(label: 'Full name', child: TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words)),
            LabeledField(label: 'Email', child: TextField(controller: email, keyboardType: TextInputType.emailAddress)),
            LabeledField(label: 'City scope (optional)', hint: 'Blank = all cities', child: TextField(controller: city, textCapitalization: TextCapitalization.words)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send invite')),
        ],
      ),
    );
    final n = name.text.trim(), e = email.text.trim().toLowerCase(), c = city.text.trim();
    name.dispose();
    email.dispose();
    city.dispose();
    if (ok != true || !mounted) return;
    final m = Toast.of(context);
    if (n.length < 2 || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(e)) {
      Toast.error(m, 'Enter a name and a valid email.');
      return;
    }
    try {
      await _repo.inviteAdmin(email: e, name: n, city: c);
      Toast.ok(m, 'Invitation sent to $e');
      _loadTeam();
    } catch (err) {
      Toast.error(m, apiErrorMessage(err, fallback: 'Could not send the invitation.'));
    }
  }

  Future<void> _saveLinks() async {
    await AppLinks.save(vendor: _vendorUrl.text, user: _userUrl.text);
    _vendorUrl.text = AppLinks.vendorApp.value;
    _userUrl.text = AppLinks.userApp.value;
    if (mounted) Toast.ok(Toast.of(context), 'App links saved on this device');
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      onRefresh: () async => Future.wait([_loadPlatform(), _loadTeam()]),
      children: [
        const PageHeader(title: 'Settings', subtitle: 'Platform rules, admin team, links and your account'),
        const SizedBox(height: 20),
        ResponsiveLayout(
          mobile: (_) => Column(children: [
            _platformCard(),
            const SizedBox(height: 16),
            _teamCard(),
            const SizedBox(height: 16),
            _linksCard(),
            const SizedBox(height: 16),
            _accountCard(),
          ]),
          desktop: (_) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(children: [_platformCard(), const SizedBox(height: 16), _linksCard()])),
            const SizedBox(width: 16),
            Expanded(child: Column(children: [_teamCard(), const SizedBox(height: 16), _accountCard()])),
          ]),
        ),
      ],
    );
  }

  Widget _platformCard() {
    final disabled = _platformUnavailable != null || _platformLoading;
    return SectionCard(
      title: 'Platform settings',
      actions: [
        if (_platformUnavailable == null && !_platformLoading)
          ElevatedButton(
            onPressed: !_dirty || _savingPlatform ? null : _savePlatform,
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 38)),
            child: _savingPlatform ? const ButtonSpinner() : const Text('Save'),
          ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_platformLoading) const LinearProgressIndicator(),
        if (_platformUnavailable != null) ...[
          InlineNotice(
            message: _platformUnavailable!,
            icon: Icons.info_outline,
            color: AppColors.warning,
            action: TextButton(onPressed: _loadPlatform, child: const Text('Retry')),
          ),
          const SizedBox(height: 12),
        ],
        Opacity(
          opacity: disabled ? .5 : 1,
          child: IgnorePointer(
            ignoring: disabled,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Platform commission: ${_commission.round()}%', style: AppType.body(size: 13.5, weight: FontWeight.w600)),
              Slider(value: _commission, min: 0, max: 30, divisions: 30, label: '${_commission.round()}%', onChanged: (v) => setState(() => _commission = v)),
              const Divider(height: 20),
              _toggle('Auto-approve KYC', 'Skip manual review when documents verify automatically', _autoApproveKyc, (v) => setState(() => _autoApproveKyc = v)),
              _toggle('Email alerts', 'Email admins about new vendors, disputes and receipts', _emailAlerts, (v) => setState(() => _emailAlerts = v)),
              _toggle('Hold payouts 48h', 'Delay vendor payouts for 48 hours after a booking completes', _payoutHold, (v) => setState(() => _payoutHold = v)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => context.go('/subscriptions'),
          icon: const Icon(Icons.qr_code_2, size: 18),
          label: const Text('UPI payment details → Subscriptions'),
        ),
      ]),
    );
  }

  Widget _toggle(String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppType.body(size: 13.5, weight: FontWeight.w600)),
            Text(sub, style: AppType.body(size: 12, color: AppColors.textMuted)),
          ]),
        ),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }

  Widget _teamCard() {
    return SectionCard(
      title: 'Admin team',
      actions: [if (_teamUnavailable == null) TextButton.icon(onPressed: _invite, icon: const Icon(Icons.person_add_alt, size: 16), label: const Text('Invite'))],
      child: _teamLoading
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : _teamUnavailable != null
              ? InlineNotice(message: _teamUnavailable!, color: AppColors.warning, action: TextButton(onPressed: _loadTeam, child: const Text('Retry')))
              : _admins.isEmpty
                  ? const EmptyView(icon: Icons.admin_panel_settings_outlined, message: 'No other admins yet')
                  : Column(children: [
                      for (final a in _admins)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            InitialsAvatar(name: '${a['name'] ?? a['email'] ?? '?'}', size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${a['name'] ?? a['email'] ?? ''}', style: AppType.body(size: 13.5, weight: FontWeight.w600)),
                                Text('${a['email'] ?? ''}', style: AppType.body(size: 12, color: AppColors.textMuted)),
                              ]),
                            ),
                            StatusChip(
                              label: '${a['city'] ?? ''}'.isEmpty ? (a['status'] == 'invited' ? 'Invited' : 'All cities') : '${a['city']}',
                              color: a['status'] == 'invited' ? AppColors.warning : AppColors.info,
                            ),
                          ]),
                        ),
                    ]),
    );
  }

  Widget _linksCard() {
    return SectionCard(
      title: 'App links',
      actions: [TextButton(onPressed: _saveLinks, child: const Text('Save'))],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Used in vendor invitations and “view on marketplace” links. Saved on this device.',
            style: AppType.body(size: 12, color: AppColors.textMuted, height: 1.45)),
        const SizedBox(height: 12),
        LabeledField(label: 'Vendor console URL', child: TextField(controller: _vendorUrl, decoration: const InputDecoration(hintText: 'https://vendor.aonego9.com'))),
        LabeledField(label: 'Marketplace (user app) URL', child: TextField(controller: _userUrl, decoration: const InputDecoration(hintText: 'https://aonego9.com'))),
      ]),
    );
  }

  Widget _accountCard() {
    return SectionCard(
      title: 'Your account',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InitialsAvatar(name: _email.isEmpty ? 'Admin' : _email.split('@').first, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_email.isEmpty ? 'Admin' : _email, style: AppType.body(size: 14, weight: FontWeight.w700)),
              Text('Scope: ${_city.isEmpty ? 'All cities' : _city}', style: AppType.body(size: 12, color: AppColors.textMuted)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Text('Appearance', style: AppType.body(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        ValueListenableBuilder<String>(
          valueListenable: ThemeModeStore.mode,
          builder: (_, mode, __) => SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'system', icon: const Icon(Icons.brightness_auto_rounded, size: 18), label: Text(Responsive.isMobile(context) ? 'Auto' : 'Match device')),
              const ButtonSegment(value: 'light', icon: Icon(Icons.light_mode_rounded, size: 18), label: Text('Light')),
              const ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode_rounded, size: 18), label: Text('Dark')),
            ],
            selected: {mode},
            onSelectionChanged: (s) => ThemeModeStore.set(s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? AppColors.gold.withValues(alpha: .16) : Colors.transparent),
              foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? AppColors.gold : AppColors.textSecondary),
              side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => signOutWithConfirm(context),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Sign out'),
        ),
      ]),
    );
  }
}
