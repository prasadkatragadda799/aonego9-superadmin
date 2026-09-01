import '../models/models.dart';
import '../models/directory_models.dart';
import '../api/api_client.dart';

// ignore: constant_identifier_names

/// ───────────────────────────────────────────────────────────────
/// ADMIN REPOSITORY — all methods now call the real FastAPI backend.
/// Base URL is configured in api_client.dart (kBaseUrl).
/// ───────────────────────────────────────────────────────────────
class AdminRepository {
  // ── Auth ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password, {String city = ''}) async {
    final data = await ApiClient.post('/auth/login/admin', {
      'email': email,
      'password': password,
      if (city.isNotEmpty) 'city': city,
    }, auth: false);
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
      'disputes': data['disputes'] as num,
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

  // GET /api/v1/vendors/admin/{id}/portfolio
  Future<List<Map<String, dynamic>>> vendorPortfolio(String vendorId) async {
    final data = await ApiClient.get('/vendors/admin/$vendorId/portfolio') as List;
    return data.cast<Map<String, dynamic>>();
  }

  // GET /api/v1/vendors/admin/{id}/profile-details
  Future<Map<String, dynamic>> vendorProfileDetails(String vendorId) async {
    final data = await ApiClient.get('/vendors/admin/$vendorId/profile-details') as Map;
    return data.cast<String, dynamic>();
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

  // ── Newsletter digest ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> newsletters() async {
    try {
      final data = await ApiClient.get('/cms/newsletters');
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map && data['items'] is List) {
        return (data['items'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> publishNewsletter(Map<String, dynamic> payload) async {
    await ApiClient.post('/cms/newsletters', payload);
  }

  Future<void> updateNewsletter(String id, Map<String, dynamic> payload) async {
    await ApiClient.put('/cms/newsletters/$id', payload);
  }

  Future<void> deleteNewsletter(String id) async {
    await ApiClient.delete('/cms/newsletters/$id');
  }

  Future<List<Map<String, dynamic>>> newsletterContributions() async {
    try {
      final data = await ApiClient.get('/cms/newsletters/contributions');
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map && data['items'] is List) {
        return (data['items'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return const [];
  }

  // ── Analytics ─────────────────────────────────────────────────

  // GET /api/v1/analytics/admin/trends
  Future<Map<String, List<KpiPoint>>> analytics() async {
    final data = await ApiClient.get('/analytics/admin/trends') as Map;
    List<KpiPoint> parsePoints(List points) =>
        points.map((p) => KpiPoint(p['label'] as String, (p['value'] as num).toDouble())).toList();
    return {
      'revenue': parsePoints((data['revenue'] as Map)['points'] as List),
      'signups': parsePoints((data['signups'] as Map)['points'] as List),
      'categoryShare': parsePoints((data['category_share'] as Map)['shares'] as List),
    };
  }

  // ── Subscriptions ─────────────────────────────────────────────

  // GET /subscriptions/admin/plans
  Future<List<SubscriptionPlan>> subscriptionPlans() async {
    final data = await ApiClient.get('/subscriptions/admin/plans') as List;
    return data.map((j) => SubscriptionPlan.fromJson(j)).toList();
  }

  // POST /subscriptions/admin/plans
  Future<SubscriptionPlan> createPlan(SubscriptionPlan plan) async {
    final data = await ApiClient.post('/subscriptions/admin/plans', plan.toJson());
    return SubscriptionPlan.fromJson(data);
  }

  // PUT /subscriptions/admin/plans/{id}
  Future<void> updatePlan(String id, SubscriptionPlan plan) async {
    await ApiClient.put('/subscriptions/admin/plans/$id', plan.toJson());
  }

  // DELETE /subscriptions/admin/plans/{id}
  Future<void> deletePlan(String id) => ApiClient.delete('/subscriptions/admin/plans/$id');

  // GET /subscriptions/admin/payment-info
  Future<PaymentSettings> paymentSettings() async {
    final data = await ApiClient.get('/subscriptions/admin/payment-info') as Map;
    return PaymentSettings.fromJson(data.cast<String, dynamic>());
  }

  // PUT /subscriptions/admin/payment-info
  Future<void> setPaymentSettings(String upiId, String payeeName) async {
    await ApiClient.put('/subscriptions/admin/payment-info', {'upi_id': upiId, 'payee_name': payeeName});
  }

  // GET /subscriptions/admin/requests
  Future<List<SubscriptionRequest>> subscriptionRequests({String? status}) async {
    final q = status != null ? '?status=$status' : '';
    final data = await ApiClient.get('/subscriptions/admin/requests$q') as List;
    return data.map((j) => SubscriptionRequest.fromJson(j)).toList();
  }

  // POST /subscriptions/admin/requests/{id}/approve
  Future<void> approveRequest(String id, {String adminNote = ''}) async {
    await ApiClient.post('/subscriptions/admin/requests/$id/approve', {'admin_note': adminNote});
  }

  // POST /subscriptions/admin/requests/{id}/reject
  Future<void> rejectRequest(String id, {String adminNote = ''}) async {
    await ApiClient.post('/subscriptions/admin/requests/$id/reject', {'admin_note': adminNote});
  }

  // POST /subscriptions/admin/vendors/{id}/assign
  Future<void> assignVendorPlan(String vendorId, String planId) async {
    await ApiClient.post('/subscriptions/admin/vendors/$vendorId/assign', {'plan_id': planId});
  }

  // ── Advance payment requests ───────────────────────────────────

  Future<List<Map<String, dynamic>>> advanceRequests({String? status}) async {
    final q = status != null ? '?status=$status' : '';
    final data = await ApiClient.get('/bookings/admin/advance$q');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const [];
  }

  Future<void> approveAdvance(String id, {String adminNote = ''}) async {
    await ApiClient.post('/bookings/admin/advance/$id/approve', {'admin_note': adminNote});
  }

  Future<void> rejectAdvance(String id, {String adminNote = ''}) async {
    await ApiClient.post('/bookings/admin/advance/$id/reject', {'admin_note': adminNote});
  }

  // ── Private helpers ───────────────────────────────────────────

  // ── Directory desks ───────────────────────────────────────────
  // Ads, sessions, partners, team, leads and social accounts. These back the
  // content the user app renders, and every read degrades to an empty list
  // rather than throwing — a desk whose backend route isn't live yet must
  // still open to a usable (empty) screen instead of a red error page.

  Future<List<Map<String, dynamic>>> _list(List<String> paths) async {
    for (final path in paths) {
      try {
        final data = await ApiClient.get(path);
        if (data is List) return data.cast<Map<String, dynamic>>();
        if (data is Map && data['items'] is List) {
          return (data['items'] as List).cast<Map<String, dynamic>>();
        }
      } catch (_) {
        // try the next candidate path
      }
    }
    return const [];
  }

  // ── Ads ──
  Future<List<AdCreative>> ads() async =>
      (await _list(['/cms/ads', '/browse/ads'])).map(AdCreative.fromJson).toList();

  Future<void> saveAd(AdCreative ad) async {
    if (ad.id.isEmpty) {
      await ApiClient.post('/cms/ads', ad.toJson());
    } else {
      await ApiClient.put('/cms/ads/${ad.id}', ad.toJson());
    }
  }

  Future<void> setAdActive(String id, bool active) =>
      ApiClient.patch('/cms/ads/$id', {'active': active});

  Future<void> deleteAd(String id) => ApiClient.delete('/cms/ads/$id');

  // ── Sessions (workshops & webinars) ──
  Future<List<Session>> sessions() async =>
      (await _list(['/sessions/admin', '/sessions'])).map(Session.fromJson).toList();

  Future<void> saveSession(Session s) async {
    if (s.id.isEmpty) {
      await ApiClient.post('/sessions', s.toJson());
    } else {
      await ApiClient.put('/sessions/${s.id}', s.toJson());
    }
  }

  Future<void> setSessionPublished(String id, bool published) =>
      ApiClient.patch('/sessions/$id', {'published': published});

  Future<void> deleteSession(String id) => ApiClient.delete('/sessions/$id');

  // ── Partners ──
  Future<List<LogoPartner>> partners() async =>
      (await _list(['/cms/partners', '/browse/partners'])).map(LogoPartner.fromJson).toList();

  Future<void> savePartner(LogoPartner p) async {
    if (p.id.isEmpty) {
      await ApiClient.post('/cms/partners', p.toJson());
    } else {
      await ApiClient.put('/cms/partners/${p.id}', p.toJson());
    }
  }

  Future<void> setPartnerPublished(String id, bool published) =>
      ApiClient.patch('/cms/partners/$id', {'published': published});

  Future<void> deletePartner(String id) => ApiClient.delete('/cms/partners/$id');

  // ── Team ──
  Future<List<TeamMember>> team() async =>
      (await _list(['/cms/team', '/browse/team'])).map(TeamMember.fromJson).toList();

  Future<void> saveTeamMember(TeamMember m) async {
    if (m.id.isEmpty) {
      await ApiClient.post('/cms/team', m.toJson());
    } else {
      await ApiClient.put('/cms/team/${m.id}', m.toJson());
    }
  }

  Future<void> setTeamPublished(String id, bool published) =>
      ApiClient.patch('/cms/team/$id', {'published': published});

  Future<void> deleteTeamMember(String id) => ApiClient.delete('/cms/team/$id');

  // ── Leads (contact / join / apply) ──
  Future<List<Lead>> leads({String? kind, String? status}) async {
    final q = <String>[
      if (kind != null && kind.isNotEmpty) 'kind=$kind',
      if (status != null && status.isNotEmpty) 'status=$status',
    ].join('&');
    final suffix = q.isEmpty ? '' : '?$q';
    return (await _list(['/browse/leads$suffix', '/cms/leads$suffix'])).map(Lead.fromJson).toList();
  }

  Future<void> setLeadStatus(String id, String status) =>
      ApiClient.patch('/browse/leads/$id', {'status': status});

  // ── Social accounts ──
  Future<List<SocialAccount>> socialAccounts() async =>
      (await _list(['/cms/social', '/settings/social'])).map(SocialAccount.fromJson).toList();

  Future<void> saveSocialAccount(SocialAccount a) async {
    if (a.id.isEmpty) {
      await ApiClient.post('/cms/social', a.toJson());
    } else {
      await ApiClient.put('/cms/social/${a.id}', a.toJson());
    }
  }

  Future<void> deleteSocialAccount(String id) => ApiClient.delete('/cms/social/$id');

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
