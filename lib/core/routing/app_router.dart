import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/typography.dart';
import '../widgets/app_shell.dart';
import '../widgets/brand.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/vendors/vendors_screen.dart';
import '../../features/users/users_screen.dart';
import '../../features/bookings/bookings_screen.dart';
import '../../features/payments/payments_screen.dart';
import '../../features/subscriptions/subscriptions_screen.dart';
import '../../features/reviews/reviews_screen.dart';
import '../../features/support/support_screen.dart';
import '../../features/cms/cms_screen.dart';
import '../../features/cms/newsletter_admin_screen.dart';
import '../../features/events/events_screen.dart';
import '../../features/sessions/sessions_admin_screen.dart';
import '../../features/ads/ads_screen.dart';
import '../../features/directory/directory_screen.dart';
import '../../features/leads/leads_screen.dart';
import '../../features/social/social_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../data/api/api_client.dart';

Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: c),
    );

GoRoute _page(String path, Widget Function(GoRouterState s) build) =>
    GoRoute(path: path, pageBuilder: (_, s) => _fade(s, build(s)));

String _q(GoRouterState s) => s.uri.queryParameters['q'] ?? '';
String _status(GoRouterState s) => s.uri.queryParameters['status'] ?? '';

/// Central route table. Every authenticated page is wrapped in [AppShell]
/// via a ShellRoute so the sidebar/rail/drawer persists across navigation.
final appRouter = GoRouter(
  initialLocation: '/dashboard',
  // An expired session goes to sign-in immediately, not on the next tap.
  refreshListenable: ApiClient.sessionChanges,
  redirect: (context, state) async {
    final loggedIn = await ApiClient.isLoggedIn();
    final path = state.uri.path;
    final onLogin = path == '/login';
    if (!loggedIn) {
      if (onLogin) return null;
      final from = state.uri.toString();
      return from == '/' || from.isEmpty ? '/login' : '/login?from=${Uri.encodeComponent(from)}';
    }
    if (onLogin || path == '/' || path.isEmpty) {
      final from = state.uri.queryParameters['from'];
      return from != null && from.startsWith('/') && !from.startsWith('/login') ? from : '/dashboard';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', redirect: (_, __) => '/dashboard'),
    GoRoute(path: '/login', pageBuilder: (_, s) => _fade(s, const LoginScreen())),
    ShellRoute(
      builder: (context, state, child) => AppShell(currentRoute: state.uri.path, child: child),
      routes: [
        _page('/dashboard', (_) => const DashboardScreen()),
        _page('/analytics', (_) => const AnalyticsScreen()),
        _page('/vendors', (s) => VendorsScreen(initialQuery: _q(s), initialStatus: _status(s))),
        _page('/users', (s) => UsersScreen(initialQuery: _q(s))),
        _page('/bookings', (s) => BookingsScreen(initialQuery: _q(s), initialStatus: _status(s))),
        _page('/payments', (_) => const PaymentsScreen()),
        _page('/subscriptions', (_) => const SubscriptionsScreen()),
        _page('/reviews', (_) => const ReviewsScreen()),
        _page('/support', (_) => const SupportScreen()),
        _page('/cms', (_) => const CmsScreen()),
        _page('/newsletter', (_) => const NewsletterAdminScreen()),
        _page('/events', (_) => const EventsScreen()),
        _page('/sessions', (_) => const SessionsAdminScreen()),
        _page('/ads', (_) => const AdsScreen()),
        _page('/directory', (_) => const DirectoryScreen()),
        _page('/leads', (s) => LeadsScreen(initialQuery: _q(s))),
        _page('/social', (_) => const SocialScreen()),
        _page('/settings', (_) => const SettingsScreen()),
      ],
    ),
  ],
  errorBuilder: (context, state) => _NotFound(path: state.uri.toString()),
);

class _NotFound extends StatelessWidget {
  final String path;
  const _NotFound({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const BrandLogo(size: 26),
            const SizedBox(height: 28),
            Text('Page not found', style: AppType.display(size: 24)),
            const SizedBox(height: 8),
            Text('There is nothing at $path.', textAlign: TextAlign.center, style: AppType.body(size: 13.5, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.go('/dashboard'),
              icon: const Icon(Icons.dashboard_outlined, size: 18),
              label: const Text('Back to dashboard'),
            ),
          ]),
        ),
      ),
    );
  }
}
