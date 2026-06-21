// ─────────────────────────────────────────────────────────────
// Domain models for AOneGo9 Super Admin.
// Each model has fromJson / toJson so the backend dev can wire
// these straight to API responses with no UI changes.
// ─────────────────────────────────────────────────────────────

enum ApprovalStatus { pending, approved, rejected, suspended }

enum BookingStatus { requested, confirmed, inProgress, completed, cancelled, disputed }

enum PaymentStatus { pending, paid, refunded, failed, payout }

/// How a booking entered the platform — directly, or from a user inquiry
/// raised in the user app (the inquiry → booking pipeline).
enum BookingSource { direct, inquiry }

enum UserRole { model, photographer, videographer, venue, eventService, client }

T _enumFromString<T>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  return values.firstWhere(
    (e) => e.toString().split('.').last.toLowerCase() == name.toLowerCase(),
    orElse: () => fallback,
  );
}

String _enumName(Object e) => e.toString().split('.').last;

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
    this.avatarUrl = '',
    this.plan = 'Starter',
  });

  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(
        id: j['id'].toString(),
        name: j['name'] ?? '',
        company: j['company'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        city: j['city'] ?? '',
        category: j['category'] ?? '',
        status: _enumFromString(ApprovalStatus.values, j['status'], ApprovalStatus.pending),
        kycVerified: j['kycVerified'] ?? false,
        rating: (j['rating'] ?? 0).toDouble(),
        totalBookings: j['totalBookings'] ?? 0,
        totalEarnings: (j['totalEarnings'] ?? 0).toDouble(),
        joinedAt: DateTime.tryParse(j['joinedAt'] ?? '') ?? DateTime.now(),
        avatarUrl: j['avatarUrl'] ?? '',
        plan: j['plan'] ?? 'Starter',
      );

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
        id: j['id'].toString(),
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        city: j['city'] ?? '',
        role: _enumFromString(UserRole.values, j['role'], UserRole.client),
        status: _enumFromString(ApprovalStatus.values, j['status'], ApprovalStatus.approved),
        verified: j['verified'] ?? false,
        rating: (j['rating'] ?? 0).toDouble(),
        jobsDone: j['jobsDone'] ?? 0,
        joinedAt: DateTime.tryParse(j['joinedAt'] ?? '') ?? DateTime.now(),
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
  });

  double get balanceDue => (amount - advancePaid).clamp(0, amount);

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'].toString(),
        clientName: j['clientName'] ?? '',
        vendorName: j['vendorName'] ?? '',
        service: j['service'] ?? '',
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        amount: (j['amount'] ?? 0).toDouble(),
        status: _enumFromString(BookingStatus.values, j['status'], BookingStatus.requested),
        city: j['city'] ?? j['location'] ?? '',
        source: _enumFromString(BookingSource.values, j['source'], BookingSource.direct),
        inquiryRef: j['inquiryRef'],
        advancePaid: (j['advancePaid'] ?? 0).toDouble(),
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

  PaymentTxn({
    required this.id,
    required this.party,
    required this.type,
    required this.amount,
    required this.status,
    required this.date,
    required this.method,
  });

  factory PaymentTxn.fromJson(Map<String, dynamic> j) => PaymentTxn(
        id: j['id'].toString(),
        party: j['party'] ?? '',
        type: j['type'] ?? '',
        amount: (j['amount'] ?? 0).toDouble(),
        status: _enumFromString(PaymentStatus.values, j['status'], PaymentStatus.pending),
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        method: j['method'] ?? '',
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

  Review({
    required this.id,
    required this.author,
    required this.target,
    required this.stars,
    required this.text,
    required this.flagged,
    required this.date,
  });
}

class SupportTicket {
  final String id;
  final String subject;
  final String requester;
  final String priority; // low, medium, high
  final String status; // open, pending, resolved
  final DateTime date;

  SupportTicket({
    required this.id,
    required this.subject,
    required this.requester,
    required this.priority,
    required this.status,
    required this.date,
  });
}

class CmsBanner {
  final String id;
  final String title;
  final String placement;
  final bool active;
  CmsBanner({required this.id, required this.title, required this.placement, required this.active});
}

class Category {
  final String id;
  final String name;
  final int listings;
  final bool active;
  Category({required this.id, required this.name, required this.listings, required this.active});
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

  PlatformEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.city,
    required this.date,
    required this.status,
    required this.onPoster,
    required this.registrations,
  });

  factory PlatformEvent.fromJson(Map<String, dynamic> j) => PlatformEvent(
        id: j['id'].toString(),
        title: j['title'] ?? '',
        category: j['category'] ?? '',
        city: j['city'] ?? '',
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        status: _enumFromString(EventStatus.values, j['status'], EventStatus.upcoming),
        onPoster: j['onPoster'] ?? false,
        registrations: j['registrations'] ?? 0,
      );

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
      );
}

class KpiPoint {
  final String label;
  final double value;
  KpiPoint(this.label, this.value);
}
