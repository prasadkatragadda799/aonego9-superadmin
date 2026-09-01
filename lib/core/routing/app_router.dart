import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
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

/// Central route table. Every authenticated page is wrapped in [AppShell]
/// via a ShellRoute so the sidebar/rail/drawer persists across navigation.
final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final loggedIn = await ApiClient.isLoggedIn();
    final loggingIn = state.matchedLocation == '/login';
    if (!loggedIn && !loggingIn) return '/login';
    if (loggedIn && state.matchedLocation == '/') return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/', redirect: (_, __) => '/dashboard'),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) => AppShell(currentRoute: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
        GoRoute(path: '/vendors', builder: (_, __) => const VendorsScreen()),
        GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
        GoRoute(path: '/bookings', builder: (_, __) => const BookingsScreen()),
        GoRoute(path: '/payments', builder: (_, __) => const PaymentsScreen()),
        GoRoute(path: '/subscriptions', builder: (_, __) => const SubscriptionsScreen()),
        GoRoute(path: '/reviews', builder: (_, __) => const ReviewsScreen()),
        GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
        GoRoute(path: '/cms', builder: (_, __) => const CmsScreen()),
        GoRoute(path: '/newsletter', builder: (_, __) => const NewsletterAdminScreen()),
        GoRoute(path: '/events', builder: (_, __) => const EventsScreen()),
        GoRoute(path: '/sessions', builder: (_, __) => const SessionsAdminScreen()),
        GoRoute(path: '/ads', builder: (_, __) => const AdsScreen()),
        GoRoute(path: '/directory', builder: (_, __) => const DirectoryScreen()),
        GoRoute(path: '/leads', builder: (_, __) => const LeadsScreen()),
        GoRoute(path: '/social', builder: (_, __) => const SocialScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
  errorBuilder: (_, __) => const Scaffold(body: Center(child: Text('Page not found'))),
);
