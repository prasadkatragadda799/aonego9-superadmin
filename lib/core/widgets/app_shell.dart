import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/typography.dart';
import '../responsive/responsive.dart';
import '../routing/nav_items.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/admin_repository.dart';

/// One item in the "needs attention" queue.
class AttentionItem {
  final String label;
  final int count;
  final IconData icon;
  final String route;
  final Color Function() color;
  const AttentionItem(this.label, this.count, this.icon, this.route, this.color);
}

/// Live work queue for the bell — everything waiting on an admin decision.
/// Refreshed on navigation (throttled) and every 90 seconds.
class AdminBadges {
  AdminBadges._();
  static final ValueNotifier<List<AttentionItem>> items = ValueNotifier(const []);
  static Timer? _timer;
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  static int get total => items.value.fold(0, (s, i) => s + i.count);

  static Future<void> refresh({bool force = false}) async {
    final now = DateTime.now();
    if (!force && now.difference(_last) < const Duration(seconds: 30)) return;
    _last = now;
    final repo = AdminRepository();
    Future<int> safe(Future<int> f) => f.catchError((_) => 0);
    final results = await Future.wait<Object?>([
      repo.dashboardSummary().then<Map<String, num>?>((v) => v).catchError((_) => null),
      safe(repo.subscriptionRequests(status: 'pending').then((l) => l.length)),
      safe(repo.advanceRequests(status: 'pending').then((l) => l.length)),
      safe(repo.leads(status: 'new').then((l) => l.where((x) => x.status == 'new').length)),
      safe(repo.tickets(status: 'open').then((l) => l.where((x) => x.status == 'open').length)),
    ]);
    final s = results[0] as Map<String, num>?;
    items.value = [
      AttentionItem('Vendors awaiting approval', (s?['pendingVendors'] ?? 0).toInt(), Icons.storefront_outlined, '/vendors?status=pending',
          () => AppColors.warning),
      AttentionItem('Subscription receipts to review', results[1] as int, Icons.receipt_long_outlined, '/subscriptions', () => AppColors.gold),
      AttentionItem('Advance payments to verify', results[2] as int, Icons.account_balance_wallet_outlined, '/bookings', () => AppColors.info),
      AttentionItem('Open disputes', (s?['disputes'] ?? 0).toInt(), Icons.gavel_outlined, '/bookings?status=disputed', () => AppColors.danger),
      AttentionItem('New leads & vendor requests', results[3] as int, Icons.inbox_outlined, '/leads', () => AppColors.success),
      AttentionItem('Open support tickets', results[4] as int, Icons.support_agent_outlined, '/support', () => AppColors.danger),
    ];
  }

  static void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 90), (_) => refresh(force: true));
    refresh();
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    items.value = const [];
  }
}

/// Adaptive shell that wraps every page.
/// - Desktop : expanded sidebar + top bar
/// - Tablet  : icon rail + top bar
/// - Mobile  : app bar + drawer + bottom bar (primary areas + More)
class AppShell extends StatefulWidget {
  final Widget child;
  final String currentRoute;
  const AppShell({super.key, required this.child, required this.currentRoute});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    AdminBadges.start();
  }

  @override
  void didUpdateWidget(covariant AppShell old) {
    super.didUpdateWidget(old);
    if (old.currentRoute != widget.currentRoute) AdminBadges.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => openCommandPalette(context),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => openCommandPalette(context),
      },
      child: Focus(
        autofocus: true,
        child: ResponsiveLayout(
          mobile: (c) => _MobileScaffold(currentRoute: widget.currentRoute, child: widget.child),
          tablet: (c) => _WideScaffold(currentRoute: widget.currentRoute, expanded: false, child: widget.child),
          desktop: (c) => _WideScaffold(currentRoute: widget.currentRoute, expanded: true, child: widget.child),
        ),
      ),
    );
  }
}

String _titleFor(String route) {
  for (final n in adminNav) {
    if (n.route == route) return n.label;
  }
  return 'Super Admin';
}

class _WideScaffold extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  final bool expanded;
  const _WideScaffold({required this.child, required this.currentRoute, required this.expanded});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(currentRoute: currentRoute, expanded: expanded),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: _titleFor(currentRoute)),
                Expanded(child: AmbientBackground(child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _bottomItems = ['/dashboard', '/vendors', '/bookings', '/leads'];

class _MobileScaffold extends StatefulWidget {
  final Widget child;
  final String currentRoute;
  const _MobileScaffold({required this.child, required this.currentRoute});

  @override
  State<_MobileScaffold> createState() => _MobileScaffoldState();
}

class _MobileScaffoldState extends State<_MobileScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final idx = _bottomItems.indexOf(widget.currentRoute);
    final selected = idx < 0 ? _bottomItems.length : idx;
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        width: 290,
        child: SafeArea(child: _Sidebar(currentRoute: widget.currentRoute, expanded: true, inDrawer: true)),
      ),
      appBar: AppBar(
        titleSpacing: 4,
        leading: IconButton(
          tooltip: 'Menu',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(children: [
          const BrandMonogram(size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_titleFor(widget.currentRoute),
                overflow: TextOverflow.ellipsis, style: AppType.display(size: 16.5, weight: FontWeight.w600)),
          ),
        ]),
        actions: [
          IconButton(tooltip: 'Search', icon: const Icon(Icons.search, size: 22), onPressed: () => openCommandPalette(context)),
          const _AttentionButton(),
          const Padding(padding: EdgeInsets.only(right: 8), child: _AccountMenu(compact: true)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: AmbientBackground(child: widget.child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (i == _bottomItems.length) {
            _scaffoldKey.currentState?.openDrawer();
          } else {
            context.go(_bottomItems[i]);
          }
        },
        destinations: [
          for (final r in _bottomItems)
            () {
              final n = adminNav.firstWhere((x) => x.route == r);
              return NavigationDestination(icon: Icon(n.icon), label: n.shortLabel);
            }(),
          const NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'More'),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String currentRoute;
  final bool expanded;
  final bool inDrawer;
  const _Sidebar({required this.currentRoute, required this.expanded, this.inDrawer = false});

  @override
  Widget build(BuildContext context) {
    final width = inDrawer ? double.infinity : (expanded ? 256.0 : 78.0);
    String? lastSection;
    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.sidebarLift, AppColors.sidebar],
        ),
        border: inDrawer ? null : Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: expanded ? 20 : 0, vertical: 20),
            child: Align(
              alignment: expanded ? Alignment.centerLeft : Alignment.center,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (inDrawer) Navigator.of(context).pop();
                  context.go('/dashboard');
                },
                child: expanded
                    ? const ConsoleLockup(label: 'Super Admin', size: 21)
                    : const Tooltip(message: 'AOneGo9 Super Admin', child: BrandMonogram(size: 38)),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<List<AttentionItem>>(
              valueListenable: AdminBadges.items,
              builder: (context, items, _) {
                int countFor(String route) =>
                    items.where((i) => i.route.split('?').first == route).fold(0, (s, i) => s + i.count);
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  children: [
                    for (final item in adminNav) ...[
                      if (expanded && item.section != null && item.section != lastSection)
                        _sectionLabel(item.section!, setLast: () => lastSection = item.section),
                      _NavTile(
                        item: item,
                        expanded: expanded,
                        selected: currentRoute == item.route,
                        count: countFor(item.route),
                        onTap: () {
                          if (inDrawer) Navigator.of(context).pop();
                          context.go(item.route);
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 6),
          _NavTile(
            item: const NavItem('Sign out', Icons.logout, '/login'),
            expanded: expanded,
            selected: false,
            danger: true,
            onTap: () async {
              if (inDrawer) Navigator.of(context).pop();
              await signOutWithConfirm(context);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {required VoidCallback setLast}) {
    setLast();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 20, 8),
      child: Text(text.toUpperCase(), style: AppType.eyebrow(color: AppColors.textMuted, size: 10)),
    );
  }
}

Future<void> signOutWithConfirm(BuildContext context) async {
  final ok = await confirmAction(
    context,
    title: 'Sign out?',
    message: 'You will need your admin email and password to sign back in.',
    confirmLabel: 'Sign out',
  );
  if (!ok) return;
  AdminBadges.stop();
  await AdminRepository().logout();
  if (context.mounted) context.go('/login');
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;
  final int count;
  final bool danger;
  const _NavTile({
    required this.item,
    required this.expanded,
    required this.selected,
    required this.onTap,
    this.count = 0,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.danger : AppColors.gold;
    final tile = Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 10, vertical: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: HoverFx(
          onTap: onTap,
          builder: (h) => AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.12) : (h ? AppColors.surface : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? accent.withValues(alpha: 0.30) : Colors.transparent),
            ),
            child: Row(
              mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                if (expanded)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(color: selected ? accent : Colors.transparent, borderRadius: BorderRadius.circular(3)),
                  ),
                if (expanded) const SizedBox(width: 11),
                Badge(
                  isLabelVisible: !expanded && count > 0,
                  backgroundColor: AppColors.gold,
                  smallSize: 8,
                  child: Icon(item.icon,
                      size: 20,
                      color: danger
                          ? AppColors.danger
                          : selected
                              ? accent
                              : (h ? AppColors.textPrimary : AppColors.textSecondary)),
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.label,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(
                            size: 13.5,
                            weight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: danger
                                ? AppColors.danger
                                : (selected || h ? AppColors.textPrimary : AppColors.textSecondary))),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                      child: Text(count > 99 ? '99+' : '$count',
                          style: AppType.mono(size: 10.5, weight: FontWeight.w700, color: AppColors.onAccent(AppColors.gold))),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return expanded ? tile : Tooltip(message: item.label, preferBelow: false, child: tile);
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    final desktop = Responsive.isDesktop(context);
    return Container(
      height: 64,
      decoration: BoxDecoration(color: AppColors.bg, border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: AppType.display(size: 17, weight: FontWeight.w600))),
          const SizedBox(width: 12),
          if (desktop)
            HoverFx(
              onTap: () => openCommandPalette(context),
              builder: (h) => AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 320,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: h ? AppColors.borderHi : AppColors.border),
                ),
                child: Row(children: [
                  Icon(Icons.search, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Search vendors, users, bookings…',
                        overflow: TextOverflow.ellipsis, style: AppType.body(size: 13, color: AppColors.textMuted)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('Ctrl K', style: AppType.mono(size: 10.5)),
                  ),
                ]),
              ),
            )
          else
            IconButton(tooltip: 'Search (Ctrl K)', icon: const Icon(Icons.search, size: 21), onPressed: () => openCommandPalette(context)),
          const SizedBox(width: 10),
          const ThemeCycleButton(),
          const _AttentionButton(),
          const SizedBox(width: 8),
          _AccountMenu(compact: !desktop),
        ],
      ),
    );
  }
}

/// The bell: a live "needs attention" queue rather than a decorative dot.
class _AttentionButton extends StatelessWidget {
  const _AttentionButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AttentionItem>>(
      valueListenable: AdminBadges.items,
      builder: (context, items, _) {
        final total = items.fold<int>(0, (s, i) => s + i.count);
        return PopupMenuButton<String>(
          tooltip: total == 0 ? 'Nothing needs attention' : '$total items need attention',
          offset: const Offset(0, 48),
          constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
          onOpened: () => AdminBadges.refresh(force: true),
          onSelected: (r) => context.go(r),
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Text('NEEDS ATTENTION', style: AppType.eyebrow(size: 10, color: AppColors.textMuted)),
            ),
            if (items.isEmpty)
              PopupMenuItem(enabled: false, child: Text('Loading…', style: AppType.body(size: 13, color: AppColors.textMuted)))
            else if (total == 0)
              PopupMenuItem(
                enabled: false,
                child: Row(children: [
                  Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                  const SizedBox(width: 10),
                  Text('All clear — nothing pending', style: AppType.body(size: 13)),
                ]),
              )
            else
              for (final i in items.where((i) => i.count > 0))
                PopupMenuItem(
                  value: i.route,
                  child: Row(children: [
                    Icon(i.icon, size: 18, color: i.color()),
                    const SizedBox(width: 12),
                    Expanded(child: Text(i.label, style: AppType.body(size: 13))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: i.color().withValues(alpha: .16), borderRadius: BorderRadius.circular(10)),
                      child: Text('${i.count}', style: AppType.mono(size: 11, weight: FontWeight.w700, color: i.color())),
                    ),
                  ]),
                ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Badge(
              isLabelVisible: total > 0,
              backgroundColor: AppColors.gold,
              textColor: AppColors.onAccent(AppColors.gold),
              label: Text(total > 99 ? '99+' : '$total'),
              child: Icon(Icons.notifications_none, size: 22, color: AppColors.textSecondary),
            ),
          ),
        );
      },
    );
  }
}

Future<(String?, String)> _identity() async => (await ApiClient.getEmail(), await ApiClient.getCity());

class _AccountMenu extends StatelessWidget {
  final bool compact;
  const _AccountMenu({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String?, String)>(
      future: _identity(),
      builder: (context, snap) {
        final email = snap.data?.$1?.trim() ?? '';
        final city = snap.data?.$2 ?? '';
        final name = email.contains('@') ? email.split('@').first : 'Admin';
        final scope = city.isEmpty ? 'All cities' : city;
        final avatar = InitialsAvatar(name: name, size: compact ? 32 : 36);
        return PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, 48),
          onSelected: (v) async {
            switch (v) {
              case 'settings':
                context.go('/settings');
              case 'theme':
                showThemePicker(context);
              case 'logout':
                await signOutWithConfirm(context);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: AppType.body(size: 13.5, weight: FontWeight.w700)),
                if (email.isNotEmpty) Text(email, style: AppType.body(size: 11.5, color: AppColors.textMuted)),
                Text('Scope: $scope', style: AppType.body(size: 11.5, color: AppColors.textMuted)),
              ]),
            ),
            const PopupMenuDivider(),
            _item('settings', Icons.settings_outlined, 'Settings'),
            _item('theme', Icons.contrast, 'Appearance'),
            const PopupMenuDivider(),
            _item('logout', Icons.logout, 'Sign out', color: AppColors.danger),
          ],
          child: compact
              ? Padding(padding: const EdgeInsets.all(4), child: avatar)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  avatar,
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(name, overflow: TextOverflow.ellipsis, style: AppType.body(weight: FontWeight.w600, size: 13)),
                      Text('Super admin · $scope',
                          overflow: TextOverflow.ellipsis, style: AppType.body(color: AppColors.textMuted, size: 11)),
                    ]),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
                ]),
        );
      },
    );
  }

  PopupMenuItem<String> _item(String v, IconData icon, String label, {Color? color}) => PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: AppType.body(size: 13.5, color: color ?? AppColors.textPrimary)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// COMMAND PALETTE
// ─────────────────────────────────────────────────────────────

Future<void> openCommandPalette(BuildContext context) async {
  final target = await showDialog<String>(context: context, builder: (_) => const _CommandPalette());
  if (target != null && context.mounted) context.go(target);
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette();
  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _q = TextEditingController();
  int _highlight = 0;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<(IconData, String, String, String)> get _results {
    final q = _q.text.trim();
    final lq = q.toLowerCase();
    final out = <(IconData, String, String, String)>[];
    if (q.isNotEmpty) {
      final enc = Uri.encodeQueryComponent(q);
      out.addAll([
        (Icons.storefront_outlined, 'Search vendors for “$q”', 'Name, company, city or email', '/vendors?q=$enc'),
        (Icons.people_outline, 'Search talent & users for “$q”', 'Name or email', '/users?q=$enc'),
        (Icons.event_note_outlined, 'Search bookings for “$q”', 'Service, client, vendor or reference', '/bookings?q=$enc'),
        (Icons.inbox_outlined, 'Search leads for “$q”', 'Name, email, phone or message', '/leads?q=$enc'),
      ]);
    }
    for (final n in adminNav) {
      if (lq.isEmpty || n.label.toLowerCase().contains(lq) || (n.section ?? '').toLowerCase().contains(lq)) {
        out.add((n.icon, n.label, n.section ?? '', n.route));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    if (_highlight >= results.length) _highlight = 0;
    return Dialog(
      alignment: const Alignment(0, -0.55),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 500),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                    setState(() => _highlight = (_highlight + 1).clamp(0, results.length - 1)),
                const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                    setState(() => _highlight = (_highlight - 1).clamp(0, results.length - 1)),
              },
              child: TextField(
                controller: _q,
                autofocus: true,
                onChanged: (_) => setState(() => _highlight = 0),
                onSubmitted: (_) {
                  if (results.isNotEmpty) Navigator.pop(context, results[_highlight].$4);
                },
                decoration: const InputDecoration(hintText: 'Jump to a page, or search vendors, users, bookings…', prefixIcon: Icon(Icons.search)),
              ),
            ),
          ),
          Flexible(
            child: results.isEmpty
                ? const EmptyView(message: 'No matches', icon: Icons.search_off)
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final r = results[i];
                      final hi = i == _highlight;
                      return Material(
                        color: hi ? AppColors.gold.withValues(alpha: .12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          leading: Icon(r.$1, size: 20, color: hi ? AppColors.gold : AppColors.textSecondary),
                          title: Text(r.$2),
                          subtitle: r.$3.isEmpty ? null : Text(r.$3),
                          trailing: hi ? Icon(Icons.keyboard_return, size: 16, color: AppColors.textMuted) : null,
                          onTap: () => Navigator.pop(context, r.$4),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
