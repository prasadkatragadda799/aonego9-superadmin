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
    final data = ApiClient.asMap(await ApiClient.post('/auth/login/admin', {
      'email': email,
      'password': password,
      if (city.isNotEmpty) 'city': city,
    }, auth: false));
    await ApiClient.saveTokens('${data['access_token']}', '${data['refresh_token'] ?? ''}', email: email, city: city);
    return data;
  }

  Future<void> logout() => ApiClient.clearTokens();

  // ── Dashboard ─────────────────────────────────────────────────

  // GET /api/v1/analytics/admin/dashboard
  Future<Map<String, num>> dashboardSummary() async {
    final data = ApiClient.asMap(await ApiClient.get('/analytics/admin/dashboard'));
    num n(String k) {
      final v = data[k];
      return v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
    }

    return {
      'totalVendors': n('total_vendors'),
      'pendingVendors': n('pending_approvals'),
      'totalUsers': n('total_users'),
      'activeBookings': n('active_bookings'),
      'revenue': n('total_revenue'),
      'monthRevenue': n('monthly_revenue'),
      'commission': n('commission_earned'),
      'disputes': n('disputes'),
    };
  }

  // ── Vendors ───────────────────────────────────────────────────

  // GET /api/v1/vendors/admin
  Future<List<Vendor>> vendors({String? status}) async {
    final q = status != null ? '?status=$status' : '';
    return (await ApiClient.getAllPages('/vendors/admin$q')).map(Vendor.fromJson).toList();
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
    return ApiClient.asList(await ApiClient.get('/vendors/admin/$vendorId/portfolio'));
  }

  // GET /api/v1/vendors/admin/{id}/profile-details
  Future<Map<String, dynamic>> vendorProfileDetails(String vendorId) async {
    return ApiClient.asMap(await ApiClient.get('/vendors/admin/$vendorId/profile-details'));
  }

  // ── Users ─────────────────────────────────────────────────────

  // GET /api/v1/users
  Future<List<AppUser>> users({String? status}) async {
    final q = status != null ? '?status=$status' : '';
    return (await ApiClient.getAllPages('/users$q')).map(AppUser.fromJson).toList();
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
    final list = (await ApiClient.getAllPages('/bookings/admin$q')).map(Booking.fromJson).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // PUT /api/v1/bookings/{id}/status
  Future<void> setBookingStatus(String id, BookingStatus status) async {
    await ApiClient.put('/bookings/$id/status', {'status': status.name});
  }

  // ── Payments ──────────────────────────────────────────────────

  // GET /api/v1/payments/admin
  Future<List<PaymentTxn>> payments() async {
    final list = (await ApiClient.getAllPages('/payments/admin')).map(PaymentTxn.fromJson).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // POST /api/v1/payments/payout
  Future<void> triggerPayout(String vendorId, double amount) async {
    await ApiClient.post('/payments/payout', {'vendor_id': vendorId, 'amount': amount});
  }

  // ── Reviews ───────────────────────────────────────────────────

  // GET /api/v1/reviews/admin
  Future<List<Review>> reviews({bool? flagged}) async {
    final q = flagged != null ? '?flagged=$flagged' : '';
    final list = (await ApiClient.getAllPages('/reviews/admin$q')).map(Review.fromJson).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
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
    final list = (await ApiClient.getAllPages('/support/admin$q')).map(SupportTicket.fromJson).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // PUT /api/v1/support/admin/{id}
  Future<void> updateTicket(String id, String status) async {
    await ApiClient.put('/support/admin/$id', {'status': status});
  }

  // ── CMS banners ───────────────────────────────────────────────

  // GET /api/v1/cms/banners
  Future<List<CmsBanner>> banners() async {
    return ApiClient.asList(await ApiClient.get('/cms/banners')).map(CmsBanner.fromJson).toList();
  }

  // POST /api/v1/cms/banners
  Future<void> createBanner(CmsBanner b) => ApiClient.post('/cms/banners', b.toJson());

  // PUT /api/v1/cms/banners/{id}
  Future<void> updateBanner(String id, Map<String, dynamic> fields) => ApiClient.put('/cms/banners/$id', fields);

  // DELETE /api/v1/cms/banners/{id}
  Future<void> deleteBanner(String id) => ApiClient.delete('/cms/banners/$id');

  // ── CMS categories ────────────────────────────────────────────

  // GET /api/v1/cms/categories
  Future<List<Category>> categories() async {
    return ApiClient.asList(await ApiClient.get('/cms/categories')).map(Category.fromJson).toList();
  }

  // POST /api/v1/cms/categories
  Future<void> createCategory(String name) => ApiClient.post('/cms/categories', {
        'name': name,
        'slug': name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), ''),
        'active': true,
      });

  // PATCH /api/v1/cms/categories/{id}/toggle
  Future<void> toggleCategory(String id) => ApiClient.patch('/cms/categories/$id/toggle');

  // ── Platform events ───────────────────────────────────────────

  // GET /api/v1/events/admin
  Future<List<PlatformEvent>> events() async {
    final list = (await ApiClient.getAllPages('/events/admin')).map(PlatformEvent.fromJson).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // POST /api/v1/events/admin — create; PUT /api/v1/events/admin/{id} — full edit.
  Future<void> saveEvent(PlatformEvent e) async {
    if (e.id.isEmpty) {
      await ApiClient.post('/events/admin', e.toWriteJson());
    } else {
      await ApiClient.put('/events/admin/${e.id}', e.toWriteJson());
    }
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
      return ApiClient.asList(await ApiClient.get('/cms/newsletters'));
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
      return ApiClient.asList(await ApiClient.get('/cms/newsletters/contributions'));
    } catch (_) {}
    return const [];
  }

  // ── Analytics ─────────────────────────────────────────────────

  // GET /api/v1/analytics/admin/trends
  Future<Map<String, List<KpiPoint>>> analytics() async {
    final data = ApiClient.asMap(await ApiClient.get('/analytics/admin/trends'));
    List<KpiPoint> parse(Object? section, String key) => ApiClient.asList(section, key).map((p) {
          final v = p['value'];
          return KpiPoint('${p['label'] ?? ''}', v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
        }).toList();
    return {
      'revenue': parse(data['revenue'], 'points'),
      'signups': parse(data['signups'], 'points'),
      'categoryShare': parse(data['category_share'], 'shares'),
    };
  }

  // ── Subscriptions ─────────────────────────────────────────────

  // GET /subscriptions/admin/plans
  Future<List<SubscriptionPlan>> subscriptionPlans() async {
    return ApiClient.asList(await ApiClient.get('/subscriptions/admin/plans')).map(SubscriptionPlan.fromJson).toList();
  }

  // POST /subscriptions/admin/plans
  Future<SubscriptionPlan> createPlan(SubscriptionPlan plan) async {
    return SubscriptionPlan.fromJson(ApiClient.asMap(await ApiClient.post('/subscriptions/admin/plans', plan.toJson())));
  }

  // PUT /subscriptions/admin/plans/{id}
  Future<void> updatePlan(String id, SubscriptionPlan plan) async {
    await ApiClient.put('/subscriptions/admin/plans/$id', plan.toJson());
  }

  // DELETE /subscriptions/admin/plans/{id}
  Future<void> deletePlan(String id) => ApiClient.delete('/subscriptions/admin/plans/$id');

  // GET /subscriptions/admin/payment-info
  Future<PaymentSettings> paymentSettings() async {
    return PaymentSettings.fromJson(ApiClient.asMap(await ApiClient.get('/subscriptions/admin/payment-info')));
  }

  // PUT /subscriptions/admin/payment-info
  Future<void> setPaymentSettings(String upiId, String payeeName) async {
    await ApiClient.put('/subscriptions/admin/payment-info', {'upi_id': upiId, 'payee_name': payeeName});
  }

  // GET /subscriptions/admin/requests
  Future<List<SubscriptionRequest>> subscriptionRequests({String? status}) async {
    final q = status != null ? '?status=$status' : '';
    final list = ApiClient.asList(await ApiClient.get('/subscriptions/admin/requests$q')).map(SubscriptionRequest.fromJson).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
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
    return ApiClient.asList(await ApiClient.get('/bookings/admin/advance$q'));
  }

  Future<void> approveAdvance(String id, {String adminNote = ''}) async {
    await ApiClient.post('/bookings/admin/advance/$id/approve', {'admin_note': adminNote});
  }

  Future<void> rejectAdvance(String id, {String adminNote = ''}) async {
    await ApiClient.post('/bookings/admin/advance/$id/reject', {'admin_note': adminNote});
  }

  // ── Private helpers ───────────────────────────────────────────

  // ── Directory desks ───────────────────────────────────────────
  // Ads, sessions, partners, team, leads and social accounts — the content
  // the user app renders.

  /// A directory desk list. Each desk has exactly one backend route (checked
  /// against aonego9-backend); failures propagate so the screen shows an
  /// error with retry rather than an empty list that looks like "no data".
  Future<List<Map<String, dynamic>>> _list(String path) async => ApiClient.asList(await ApiClient.get(path));

  // ── Ads ──
  Future<List<AdCreative>> ads() async =>
      (await _list('/cms/ads')).map(AdCreative.fromJson).toList();

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
      (await _list('/sessions/admin')).map(Session.fromJson).toList();

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
      (await _list('/cms/partners')).map(LogoPartner.fromJson).toList();

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
      (await _list('/cms/team')).map(TeamMember.fromJson).toList();

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
    return (await _list('/browse/leads$suffix')).map(Lead.fromJson).toList();
  }

  Future<void> setLeadStatus(String id, String status) =>
      ApiClient.patch('/browse/leads/$id', {'status': status});

  // ── Social accounts ──
  Future<List<SocialAccount>> socialAccounts() async =>
      (await _list('/cms/social')).map(SocialAccount.fromJson).toList();

  Future<void> saveSocialAccount(SocialAccount a) async {
    if (a.id.isEmpty) {
      await ApiClient.post('/cms/social', a.toJson());
    } else {
      await ApiClient.put('/cms/social/${a.id}', a.toJson());
    }
  }

  Future<void> deleteSocialAccount(String id) => ApiClient.delete('/cms/social/$id');

  // ── Platform settings & admin team ─────────────────────────────
  // GET/PUT /api/v1/settings/platform and /api/v1/admins. A deployment
  // without these routes answers 404, which the Settings screen turns into
  // a clear "not enabled on this backend" state rather than fake toggles.

  Future<Map<String, dynamic>> platformSettings() async =>
      ApiClient.asMap(await ApiClient.get('/settings/platform'));

  Future<Map<String, dynamic>> savePlatformSettings(Map<String, dynamic> body) async =>
      ApiClient.asMap(await ApiClient.put('/settings/platform', body));

  Future<List<Map<String, dynamic>>> admins() async => ApiClient.asList(await ApiClient.get('/admins'));

  /// Returns the one-time temporary password for the new admin — the backend
  /// has no outbound email, so the inviting admin passes it on.
  Future<String> inviteAdmin({required String email, required String name, String city = ''}) async {
    final data = ApiClient.asMap(
      await ApiClient.post('/admins/invite', {'email': email, 'name': name, if (city.isNotEmpty) 'city': city}),
    );
    return '${data['temporary_password'] ?? ''}';
  }

  /// Anonymous password-reset request from the sign-in page. Lands in the
  /// Leads inbox for another admin (or the platform owner) to action.
  Future<void> requestPasswordReset(String email) => ApiClient.post('/browse/leads', {
        'kind': 'password_reset',
        'name': email.split('@').first,
        'email': email,
        'message': 'Super Admin console password reset requested for $email.',
        'source': 'admin_console',
      }, auth: false);
}
