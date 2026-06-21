import '../models/models.dart';
import '../mock/mock_data.dart';

/// ───────────────────────────────────────────────────────────────
/// REPOSITORY LAYER — the single seam between UI and backend.
///
/// BACKEND DEV: every method below currently returns mock data.
/// Replace the bodies with real HTTP calls (e.g. using `dio` or
/// `http`) and the entire UI keeps working unchanged. Suggested
/// REST endpoints are noted above each method.
/// ───────────────────────────────────────────────────────────────

class AdminRepository {
  // Simulated network latency so loading states are visible in the demo.
  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 350));

  // GET /api/admin/dashboard/summary
  Future<Map<String, num>> dashboardSummary() async {
    await _delay();
    return {
      'totalVendors': MockData.vendors.length,
      'pendingVendors': MockData.vendors.where((v) => v.status == ApprovalStatus.pending).length,
      'totalUsers': MockData.users.length,
      'activeBookings': MockData.bookings.where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.inProgress).length,
      'revenue': MockData.payments.where((p) => p.type == 'booking').fold<double>(0, (s, p) => s + p.amount),
      'disputes': MockData.bookings.where((b) => b.status == BookingStatus.disputed).length,
    };
  }

  // GET /api/admin/vendors
  Future<List<Vendor>> vendors() async {
    await _delay();
    return List.of(MockData.vendors);
  }

  // PATCH /api/admin/vendors/{id}  { status }
  Future<void> setVendorStatus(String id, ApprovalStatus status) async {
    await _delay();
    final i = MockData.vendors.indexWhere((v) => v.id == id);
    if (i != -1) MockData.vendors[i] = MockData.vendors[i].copyWith(status: status);
  }

  // GET /api/admin/users
  Future<List<AppUser>> users() async {
    await _delay();
    return List.of(MockData.users);
  }

  // PATCH /api/admin/users/{id} { status }
  Future<void> setUserStatus(String id, ApprovalStatus status) async {
    await _delay();
    final i = MockData.users.indexWhere((u) => u.id == id);
    if (i != -1) MockData.users[i] = MockData.users[i].copyWith(status: status);
  }

  // GET /api/admin/bookings
  Future<List<Booking>> bookings() async {
    await _delay();
    return List.of(MockData.bookings);
  }

  // GET /api/admin/payments
  Future<List<PaymentTxn>> payments() async {
    await _delay();
    return List.of(MockData.payments);
  }

  // GET /api/admin/reviews
  Future<List<Review>> reviews() async {
    await _delay();
    return List.of(MockData.reviews);
  }

  // GET /api/admin/support/tickets
  Future<List<SupportTicket>> tickets() async {
    await _delay();
    return List.of(MockData.tickets);
  }

  // GET /api/admin/cms/banners
  Future<List<CmsBanner>> banners() async {
    await _delay();
    return List.of(MockData.banners);
  }

  // GET /api/admin/categories
  Future<List<Category>> categories() async {
    await _delay();
    return List.of(MockData.categories);
  }

  // GET /api/admin/events
  Future<List<PlatformEvent>> events() async {
    await _delay();
    return List.of(MockData.events);
  }

  // PATCH /api/admin/events/{id} { status }
  Future<void> setEventStatus(String id, EventStatus status) async {
    await _delay();
    final i = MockData.events.indexWhere((e) => e.id == id);
    if (i != -1) MockData.events[i] = MockData.events[i].copyWith(status: status);
  }

  // PATCH /api/admin/events/{id} { onPoster } — toggles the live scroll poster
  Future<void> toggleEventPoster(String id, bool onPoster) async {
    await _delay();
    final i = MockData.events.indexWhere((e) => e.id == id);
    if (i != -1) MockData.events[i] = MockData.events[i].copyWith(onPoster: onPoster);
  }

  // GET /api/admin/analytics/*
  Future<Map<String, List<KpiPoint>>> analytics() async {
    await _delay();
    return {
      'revenue': MockData.revenueTrend,
      'signups': MockData.signupsTrend,
      'categoryShare': MockData.categoryShare,
    };
  }
}
