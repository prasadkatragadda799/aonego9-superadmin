/// ─────────────────────────────────────────────────────────────
/// DIRECTORY MODELS — the content surfaces the super admin curates for the
/// user app: ad creatives, workshops & webinars, academic + brand partners,
/// the team roster, and inbound leads from the contact / join / apply forms.
///
/// These mirror the user app's `data/directory.dart` shapes field for field,
/// so what the desk publishes here is exactly what the marketplace renders.
/// ─────────────────────────────────────────────────────────────
library;

String _s(dynamic v) => v == null ? '' : '$v'.trim();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

/// ── Ad creative ─────────────────────────────────────────────────
class AdCreative {
  final String id;

  /// 'video' | 'photo'
  final String media;
  final String headline;
  final String sub;
  final String imageUrl;
  final String videoUrl;

  /// Promotes a marketplace profile when set, otherwise the website.
  final String profileId;
  final String profileName;
  final String profileCat;
  final String websiteUrl;
  final String label;
  final String city;
  final bool active;
  final int impressions;
  final int clicks;

  const AdCreative({
    required this.id,
    required this.media,
    required this.headline,
    this.sub = '',
    this.imageUrl = '',
    this.videoUrl = '',
    this.profileId = '',
    this.profileName = '',
    this.profileCat = '',
    this.websiteUrl = '',
    this.label = 'Featured',
    this.city = '',
    this.active = true,
    this.impressions = 0,
    this.clicks = 0,
  });

  bool get isVideo => media == 'video';

  /// Click-through rate as a percentage. Zero impressions is 0, not NaN —
  /// a brand-new creative must not render "NaN%" in the table.
  double get ctr => impressions == 0 ? 0 : (clicks / impressions) * 100;

  factory AdCreative.fromJson(Map<String, dynamic> j) => AdCreative(
        id: _s(j['id']),
        media: _s(j['media'] ?? j['type']).toLowerCase().contains('vid') ? 'video' : 'photo',
        headline: _s(j['headline'] ?? j['title']),
        sub: _s(j['sub'] ?? j['subtitle']),
        imageUrl: _s(j['image_url']),
        videoUrl: _s(j['video_url']),
        profileId: _s(j['profile_id'] ?? j['vendor_id']),
        profileName: _s(j['profile_name'] ?? j['vendor_name']),
        profileCat: _s(j['profile_cat'] ?? j['category']),
        websiteUrl: _s(j['website_url']),
        label: _s(j['label']).isEmpty ? 'Featured' : _s(j['label']),
        city: _s(j['city']),
        active: j['active'] != false,
        impressions: _i(j['impressions']),
        clicks: _i(j['clicks']),
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'media': media,
        'headline': headline,
        'sub': sub,
        'image_url': imageUrl,
        'video_url': videoUrl,
        'profile_id': profileId,
        'profile_name': profileName,
        'profile_cat': profileCat,
        'website_url': websiteUrl,
        'label': label,
        'city': city,
        'active': active,
      };

  AdCreative copyWith({bool? active}) => AdCreative(
        id: id,
        media: media,
        headline: headline,
        sub: sub,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        profileId: profileId,
        profileName: profileName,
        profileCat: profileCat,
        websiteUrl: websiteUrl,
        label: label,
        city: city,
        active: active ?? this.active,
        impressions: impressions,
        clicks: clicks,
      );
}

/// ── Workshop / webinar ──────────────────────────────────────────
class Session {
  final String id;

  /// 'workshop' (in person) | 'webinar' (online)
  final String mode;
  final String title;
  final String host;
  final String division;
  final String city;
  final String state;
  final String date;
  final String time;
  final String duration;
  final String fee;
  final int seats;
  final int seatsLeft;
  final String blurb;
  final String emoji;
  final bool published;
  final int registrations;

  const Session({
    required this.id,
    required this.mode,
    required this.title,
    this.host = '',
    this.division = 'talent',
    this.city = '',
    this.state = '',
    this.date = '',
    this.time = '',
    this.duration = '',
    this.fee = 'Free',
    this.seats = 0,
    this.seatsLeft = 0,
    this.blurb = '',
    this.emoji = '🎓',
    this.published = false,
    this.registrations = 0,
  });

  bool get isWebinar => mode == 'webinar';
  bool get soldOut => seats > 0 && seatsLeft <= 0;

  /// "Mumbai · Maharashtra", "Online", or just the city.
  ///
  /// Some places are their own state — Delhi NCR, Goa — and joining those
  /// blindly renders "Delhi NCR · Delhi NCR" in the schedule list.
  String get placeLabel {
    if (city.isEmpty) return '';
    if (city.toLowerCase() == 'online') return city;
    if (state.isEmpty || state.toLowerCase() == city.toLowerCase()) return city;
    return '$city · $state';
  }

  /// How full the session is, 0–1. Guards the divide so a session with no
  /// declared capacity reads as empty rather than crashing the progress bar.
  double get fillRatio => seats == 0 ? 0 : ((seats - seatsLeft) / seats).clamp(0, 1);

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: _s(j['id']),
        mode: _s(j['mode'] ?? j['type']).toLowerCase().contains('webinar') ? 'webinar' : 'workshop',
        title: _s(j['title']),
        host: _s(j['host'] ?? j['presenter']),
        division: _s(j['division']).isEmpty ? 'talent' : _s(j['division']),
        city: _s(j['city']),
        state: _s(j['state']),
        date: _s(j['date'] ?? j['starts_at']),
        time: _s(j['time']),
        duration: _s(j['duration']),
        fee: _s(j['fee']).isEmpty ? 'Free' : _s(j['fee']),
        seats: _i(j['seats']),
        seatsLeft: _i(j['seats_left']),
        blurb: _s(j['blurb'] ?? j['description']),
        emoji: _s(j['emoji']).isEmpty ? '🎓' : _s(j['emoji']),
        published: j['published'] == true,
        registrations: _i(j['registrations']),
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'mode': mode,
        'title': title,
        'host': host,
        'division': division,
        'city': city,
        'state': state,
        'date': date,
        'time': time,
        'duration': duration,
        'fee': fee,
        'seats': seats,
        'seats_left': seatsLeft,
        'blurb': blurb,
        'emoji': emoji,
        'published': published,
      };

  Session copyWith({bool? published}) => Session(
        id: id,
        mode: mode,
        title: title,
        host: host,
        division: division,
        city: city,
        state: state,
        date: date,
        time: time,
        duration: duration,
        fee: fee,
        seats: seats,
        seatsLeft: seatsLeft,
        blurb: blurb,
        emoji: emoji,
        published: published ?? this.published,
        registrations: registrations,
      );
}

/// ── Partner ─────────────────────────────────────────────────────
enum PartnerTier { academic, brand, institutional }

class LogoPartner {
  final String id;
  final String name;
  final String tagline;
  final String logoUrl;
  final PartnerTier tier;
  final String division;
  final String city;
  final String website;
  final bool published;

  const LogoPartner({
    required this.id,
    required this.name,
    this.tagline = '',
    this.logoUrl = '',
    this.tier = PartnerTier.brand,
    this.division = '',
    this.city = '',
    this.website = '',
    this.published = true,
  });

  String get tierLabel => switch (tier) {
        PartnerTier.academic => 'Academic',
        PartnerTier.institutional => 'Industry body',
        PartnerTier.brand => 'Brand',
      };

  factory LogoPartner.fromJson(Map<String, dynamic> j) => LogoPartner(
        id: _s(j['id']),
        name: _s(j['name']),
        tagline: _s(j['tagline'] ?? j['blurb']),
        logoUrl: _s(j['logo_url']),
        tier: switch (_s(j['tier']).toLowerCase()) {
          'academic' => PartnerTier.academic,
          'institutional' => PartnerTier.institutional,
          _ => PartnerTier.brand,
        },
        division: _s(j['division'] ?? j['category']),
        city: _s(j['city']),
        website: _s(j['website']),
        published: j['published'] != false,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        'tagline': tagline,
        'logo_url': logoUrl,
        'tier': tier.name,
        'division': division,
        'city': city,
        'website': website,
        'published': published,
      };

  LogoPartner copyWith({bool? published}) => LogoPartner(
        id: id,
        name: name,
        tagline: tagline,
        logoUrl: logoUrl,
        tier: tier,
        division: division,
        city: city,
        website: website,
        published: published ?? this.published,
      );
}

/// ── Team member ─────────────────────────────────────────────────
class TeamMember {
  final String id;
  final String name;
  final String role;
  final String desk;
  final String bio;
  final String photoUrl;
  final String city;
  final bool published;

  const TeamMember({
    required this.id,
    required this.name,
    this.role = '',
    this.desk = 'Leadership',
    this.bio = '',
    this.photoUrl = '',
    this.city = '',
    this.published = true,
  });

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        id: _s(j['id']),
        name: _s(j['name']),
        role: _s(j['role']),
        desk: _s(j['desk'] ?? j['department']).isEmpty ? 'Leadership' : _s(j['desk'] ?? j['department']),
        bio: _s(j['bio']),
        photoUrl: _s(j['photo_url'] ?? j['avatar_url']),
        city: _s(j['city']),
        published: j['published'] != false,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        'role': role,
        'desk': desk,
        'bio': bio,
        'photo_url': photoUrl,
        'city': city,
        'published': published,
      };

  TeamMember copyWith({bool? published}) => TeamMember(
        id: id,
        name: name,
        role: role,
        desk: desk,
        bio: bio,
        photoUrl: photoUrl,
        city: city,
        published: published ?? this.published,
      );
}

/// ── Inbound lead ────────────────────────────────────────────────
/// One submission from the user app's contact / join us / apply forms.
class Lead {
  final String id;

  /// contact | join | apply_artist | apply_vendor | partner | session_register
  final String kind;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String state;

  /// Free-form extras that differ per form — desk, category, portfolio,
  /// business name, topic. Kept as a map rather than twenty nullable fields
  /// so a new form field needs no model change to be visible to the desk.
  final Map<String, dynamic> details;
  final String message;
  final String status; // new | in_progress | closed
  final DateTime? createdAt;

  const Lead({
    required this.id,
    required this.kind,
    required this.name,
    this.email = '',
    this.phone = '',
    this.city = '',
    this.state = '',
    this.details = const {},
    this.message = '',
    this.status = 'new',
    this.createdAt,
  });

  String get kindLabel => switch (kind) {
        'contact' => 'Contact',
        'join' => 'Join us',
        'apply_artist' => 'Artist application',
        'apply_vendor' => 'Vendor application',
        'partner' => 'Partnership',
        'session_register' => 'Session signup',
        _ => 'Lead',
      };

  bool get isApplication => kind == 'apply_artist' || kind == 'apply_vendor';

  factory Lead.fromJson(Map<String, dynamic> j) {
    // Anything that isn't a known column is surfaced as a detail row, so the
    // desk sees the whole submission even when the form grows new fields.
    const known = {
      'id', 'kind', 'name', 'email', 'phone', 'city', 'state',
      'message', 'status', 'created_at', 'createdAt',
    };
    final details = <String, dynamic>{};
    j.forEach((k, v) {
      if (known.contains(k)) return;
      final s = _s(v);
      if (s.isEmpty || s == 'null') return;
      details[k] = v;
    });

    return Lead(
      id: _s(j['id']),
      kind: _s(j['kind']).isEmpty ? 'contact' : _s(j['kind']),
      name: _s(j['name']),
      email: _s(j['email']),
      phone: _s(j['phone']),
      city: _s(j['city']),
      state: _s(j['state']),
      details: details,
      message: _s(j['message']),
      status: _s(j['status']).isEmpty ? 'new' : _s(j['status']),
      createdAt: DateTime.tryParse(_s(j['created_at'] ?? j['createdAt'])),
    );
  }

  Lead copyWith({String? status}) => Lead(
        id: id,
        kind: kind,
        name: name,
        email: email,
        phone: phone,
        city: city,
        state: state,
        details: details,
        message: message,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}

/// ── Social account ──────────────────────────────────────────────
/// "Vendor admin profile managed to social media accounts AOneGo9 — create
/// admin profile section and marketing."
class SocialAccount {
  final String id;
  final String platform;
  final String handle;
  final String url;
  final int followers;
  final bool connected;

  /// Who on the desk owns posting for this account.
  final String owner;

  const SocialAccount({
    required this.id,
    required this.platform,
    this.handle = '',
    this.url = '',
    this.followers = 0,
    this.connected = false,
    this.owner = '',
  });

  factory SocialAccount.fromJson(Map<String, dynamic> j) => SocialAccount(
        id: _s(j['id']),
        platform: _s(j['platform']),
        handle: _s(j['handle']),
        url: _s(j['url']),
        followers: _i(j['followers']),
        connected: j['connected'] == true,
        owner: _s(j['owner']),
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'platform': platform,
        'handle': handle,
        'url': url,
        'followers': followers,
        'connected': connected,
        'owner': owner,
      };
}

/// ── Taxonomy mirrors ────────────────────────────────────────────
/// The user app's divisions and brand divisions, duplicated here so admin
/// forms offer exactly the values the marketplace can render. Keep in step
/// with `aonego9-user/lib/data/taxonomy.dart` and `data/directory.dart`.
const List<({String id, String name, String icon})> adminDivisions = [
  (id: 'talent', name: 'Talent', icon: '✦'),
  (id: 'crew', name: 'Production', icon: '🎬'),
  (id: 'post', name: 'Post & Design', icon: '🖥️'),
  (id: 'beauty', name: 'Hair & Makeup', icon: '💄'),
  (id: 'fashion', name: 'Fashion & Retail', icon: '👗'),
  (id: 'spaces', name: 'Venues', icon: '🏛️'),
  (id: 'hospitality', name: 'Hospitality', icon: '🏨'),
  (id: 'education', name: 'Academy', icon: '🎓'),
];

const List<String> adminBrandDivisions = [
  'Fashion & Apparel',
  'Beauty & Cosmetics',
  'Jewellery & Luxury',
  'Sportswear & Fitness',
  'Media & Entertainment',
  'Hospitality & Travel',
];

const List<String> adminTeamDesks = [
  'Leadership',
  'Casting Desk',
  'Production Desk',
  'Verification',
  'Editorial',
  'Partnerships',
];

String divisionName(String id) =>
    adminDivisions.where((d) => d.id == id).map((d) => d.name).firstOrNull ?? id;
