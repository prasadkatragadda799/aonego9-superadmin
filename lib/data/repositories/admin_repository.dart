import '../models/models.dart';
import '../api/api_client.dart';

// ignore: constant_identifier_names

/// ───────────────────────────────────────────────────────────────
/// ADMIN REPOSITORY — all methods now call the real FastAPI backend.
/// Base URL is configured in api_client.dart (kBaseUrl).
/// ───────────────────────────────────────────────────────────────
class AdminRepository {
  static const String baseUrlHint = kBaseUrl;

  // ── Auth ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await ApiClient.post('/auth/login/admin', {'email': email, 'password': password}, auth: false);
    await ApiClient.saveTokens(data['access_token'], data['refresh_token']);
    return data;
  }

  Future<void> logout() => ApiClient.clearTokens();

  // ── Dashboard ─────────────────────────────────────────────────

  // GET /api/v1/analytics/admin/dashboard
  Future<Map<String, num>> dashboardSummary() async {
    final data = await ApiClient.get('/analytics/admin/dashboard');
    return {
      'totalVendors': data['total_vendors'] as num,
      'pendingVendors': data['pending_approvals'] as num,
      'totalUsers': data['total_users'] as num,
      'activeBookings': data['active_bookings'] as num,
      'revenue': data['total_revenue'] as num,
      'disputes': 0,
    };
  }

  // ── Vendors ───────────────────────────────────────────────────

  // GET /api/v1/vendors/admin
  Future<List<Vendor>> vendors({String? status}) async {
    final q = status != null ? '?status=$status' : '';
    final data = await ApiClient.get('/vendors/admin$q') as Map;
    return (data['items'] as List).map((j) => Vendor.fromJson(j)).toList();
  }

  // PUT /api/v1/vendors/admin/{id}/status  { status }
  Future<void> setVendorStatus(String id, ApprovalStatus status) async {
    await ApiClient.put('/vendors/admin/$id/status', {'status': status.name});
  }

  // PUT /api/v1/vendors/admin/{id}/kyc  { kyc_verified }
  Future<void> setVendorKyc(String id, bool verified) async {
    await ApiClient.put('/vendors/admin/$id/kyc', {'kyc_verified': verified});
  }

  // ── Users ─────────────────────────────────────────────────────

  // GET /api/v1/users
  Future<List<AppUser>> users({String? status}) async {
    final q = status != null ? '?status=$status' : '';
    final data = await ApiClient.get('/users$q') as Map;
    return (data['items'] as List).map((j) => AppUser.fromJson(j)).toList();
  }

  // PUT /api/v1/users/{id}/status  { status }
  Future<void> setUserStatus(String id, ApprovalStatus status) async {
    await ApiClient.put('/users/$id/status', {'status': status.name});
  }

  // PUT /api/v1/users/{id}/verify
  Future<void> verifyUser(String id) async {
    await ApiClient.put('/users/$id/verify', {});
  }

  // ── Bookings ──────────────────────────────────────────────────

  // GET /api/v1/bookings/admin
  Future<List<Booking>> bookings({String? status}) async {
    final q = status != null ? '?status=$status' : '';
    final data = await ApiClient.get('/bookings/admin$q') as Map;
    return (data['items'] as List).map((j) => Booking.fromJson(j)).toList();
  }

  // PUT /api/v1/bookings/{id}/status
  Future<void> setBookingStatus(String id, BookingStatus status) async {
    await ApiClient.put('/bookings/$id/status', {'status': status.name});
  }

  // ── Payments ──────────────────────────────────────────────────

  // GET /api/v1/payments/admin
  Future<List<PaymentTxn>> payments() async {
    final data = await ApiClient.get('/payments/admin') as Map;
    return (data['items'] as List).map((j) => PaymentTxn.fromJson(j)).toList();
  }

  // POST /api/v1/payments/payout
  Future<void> triggerPayout(String vendorId, double amount) async {
    await ApiClient.post('/payments/payout', {'vendor_id': vendorId, 'amount': amount});
  }

  // ── Reviews ───────────────────────────────────────────────────

  // GET /api/v1/reviews/admin
  Future<List<Review>> reviews({bool? flagged}) async {
    final q = flagged != null ? '?flagged=$flagged' : '';
    final data = await ApiClient.get('/reviews/admin$q') as Map;
    return (data['items'] as List).map((j) => _reviewFromJson(j)).toList();
  }

  // PUT /api/v1/reviews/{id}/flag  (toggles)
  Future<void> toggleReviewFlag(String id) async {
    await ApiClient.put('/reviews/$id/flag', {});
  }

  // DELETE /api/v1/reviews/{id}
  Future<void> deleteReview(String id) => ApiClient.delete('/reviews/$id');

  // ── Support tickets ───────────────────────────────────────────

  // GET /api/v1/support/admin
  Future<List<SupportTicket>> tickets({String? status}) async {
    final q = status != null ? '?status=$status' : '';
    final data = await ApiClient.get('/support/admin$q') as Map;
    return (data['items'] as List).map((j) => _ticketFromJson(j)).toList();
  }

  // PUT /api/v1/support/admin/{id}
  Future<void> updateTicket(String id, String status) async {
    await ApiClient.put('/support/admin/$id', {'status': status});
  }

  // ── CMS banners ───────────────────────────────────────────────

  // GET /api/v1/cms/banners
  Future<List<CmsBanner>> banners() async {
    final data = await ApiClient.get('/cms/banners') as List;
    return data.map((j) => CmsBanner(id: j['id'], title: j['title'], placement: j['placement'], active: j['active'])).toList();
  }

  // PUT /api/v1/cms/banners/{id}
  Future<void> updateBanner(String id, Map<String, dynamic> fields) => ApiClient.put('/cms/banners/$id', fields);

  // DELETE /api/v1/cms/banners/{id}
  Future<void> deleteBanner(String id) => ApiClient.delete('/cms/banners/$id');

  // ── CMS categories ────────────────────────────────────────────

  // GET /api/v1/cms/categories
  Future<List<Category>> categories() async {
    final data = await ApiClient.get('/cms/categories') as List;
    return data.map((j) => Category(id: j['id'], name: j['name'], listings: j['listings'], active: j['active'])).toList();
  }

  // PATCH /api/v1/cms/categories/{id}/toggle
  Future<void> toggleCategory(String id) => ApiClient.patch('/cms/categories/$id/toggle');

  // ── Platform events ───────────────────────────────────────────

  // GET /api/v1/events/admin
  Future<List<PlatformEvent>> events() async {
    final data = await ApiClient.get('/events/admin') as Map;
    return (data['items'] as List).map((j) => PlatformEvent.fromJson(j)).toList();
  }

  // PUT /api/v1/events/admin/{id}
  Future<void> setEventStatus(String id, EventStatus status) async {
    await ApiClient.put('/events/admin/$id', {'status': status.name});
  }

  // PATCH /api/v1/events/admin/{id}/poster  { on_poster }
  Future<void> toggleEventPoster(String id, bool onPoster) async {
    await ApiClient.patch('/events/admin/$id/poster', {'on_poster': onPoster});
  }

  // DELETE /api/v1/events/admin/{id}
  Future<void> deleteEvent(String id) => ApiClient.delete('/events/admin/$id');

  // ── Analytics ─────────────────────────────────────────────────

  // GET /api/v1/analytics/admin/dashboard (KPIs already in dashboardSummary)
  Future<Map<String, List<KpiPoint>>> analytics() async {
    // Return stub trend data — wire up dedicated trend endpoints as needed
    return {
      'revenue': const [
        KpiPoint('Jan', 2.1), KpiPoint('Feb', 2.6), KpiPoint('Mar', 2.4),
        KpiPoint('Apr', 3.2), KpiPoint('May', 3.8), KpiPoint('Jun', 4.5),
      ],
      'signups': const [
        KpiPoint('Jan', 120), KpiPoint('Feb', 180), KpiPoint('Mar', 160),
        KpiPoint('Apr', 240), KpiPoint('May', 320), KpiPoint('Jun', 410),
      ],
      'categoryShare': const [
        KpiPoint('Models', 38), KpiPoint('Photo', 24), KpiPoint('Video', 16),
        KpiPoint('Venues', 12), KpiPoint('Events', 10),
      ],
    };
  }

  // ── Private helpers ───────────────────────────────────────────

  static Review _reviewFromJson(Map j) => Review(
        id: j['id'],
        author: j['author_id'] ?? '',
        target: j['vendor_id'] ?? '',
        stars: j['stars'],
        text: j['text'],
        flagged: j['flagged'] ?? false,
        date: DateTime.parse(j['date']),
      );

  static SupportTicket _ticketFromJson(Map j) => SupportTicket(
        id: j['id'],
        subject: j['subject'],
        requester: j['requester_id'] ?? '',
        priority: j['priority'],
        status: j['status'],
        date: DateTime.parse(j['created_at']),
      );
}
