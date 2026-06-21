import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/typography.dart';
import '../responsive/responsive.dart';
import '../routing/nav_items.dart';
import '../widgets/common.dart';

/// Adaptive shell that wraps every page.
/// - Desktop  : fixed expanded sidebar
/// - Tablet   : compact icon rail
/// - Mobile   : top app bar + slide-in drawer
class AppShell extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  const AppShell({super.key, required this.child, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: (c) => _MobileScaffold(currentRoute: currentRoute, child: child),
      tablet: (c) => _WideScaffold(currentRoute: currentRoute, expanded: false, child: child),
      desktop: (c) => _WideScaffold(currentRoute: currentRoute, expanded: true, child: child),
    );
  }
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
                const _TopBar(),
                Expanded(child: AmbientBackground(child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileScaffold extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  const _MobileScaffold({required this.child, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: AppColors.sidebar,
        child: SafeArea(child: _Sidebar(currentRoute: currentRoute, expanded: true, inDrawer: true)),
      ),
      appBar: AppBar(
        title: const _BrandMark(compact: true),
        actions: const [
          Icon(Icons.notifications_none, size: 22),
          SizedBox(width: 14),
          Padding(padding: EdgeInsets.only(right: 14), child: InitialsAvatar(name: 'Super Admin', size: 30)),
        ],
      ),
      body: AmbientBackground(child: child),
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
    final width = expanded ? 254.0 : 76.0;
    String? lastSection;
    return Container(
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF13151B), AppColors.sidebar],
        ),
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: expanded ? 20 : 0, vertical: 22),
            child: Align(
              alignment: expanded ? Alignment.centerLeft : Alignment.center,
              child: _BrandMark(compact: !expanded),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                for (final item in adminNav) ...[
                  if (expanded && item.section != null && item.section != lastSection)
                    _sectionLabel(item.section!, setLast: () => lastSection = item.section),
                  _NavTile(
                    item: item,
                    expanded: expanded,
                    selected: currentRoute == item.route,
                    onTap: () {
                      if (inDrawer) Navigator.of(context).pop();
                      context.go(item.route);
                    },
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          _NavTile(
            item: const NavItem('Logout', Icons.logout, '/login'),
            expanded: expanded,
            selected: false,
            onTap: () => context.go('/login'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {required VoidCallback setLast}) {
    setLast();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 20, 9),
      child: Text(text.toUpperCase(), style: AppType.eyebrow(color: AppColors.textMuted, size: 10)),
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.expanded, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : AppColors.textSecondary;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 10, vertical: 2),
      child: HoverFx(
        onTap: onTap,
        builder: (h) => AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.12)
                : (h ? AppColors.surface : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.gold.withValues(alpha: 0.30) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              // Active accent bar.
              if (expanded)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              if (expanded) const SizedBox(width: 11),
              Icon(item.icon, size: 20, color: selected ? AppColors.gold : (h ? AppColors.textPrimary : color)),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.label,
                      style: AppType.body(
                          size: 13.5,
                          weight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? AppColors.textPrimary : (h ? AppColors.textPrimary : AppColors.textSecondary))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Spacer(),
          Container(
            width: 300,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text('Search vendors, users, bookings…',
                    style: AppType.body(size: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _iconBtn(Icons.notifications_none, badge: true),
          const SizedBox(width: 8),
          _iconBtn(Icons.help_outline),
          const SizedBox(width: 16),
          const InitialsAvatar(name: 'Super Admin', size: 36),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Super Admin', style: AppType.body(weight: FontWeight.w600, size: 13)),
              Text('admin@aonego9.com', style: AppType.body(color: AppColors.textMuted, size: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, {bool badge = false}) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 19, color: AppColors.textSecondary),
        ),
        if (badge)
          const Positioned(
            right: 9, top: 9,
            child: CircleAvatar(radius: 4, backgroundColor: AppColors.gold),
          ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  final bool compact;
  const _BrandMark({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.goldLight, AppColors.goldDark]),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Text('A9', style: AppType.display(color: const Color(0xFF1A1407), weight: FontWeight.w700, size: 15)),
    );
    if (compact) return logo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 11),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: AppType.display(size: 18, weight: FontWeight.w600),
                children: [
                  const TextSpan(text: 'AOne'),
                  TextSpan(text: 'Go9', style: AppType.display(size: 18, weight: FontWeight.w600, color: AppColors.gold)),
                ],
              ),
            ),
            Text('SUPER ADMIN', style: AppType.eyebrow(color: AppColors.gold.withValues(alpha: 0.9), size: 9)),
          ],
        ),
      ],
    );
  }
}
