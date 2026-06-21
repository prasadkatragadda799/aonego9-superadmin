import '../models/models.dart';

/// Static seed data used by the mock repositories.
/// Backend dev: delete this file once real endpoints are live.
class MockData {
  static final _now = DateTime(2026, 6, 16);

  static final vendors = <Vendor>[
    Vendor(id: 'V-1001', name: 'Rohan Mehta', company: 'Frame & Light Studios', email: 'rohan@framelight.in', phone: '+91 98200 11223', city: 'Mumbai', category: 'Photography', status: ApprovalStatus.pending, kycVerified: false, rating: 0, totalBookings: 0, totalEarnings: 0, joinedAt: _now.subtract(const Duration(days: 1))),
    Vendor(id: 'V-1002', name: 'Aisha Khan', company: 'Spotlight Talent Co.', email: 'aisha@spotlight.in', phone: '+91 99300 44556', city: 'Delhi', category: 'Talent Agency', status: ApprovalStatus.approved, kycVerified: true, rating: 4.8, totalBookings: 132, totalEarnings: 1840000, joinedAt: _now.subtract(const Duration(days: 210)), plan: 'Elite'),
    Vendor(id: 'V-1003', name: 'Karan Patel', company: 'Reel Motion Films', email: 'karan@reelmotion.in', phone: '+91 97400 66778', city: 'Ahmedabad', category: 'Videography', status: ApprovalStatus.approved, kycVerified: true, rating: 4.6, totalBookings: 88, totalEarnings: 1260000, joinedAt: _now.subtract(const Duration(days: 150)), plan: 'Pro'),
    Vendor(id: 'V-1004', name: 'Sneha Rao', company: 'Grand Vista Venues', email: 'sneha@grandvista.in', phone: '+91 96500 88990', city: 'Bengaluru', category: 'Venue', status: ApprovalStatus.pending, kycVerified: true, rating: 0, totalBookings: 0, totalEarnings: 0, joinedAt: _now.subtract(const Duration(days: 3))),
    Vendor(id: 'V-1005', name: 'Imran Sheikh', company: 'EventCraft Services', email: 'imran@eventcraft.in', phone: '+91 95600 12345', city: 'Hyderabad', category: 'Event Services', status: ApprovalStatus.suspended, kycVerified: true, rating: 3.9, totalBookings: 41, totalEarnings: 520000, joinedAt: _now.subtract(const Duration(days: 320))),
    Vendor(id: 'V-1006', name: 'Divya Nair', company: 'Aperture Collective', email: 'divya@aperture.in', phone: '+91 94700 56789', city: 'Kochi', category: 'Photography', status: ApprovalStatus.rejected, kycVerified: false, rating: 0, totalBookings: 0, totalEarnings: 0, joinedAt: _now.subtract(const Duration(days: 12))),
    Vendor(id: 'V-1007', name: 'Vikram Singh', company: 'Elite Models Mgmt', email: 'vikram@elitemodels.in', phone: '+91 93800 90123', city: 'Pune', category: 'Talent Agency', status: ApprovalStatus.approved, kycVerified: true, rating: 4.9, totalBookings: 201, totalEarnings: 2750000, joinedAt: _now.subtract(const Duration(days: 410)), plan: 'Elite'),
  ];

  static final users = <AppUser>[
    AppUser(id: 'U-2001', name: 'Priya Sharma', email: 'priya@gmail.com', phone: '+91 90000 11111', city: 'Mumbai', role: UserRole.model, status: ApprovalStatus.approved, verified: true, rating: 4.7, jobsDone: 34, joinedAt: _now.subtract(const Duration(days: 90))),
    AppUser(id: 'U-2002', name: 'Arjun Verma', email: 'arjun@gmail.com', phone: '+91 90000 22222', city: 'Delhi', role: UserRole.photographer, status: ApprovalStatus.approved, verified: true, rating: 4.5, jobsDone: 51, joinedAt: _now.subtract(const Duration(days: 140))),
    AppUser(id: 'U-2003', name: 'Neha Gupta', email: 'neha@gmail.com', phone: '+91 90000 33333', city: 'Bengaluru', role: UserRole.model, status: ApprovalStatus.pending, verified: false, rating: 0, jobsDone: 0, joinedAt: _now.subtract(const Duration(days: 2))),
    AppUser(id: 'U-2004', name: 'Sameer Joshi', email: 'sameer@gmail.com', phone: '+91 90000 44444', city: 'Pune', role: UserRole.videographer, status: ApprovalStatus.approved, verified: true, rating: 4.2, jobsDone: 22, joinedAt: _now.subtract(const Duration(days: 60))),
    AppUser(id: 'U-2005', name: 'Tara Dsouza', email: 'tara@gmail.com', phone: '+91 90000 55555', city: 'Goa', role: UserRole.client, status: ApprovalStatus.approved, verified: true, rating: 0, jobsDone: 8, joinedAt: _now.subtract(const Duration(days: 30))),
    AppUser(id: 'U-2006', name: 'Mohit Bansal', email: 'mohit@gmail.com', phone: '+91 90000 66666', city: 'Jaipur', role: UserRole.model, status: ApprovalStatus.suspended, verified: true, rating: 3.4, jobsDone: 5, joinedAt: _now.subtract(const Duration(days: 200))),
    AppUser(id: 'U-2007', name: 'Ananya Iyer', email: 'ananya@gmail.com', phone: '+91 90000 77777', city: 'Chennai', role: UserRole.eventService, status: ApprovalStatus.pending, verified: false, rating: 0, jobsDone: 0, joinedAt: _now.subtract(const Duration(days: 1))),
  ];

  static final bookings = <Booking>[
    Booking(id: 'B-3001', clientName: 'Tara Dsouza', vendorName: 'Spotlight Talent Co.', service: 'Fashion Shoot — 2 models', date: _now.add(const Duration(days: 5)), amount: 85000, status: BookingStatus.confirmed, city: 'Mumbai', advancePaid: 20000),
    Booking(id: 'B-3002', clientName: 'Acme Ads', vendorName: 'Reel Motion Films', service: 'Brand Film Production', date: _now.add(const Duration(days: 12)), amount: 320000, status: BookingStatus.inProgress, city: 'Ahmedabad'),
    Booking(id: 'B-3003', clientName: 'Wedding — Kapoor', vendorName: 'Grand Vista Venues', service: 'Venue + Decor', date: _now.subtract(const Duration(days: 4)), amount: 540000, status: BookingStatus.completed, city: 'Bengaluru'),
    Booking(id: 'B-3004', clientName: 'StartupX', vendorName: 'Frame & Light Studios', service: 'Product Photography', date: _now.add(const Duration(days: 2)), amount: 45000, status: BookingStatus.requested, city: 'Mumbai', source: BookingSource.inquiry, inquiryRef: 'AO9-7K2P9X', advancePaid: 5000),
    Booking(id: 'B-3008', clientName: 'Meera Nair', vendorName: 'Spotlight Talent Co.', service: 'Bridal Editorial — 2 models', date: _now.add(const Duration(days: 7)), amount: 90000, status: BookingStatus.requested, city: 'Kochi', source: BookingSource.inquiry, inquiryRef: 'AO9-3F8Q1Z', advancePaid: 5000),
    Booking(id: 'B-3005', clientName: 'Riya Events', vendorName: 'EventCraft Services', service: 'Corporate Event', date: _now.subtract(const Duration(days: 1)), amount: 210000, status: BookingStatus.disputed, city: 'Hyderabad'),
    Booking(id: 'B-3006', clientName: 'Fashion Hub', vendorName: 'Elite Models Mgmt', service: 'Runway — 6 models', date: _now.subtract(const Duration(days: 10)), amount: 480000, status: BookingStatus.completed, city: 'Pune'),
    Booking(id: 'B-3007', clientName: 'Cafe Mocha', vendorName: 'Aperture Collective', service: 'Menu Shoot', date: _now.add(const Duration(days: 8)), amount: 38000, status: BookingStatus.cancelled, city: 'Kochi'),
  ];

  static final payments = <PaymentTxn>[
    PaymentTxn(id: 'T-4001', party: 'Tara Dsouza', type: 'booking', amount: 85000, status: PaymentStatus.paid, date: _now.subtract(const Duration(days: 1)), method: 'UPI'),
    PaymentTxn(id: 'T-4002', party: 'Spotlight Talent Co.', type: 'payout', amount: 72250, status: PaymentStatus.payout, date: _now.subtract(const Duration(days: 1)), method: 'Bank Transfer'),
    PaymentTxn(id: 'T-4003', party: 'Acme Ads', type: 'booking', amount: 320000, status: PaymentStatus.paid, date: _now.subtract(const Duration(days: 3)), method: 'Card'),
    PaymentTxn(id: 'T-4004', party: 'Riya Events', type: 'refund', amount: 210000, status: PaymentStatus.refunded, date: _now.subtract(const Duration(days: 2)), method: 'UPI'),
    PaymentTxn(id: 'T-4005', party: 'Platform Commission', type: 'commission', amount: 48000, status: PaymentStatus.paid, date: _now.subtract(const Duration(days: 4)), method: 'Internal'),
    PaymentTxn(id: 'T-4006', party: 'Frame & Light Studios', type: 'booking', amount: 45000, status: PaymentStatus.pending, date: _now, method: 'UPI'),
    PaymentTxn(id: 'T-4007', party: 'Elite Models Mgmt', type: 'payout', amount: 408000, status: PaymentStatus.payout, date: _now.subtract(const Duration(days: 9)), method: 'Bank Transfer'),
    // Subscription revenue (vendor plan billing)
    PaymentTxn(id: 'T-4008', party: 'Spotlight Talent Co. — Elite plan', type: 'subscription', amount: 2999, status: PaymentStatus.paid, date: _now.subtract(const Duration(days: 6)), method: 'Card'),
    PaymentTxn(id: 'T-4009', party: 'Reel Motion Films — Pro plan', type: 'subscription', amount: 999, status: PaymentStatus.paid, date: _now.subtract(const Duration(days: 6)), method: 'UPI'),
    PaymentTxn(id: 'T-4010', party: 'Elite Models Mgmt — Elite plan', type: 'subscription', amount: 2999, status: PaymentStatus.paid, date: _now.subtract(const Duration(days: 5)), method: 'Card'),
    // Advance / deposit payments from users confirming a booking
    PaymentTxn(id: 'T-4011', party: 'StartupX — advance (AO9-7K2P9X)', type: 'advance', amount: 5000, status: PaymentStatus.paid, date: _now.subtract(const Duration(hours: 6)), method: 'UPI'),
    PaymentTxn(id: 'T-4012', party: 'Meera Nair — advance (AO9-3F8Q1Z)', type: 'advance', amount: 5000, status: PaymentStatus.paid, date: _now.subtract(const Duration(hours: 20)), method: 'Card'),
    PaymentTxn(id: 'T-4013', party: 'Tara Dsouza — advance', type: 'advance', amount: 20000, status: PaymentStatus.paid, date: _now.subtract(const Duration(days: 2)), method: 'UPI'),
  ];

  static final reviews = <Review>[
    Review(id: 'R-1', author: 'Tara Dsouza', target: 'Spotlight Talent Co.', stars: 5, text: 'Incredible professionalism and on-time delivery.', flagged: false, date: _now.subtract(const Duration(days: 2))),
    Review(id: 'R-2', author: 'Anon', target: 'EventCraft Services', stars: 1, text: 'Spam-like promotional content with external links.', flagged: true, date: _now.subtract(const Duration(days: 1))),
    Review(id: 'R-3', author: 'StartupX', target: 'Frame & Light Studios', stars: 4, text: 'Great quality, minor delays.', flagged: false, date: _now.subtract(const Duration(days: 5))),
    Review(id: 'R-4', author: 'Fashion Hub', target: 'Elite Models Mgmt', stars: 5, text: 'Best roster in the country.', flagged: false, date: _now.subtract(const Duration(days: 8))),
  ];

  static final tickets = <SupportTicket>[
    SupportTicket(id: 'S-1', subject: 'Payout not received', requester: 'Spotlight Talent Co.', priority: 'high', status: 'open', date: _now.subtract(const Duration(days: 1))),
    SupportTicket(id: 'S-2', subject: 'KYC document re-upload', requester: 'Rohan Mehta', priority: 'medium', status: 'pending', date: _now.subtract(const Duration(days: 2))),
    SupportTicket(id: 'S-3', subject: 'Dispute on booking B-3005', requester: 'Riya Events', priority: 'high', status: 'open', date: _now.subtract(const Duration(days: 1))),
    SupportTicket(id: 'S-4', subject: 'Profile photo change request', requester: 'Priya Sharma', priority: 'low', status: 'resolved', date: _now.subtract(const Duration(days: 6))),
  ];

  static final banners = <CmsBanner>[
    CmsBanner(id: 'C-1', title: 'Summer Fashion Week 2026', placement: 'Home — Hero', active: true),
    CmsBanner(id: 'C-2', title: 'Refer a Vendor, Earn ₹5000', placement: 'Vendor App — Banner', active: true),
    CmsBanner(id: 'C-3', title: 'Monsoon Wedding Specials', placement: 'Home — Mid', active: false),
  ];

  static final categories = <Category>[
    Category(id: 'CAT-1', name: 'Models', listings: 1240, active: true),
    Category(id: 'CAT-2', name: 'Photographers', listings: 860, active: true),
    Category(id: 'CAT-3', name: 'Videographers', listings: 540, active: true),
    Category(id: 'CAT-4', name: 'Venues', listings: 320, active: true),
    Category(id: 'CAT-5', name: 'Event Services', listings: 410, active: true),
    Category(id: 'CAT-6', name: 'Makeup Artists', listings: 290, active: false),
  ];

  static final events = <PlatformEvent>[
    PlatformEvent(id: 'EV-1', title: 'Summer Fashion Week 2026', category: 'Fashion Show', city: 'Mumbai', date: _now.add(const Duration(days: 5)), status: EventStatus.live, onPoster: true, registrations: 1840),
    PlatformEvent(id: 'EV-2', title: 'AOneGo9 Talent Showcase', category: 'Showcase', city: 'Delhi', date: _now.add(const Duration(days: 12)), status: EventStatus.upcoming, onPoster: true, registrations: 620),
    PlatformEvent(id: 'EV-3', title: 'Bridal & Wedding Expo', category: 'Expo', city: 'Bengaluru', date: _now.add(const Duration(days: 21)), status: EventStatus.upcoming, onPoster: true, registrations: 410),
    PlatformEvent(id: 'EV-4', title: 'Monsoon Editorial Awards', category: 'Awards', city: 'Mumbai', date: _now.add(const Duration(days: 34)), status: EventStatus.draft, onPoster: false, registrations: 0),
    PlatformEvent(id: 'EV-5', title: 'Corporate Brand Summit', category: 'Conference', city: 'Hyderabad', date: _now.subtract(const Duration(days: 9)), status: EventStatus.ended, onPoster: false, registrations: 2110),
  ];

  static final revenueTrend = <KpiPoint>[
    KpiPoint('Jan', 2.1), KpiPoint('Feb', 2.6), KpiPoint('Mar', 2.4),
    KpiPoint('Apr', 3.2), KpiPoint('May', 3.8), KpiPoint('Jun', 4.5),
  ];

  static final signupsTrend = <KpiPoint>[
    KpiPoint('Jan', 120), KpiPoint('Feb', 180), KpiPoint('Mar', 160),
    KpiPoint('Apr', 240), KpiPoint('May', 320), KpiPoint('Jun', 410),
  ];

  static final categoryShare = <KpiPoint>[
    KpiPoint('Models', 38), KpiPoint('Photo', 24), KpiPoint('Video', 16),
    KpiPoint('Venues', 12), KpiPoint('Events', 10),
  ];
}
