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
import '../../features/reviews/reviews_screen.dart';
import '../../features/support/support_screen.dart';
import '../../features/cms/cms_screen.dart';
import '../../features/events/events_screen.dart';
import '../../features/settings/settings_screen.dart';

/// Central route table. Every authenticated page is wrapped in [AppShell]
/// via a ShellRoute so the sidebar/rail/drawer persists across navigation.
final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
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
        GoRoute(path: '/reviews', builder: (_, __) => const ReviewsScreen()),
        GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
        GoRoute(path: '/cms', builder: (_, __) => const CmsScreen()),
        GoRoute(path: '/events', builder: (_, __) => const EventsScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
  errorBuilder: (_, __) => const Scaffold(body: Center(child: Text('Page not found'))),
);
