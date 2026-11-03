// ─────────────────────────────────────────────────────────────
// Domain models for AOneGo9 Super Admin.
// Each model has fromJson / toJson so the backend dev can wire
// these straight to API responses with no UI changes.
// ─────────────────────────────────────────────────────────────

import '../../core/utils/date_util.dart';

enum ApprovalStatus { pending, approved, rejected, suspended }

enum BookingStatus { requested, confirmed, inProgress, completed, cancelled, disputed }

enum PaymentStatus { pending, paid, refunded, failed, payout }

/// How a booking entered the platform — directly, or from a user inquiry
/// raised in the user app (the inquiry → booking pipeline).
enum BookingSource { direct, inquiry }

enum UserRole { model, photographer, videographer, venue, eventService, client }

/// Enum lookup that also understands snake_case (`in_progress`,
/// `event_service`) and is case-insensitive.
T _enumFromString<T>(List<T> values, Object? name, T fallback) {
  if (name == null) return fallback;
  final n = '$name'.replaceAll('_', '').replaceAll('-', '').replaceAll(' ', '').toLowerCase();
  return values.firstWhere(
    (e) => e.toString().split('.').last.toLowerCase() == n,
    orElse: () => fallback,
  );
}

String _enumName(Object e) => e.toString().split('.').last;

Object? _pick(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    final v = j[k];
    if (v != null) return v;
  }
  return null;
}

double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
String _str(Object? v) => v == null ? '' : '$v';
bool _bool(Object? v, {bool fb = false}) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return fb;
}

/// Missing or malformed timestamps become "now" instead of throwing.
DateTime _date(Object? v) {
  final raw = _str(v);
  if (raw.isEmpty) return DateTime.now();
  return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
}

class Vendor {
  final String id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final String city;
  final String category;
  final ApprovalStatus status;
  final bool kycVerified;
  final double rating;
  final int totalBookings;
  final double totalEarnings;
  final DateTime joinedAt;
  final DateTime? lastLoginAt;
  final String avatarUrl;
  final String plan; // Starter | Pro | Elite — subscription tier

  Vendor({
    required this.id,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.city,
    required this.category,
    required this.status,
    required this.kycVerified,
    required this.rating,
    required this.totalBookings,
    required this.totalEarnings,
    required this.joinedAt,
    this.lastLoginAt,
    this.avatarUrl = '',
    this.plan = 'Starter',
  });

  factory Vendor.fromJson(Map<String, dynamic> j) {
    final last = _pick(j, ['last_login_at', 'lastLoginAt']);
    return Vendor(
      id: _str(j['id']),
      name: _str(j['name']),
      company: _str(j['company']),
      email: _str(j['email']),
      phone: _str(j['phone']),
      city: _str(j['city']),
      category: _str(j['category']),
      status: _enumFromString(ApprovalStatus.values, j['status'], ApprovalStatus.pending),
      kycVerified: _bool(_pick(j, ['kycVerified', 'kyc_verified'])),
      rating: _num(j['rating']),
      totalBookings: _int(_pick(j, ['totalBookings', 'total_bookings'])),
      totalEarnings: _num(_pick(j, ['totalEarnings', 'total_earnings'])),
      joinedAt: parseApiDateTime(_str(_pick(j, ['joinedAt', 'joined_at', 'created_at']))),
      lastLoginAt: last == null ? null : parseApiDateTime('$last'),
      avatarUrl: _str(_pick(j, ['avatarUrl', 'avatar_url'])),
      plan: _str(j['plan']).isEmpty ? 'Starter' : _str(j['plan']),
    );
  }

  String get displayName => company.isNotEmpty ? company : name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'company': company,
        'email': email,
        'phone': phone,
        'city': city,
        'category': category,
        'status': _enumName(status),
        'kycVerified': kycVerified,
        'rating': rating,
        'totalBookings': totalBookings,
        'totalEarnings': totalEarnings,
        'joinedAt': joinedAt.toIso8601String(),
        'avatarUrl': avatarUrl,
        'plan': plan,
      };

  Vendor copyWith({ApprovalStatus? status, bool? kycVerified}) => Vendor(
        id: id,
        name: name,
        company: company,
        email: email,
        phone: phone,
        city: city,
        category: category,
        status: status ?? this.status,
        kycVerified: kycVerified ?? this.kycVerified,
        rating: rating,
        totalBookings: totalBookings,
        totalEarnings: totalEarnings,
        joinedAt: joinedAt,
        lastLoginAt: lastLoginAt,
        avatarUrl: avatarUrl,
        plan: plan,
      );
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final UserRole role;
  final ApprovalStatus status;
  final bool verified;
  final double rating;
  final int jobsDone;
  final DateTime joinedAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.role,
    required this.status,
    required this.verified,
    required this.rating,
    required this.jobsDone,
    required this.joinedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _str(j['id']),
        name: _str(j['name']).isEmpty ? 'Unnamed user' : _str(j['name']),
        email: _str(j['email']),
        phone: _str(j['phone']),
        city: _str(j['city']),
        role: _enumFromString(UserRole.values, j['role'], UserRole.client),
        status: _enumFromString(ApprovalStatus.values, j['status'], ApprovalStatus.approved),
        verified: _bool(_pick(j, ['verified', 'is_verified'])),
        rating: _num(j['rating']),
        jobsDone: _int(_pick(j, ['jobsDone', 'jobs_done'])),
        joinedAt: _date(_pick(j, ['joinedAt', 'joined_at', 'created_at'])),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'city': city,
        'role': _enumName(role),
        'status': _enumName(status),
        'verified': verified,
        'rating': rating,
        'jobsDone': jobsDone,
        'joinedAt': joinedAt.toIso8601String(),
      };

  AppUser copyWith({ApprovalStatus? status, bool? verified}) => AppUser(
        id: id,
        name: name,
        email: email,
        phone: phone,
        city: city,
        role: role,
        status: status ?? this.status,
        verified: verified ?? this.verified,
        rating: rating,
        jobsDone: jobsDone,
        joinedAt: joinedAt,
      );
}

class Booking {
  final String id;
  final String clientName;
  final String vendorName;
  final String service;
  final DateTime date;
  final double amount;
  final BookingStatus status;
  final String city;
  final BookingSource source;
  final String? inquiryRef; // AO9-xxxxxx reference when raised via inquiry
  final double advancePaid; // deposit the client has already paid
  final String vendorId;
  final String clientEmail;
  final String clientPhone;
  final String notes;

  Booking({
    required this.id,
    required this.clientName,
    required this.vendorName,
    required this.service,
    required this.date,
    required this.amount,
    required this.status,
    required this.city,
    this.source = BookingSource.direct,
    this.inquiryRef,
    this.advancePaid = 0,
    this.vendorId = '',
    this.clientEmail = '',
    this.clientPhone = '',
    this.notes = '',
  });

  double get balanceDue => (amount - advancePaid).clamp(0, amount);

  factory Booking.fromJson(Map<String, dynamic> j) {
    final ref = _str(_pick(j, ['inquiry_ref', 'inquiryRef']));
    return Booking(
      id: _str(j['id']),
      clientName: _str(_pick(j, ['client_name', 'clientName'])),
      vendorName: _str(_pick(j, ['vendor_name', 'vendorName'])),
      service: _str(_pick(j, ['service', 'category'])),
      date: _date(_pick(j, ['date', 'event_date'])),
      amount: _num(j['amount']),
      status: _enumFromString(BookingStatus.values, j['status'], BookingStatus.requested),
      city: _str(_pick(j, ['city', 'location'])),
      source: _enumFromString(BookingSource.values, j['source'], ref.isEmpty ? BookingSource.direct : BookingSource.inquiry),
      inquiryRef: ref.isEmpty ? null : ref,
      advancePaid: _num(_pick(j, ['advance_paid', 'advancePaid'])),
      vendorId: _str(_pick(j, ['vendor_id', 'vendorId'])),
      clientEmail: _str(_pick(j, ['client_email', 'email'])),
      clientPhone: _str(_pick(j, ['client_phone', 'phone'])),
      notes: _str(_pick(j, ['notes', 'message'])),
    );
  }

  Booking copyWith({BookingStatus? status}) => Booking(
        id: id,
        clientName: clientName,
        vendorName: vendorName,
        service: service,
        date: date,
        amount: amount,
        status: status ?? this.status,
        city: city,
        source: source,
        inquiryRef: inquiryRef,
        advancePaid: advancePaid,
        vendorId: vendorId,
        clientEmail: clientEmail,
        clientPhone: clientPhone,
        notes: notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'vendorName': vendorName,
        'service': service,
        'date': date.toIso8601String(),
        'amount': amount,
        'status': _enumName(status),
        'city': city,
        'source': _enumName(source),
        'inquiryRef': inquiryRef,
        'advancePaid': advancePaid,
      };
}

class PaymentTxn {
  final String id;
  final String party;
  final String type; // booking, payout, refund, commission
  final double amount;
  final PaymentStatus status;
  final DateTime date;
  final String method;
  final String vendorId;
  final String reference;

  PaymentTxn({
    required this.id,
    required this.party,
    required this.type,
    required this.amount,
    required this.status,
    required this.date,
    required this.method,
    this.vendorId = '',
    this.reference = '',
  });

  factory PaymentTxn.fromJson(Map<String, dynamic> j) => PaymentTxn(
        id: _str(j['id']),
        party: _str(_pick(j, ['party', 'vendor_name', 'client_name'])),
        type: _str(j['type']).toLowerCase(),
        amount: _num(j['amount']),
        status: _enumFromString(PaymentStatus.values, j['status'], PaymentStatus.pending),
        date: _date(_pick(j, ['date', 'created_at'])),
        method: _str(j['method']),
        vendorId: _str(_pick(j, ['vendor_id', 'vendorId'])),
        reference: _str(_pick(j, ['reference', 'inquiry_ref', 'booking_id'])),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'party': party,
        'type': type,
        'amount': amount,
        'status': _enumName(status),
        'date': date.toIso8601String(),
        'method': method,
      };
}

class Review {
  final String id;
  final String author;
  final String target;
  final int stars;
  final String text;
  final bool flagged;
  final DateTime date;

  final String reply;

  Review({
    required this.id,
    required this.author,
    required this.target,
    required this.stars,
    required this.text,
    required this.flagged,
    required this.date,
    this.reply = '',
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: _str(j['id']),
        author: _str(_pick(j, ['author_name', 'client_name', 'author', 'author_id'])).isEmpty
            ? 'Anonymous'
            : _str(_pick(j, ['author_name', 'client_name', 'author', 'author_id'])),
        target: _str(_pick(j, ['vendor_name', 'target', 'vendor_id'])),
        stars: _int(_pick(j, ['stars', 'rating'])).clamp(0, 5),
        text: _str(j['text']),
        flagged: _bool(j['flagged']),
        date: _date(_pick(j, ['date', 'created_at'])),
        reply: _str(j['reply']),
      );

  Review copyWith({bool? flagged}) => Review(
        id: id, author: author, target: target, stars: stars, text: text,
        flagged: flagged ?? this.flagged, date: date, reply: reply,
      );
}

class SupportTicket {
  final String id;
  final String subject;
  final String requester;
  final String priority; // low, medium, high
  final String status; // open, pending, resolved
  final DateTime date;

  final String message;
  final String requesterEmail;

  SupportTicket({
    required this.id,
    required this.subject,
    required this.requester,
    required this.priority,
    required this.status,
    required this.date,
    this.message = '',
    this.requesterEmail = '',
  });

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: _str(j['id']),
        subject: _str(j['subject']).isEmpty ? '(no subject)' : _str(j['subject']),
        requester: _str(_pick(j, ['requester_name', 'requester', 'requester_id'])),
        priority: _str(j['priority']).toLowerCase(),
        status: _str(j['status']).isEmpty ? 'open' : _str(j['status']).toLowerCase(),
        date: _date(_pick(j, ['created_at', 'date'])),
        message: _str(_pick(j, ['message', 'body', 'description'])),
        requesterEmail: _str(_pick(j, ['requester_email', 'email'])),
      );

  SupportTicket copyWith({String? status}) => SupportTicket(
        id: id, subject: subject, requester: requester, priority: priority,
        status: status ?? this.status, date: date, message: message, requesterEmail: requesterEmail,
      );
}

class CmsBanner {
  final String id;
  final String title;
  final String placement;
  final bool active;
  final String imageUrl;
  final String link;
  CmsBanner({
    required this.id,
    required this.title,
    required this.placement,
    required this.active,
    this.imageUrl = '',
    this.link = '',
  });

  factory CmsBanner.fromJson(Map<String, dynamic> j) => CmsBanner(
        id: _str(j['id']),
        title: _str(j['title']),
        placement: _str(j['placement']),
        active: _bool(j['active'], fb: true),
        imageUrl: _str(_pick(j, ['image_url', 'imageUrl'])),
        link: _str(_pick(j, ['link_url', 'link', 'url'])),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'placement': placement,
        'active': active,
        'image_url': imageUrl,
        'link_url': link,
      };

  CmsBanner copyWith({bool? active}) =>
      CmsBanner(id: id, title: title, placement: placement, active: active ?? this.active, imageUrl: imageUrl, link: link);
}

class Category {
  final String id;
  final String name;
  final int listings;
  final bool active;
  Category({required this.id, required this.name, required this.listings, required this.active});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: _str(j['id']),
        name: _str(_pick(j, ['name', 'label'])),
        listings: _int(_pick(j, ['listings', 'count'])),
        active: _bool(j['active'], fb: true),
      );

  Category copyWith({bool? active}) => Category(id: id, name: name, listings: listings, active: active ?? this.active);
}

enum EventStatus { draft, upcoming, live, ended }

/// A platform-curated event. The super admin owns the full lifecycle and
/// decides which events appear in the live scroll poster shown to users.
class PlatformEvent {
  final String id;
  final String title;
  final String category;
  final String city;
  final DateTime date;
  final EventStatus status;
  final bool onPoster; // surfaced in the user app's live scroll poster
  final int registrations;
  final String venue;
  final String description;
  final String imageUrl;

  PlatformEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.city,
    required this.date,
    required this.status,
    required this.onPoster,
    required this.registrations,
    this.venue = '',
    this.description = '',
    this.imageUrl = '',
  });

  factory PlatformEvent.fromJson(Map<String, dynamic> j) => PlatformEvent(
        id: _str(j['id']),
        title: _str(j['title']),
        category: _str(j['category']),
        city: _str(j['city']),
        date: _date(j['date']),
        status: _enumFromString(EventStatus.values, j['status'], EventStatus.upcoming),
        onPoster: _bool(_pick(j, ['on_poster', 'onPoster'])),
        registrations: _int(j['registrations']),
        venue: _str(j['venue']),
        description: _str(j['description']),
        imageUrl: _str(_pick(j, ['image_url', 'imageUrl'])),
      );

  /// Body for creating / editing an event (snake_case, as the poster
  /// toggle already uses).
  Map<String, dynamic> toWriteJson() => {
        'title': title,
        'category': category,
        'city': city,
        'venue': venue,
        'description': description,
        'image_url': imageUrl,
        'date': date.toIso8601String(),
        'status': _enumName(status),
        'on_poster': onPoster,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'city': city,
        'date': date.toIso8601String(),
        'status': _enumName(status),
        'onPoster': onPoster,
        'registrations': registrations,
      };

  PlatformEvent copyWith({EventStatus? status, bool? onPoster}) => PlatformEvent(
        id: id,
        title: title,
        category: category,
        city: city,
        date: date,
        status: status ?? this.status,
        onPoster: onPoster ?? this.onPoster,
        registrations: registrations,
        venue: venue,
        description: description,
        imageUrl: imageUrl,
      );
}

class KpiPoint {
  final String label;
  final double value;
  KpiPoint(this.label, this.value);
}

/// A subscription pricing tier offered to vendors and/or users.
class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final String period; // e.g. monthly, yearly
  final List<String> features;
  final bool recommended;
  final String audience; // vendor | user | both

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    required this.recommended,
    required this.audience,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) => SubscriptionPlan(
        id: _str(j['id']),
        name: _str(j['name']),
        price: _num(j['price']),
        period: _str(j['period']),
        features: (j['features'] is List ? j['features'] as List : const []).map((f) => f.toString()).toList(),
        recommended: _bool(j['recommended']),
        audience: _str(j['audience']).isEmpty ? 'both' : _str(j['audience']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'period': period,
        'features': features,
        'recommended': recommended,
        'audience': audience,
      };
}

/// A vendor/user submitted request to activate a subscription plan,
/// pending admin review of the uploaded payment receipt.
class SubscriptionRequest {
  final String id;
  final String requesterType; // vendor | user
  final String? vendorId;
  final String? userId;
  final String planId;
  final String planName;
  final double amount;
  final String receiptImage; // base64 data URI
  final String status; // pending | approved | rejected
  final String adminNote;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  SubscriptionRequest({
    required this.id,
    required this.requesterType,
    this.vendorId,
    this.userId,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.receiptImage,
    required this.status,
    required this.adminNote,
    required this.createdAt,
    this.reviewedAt,
  });

  factory SubscriptionRequest.fromJson(Map<String, dynamic> j) => SubscriptionRequest(
        id: _str(j['id']),
        requesterType: _str(j['requester_type']),
        vendorId: j['vendor_id']?.toString(),
        userId: j['user_id']?.toString(),
        planId: _str(j['plan_id']),
        planName: _str(j['plan_name']),
        amount: _num(j['amount']),
        receiptImage: _str(j['receipt_image']),
        status: _str(j['status']).isEmpty ? 'pending' : _str(j['status']).toLowerCase(),
        adminNote: _str(j['admin_note']),
        createdAt: parseApiDateTime(j['created_at']?.toString() ?? j['createdAt']?.toString() ?? ''),
        reviewedAt: j['reviewed_at'] == null && j['reviewedAt'] == null
            ? null
            : parseApiDateTime((j['reviewed_at'] ?? j['reviewedAt']).toString()),
      );
}

/// The UPI details shown to vendors/users when paying for a subscription.
class PaymentSettings {
  final String upiId;
  final String payeeName;
  PaymentSettings({required this.upiId, required this.payeeName});

  factory PaymentSettings.fromJson(Map<String, dynamic> j) => PaymentSettings(
        upiId: _str(j['upi_id']).trim(),
        payeeName: _str(j['payee_name']).trim(),
      );

  Map<String, dynamic> toJson() => {'upi_id': upiId, 'payee_name': payeeName};
}
