import 'package:flutter_test/flutter_test.dart';
import 'package:aonego9_superadmin/data/models/directory_models.dart';

void main() {
  group('AdCreative', () {
    test('CTR is zero rather than NaN on a fresh creative', () {
      const a = AdCreative(id: '1', media: 'photo', headline: 'x');
      expect(a.ctr, 0);
      expect(a.ctr.isNaN, isFalse);
    });

    test('CTR is a percentage', () {
      const a = AdCreative(id: '1', media: 'photo', headline: 'x', impressions: 200, clicks: 10);
      expect(a.ctr, 5);
    });

    test('media is normalised to photo or video only', () {
      expect(AdCreative.fromJson({'id': '1', 'type': 'VIDEO', 'headline': 'h'}).media, 'video');
      expect(AdCreative.fromJson({'id': '1', 'type': 'anything', 'headline': 'h'}).media, 'photo');
      expect(AdCreative.fromJson({'id': '1', 'headline': 'h'}).media, 'photo');
    });

    test('active defaults to true and survives an explicit false', () {
      expect(AdCreative.fromJson({'id': '1', 'headline': 'h'}).active, isTrue);
      expect(AdCreative.fromJson({'id': '1', 'headline': 'h', 'active': false}).active, isFalse);
    });
  });

  group('Session', () {
    test('fillRatio guards a zero capacity', () {
      const s = Session(id: '1', mode: 'workshop', title: 't');
      expect(s.fillRatio, 0);
      expect(s.fillRatio.isNaN, isFalse);
    });

    test('fillRatio reflects seats taken and stays within 0–1', () {
      const s = Session(id: '1', mode: 'workshop', title: 't', seats: 40, seatsLeft: 10);
      expect(s.fillRatio, closeTo(0.75, 0.001));
      // A backend that reports more seats left than exist must not push the
      // progress bar negative.
      const odd = Session(id: '1', mode: 'workshop', title: 't', seats: 10, seatsLeft: 40);
      expect(odd.fillRatio, inInclusiveRange(0.0, 1.0));
    });

    test('soldOut only applies when a capacity was declared', () {
      expect(const Session(id: '1', mode: 'workshop', title: 't').soldOut, isFalse);
      expect(const Session(id: '1', mode: 'workshop', title: 't', seats: 20, seatsLeft: 0).soldOut, isTrue);
    });

    test('mode falls back to workshop', () {
      expect(Session.fromJson({'id': '1', 'title': 't'}).mode, 'workshop');
      expect(Session.fromJson({'id': '1', 'title': 't', 'mode': 'Webinar'}).mode, 'webinar');
    });
  });

  _placeLabelGuards();

  group('Lead', () {
    test('unknown payload keys become visible detail rows', () {
      final l = Lead.fromJson({
        'id': '1',
        'kind': 'apply_artist',
        'name': 'Priya',
        'email': 'p@x.com',
        'portfolio': 'https://x.com',
        'experience': '3–6 years',
      });
      expect(l.details.keys, containsAll(<String>['portfolio', 'experience']));
      // Known columns must not be duplicated into details.
      expect(l.details.containsKey('name'), isFalse);
      expect(l.details.containsKey('email'), isFalse);
    });

    test('blank extras are dropped rather than shown as empty chips', () {
      final l = Lead.fromJson({'id': '1', 'name': 'A', 'business_name': '', 'note': null});
      expect(l.details, isEmpty);
    });

    test('labels every kind the forms can submit', () {
      for (final k in ['contact', 'join', 'apply_artist', 'apply_vendor', 'partner', 'session_register']) {
        final l = Lead.fromJson({'id': '1', 'kind': k, 'name': 'A'});
        expect(l.kindLabel, isNot('Lead'), reason: '$k has no label');
      }
    });

    test('applications are flagged for routing', () {
      expect(Lead.fromJson({'id': '1', 'kind': 'apply_vendor', 'name': 'A'}).isApplication, isTrue);
      expect(Lead.fromJson({'id': '1', 'kind': 'contact', 'name': 'A'}).isApplication, isFalse);
    });

    test('status defaults to new', () {
      expect(Lead.fromJson({'id': '1', 'name': 'A'}).status, 'new');
    });
  });

  group('LogoPartner', () {
    test('tier parses and labels', () {
      expect(LogoPartner.fromJson({'id': '1', 'name': 'N', 'tier': 'academic'}).tier, PartnerTier.academic);
      expect(LogoPartner.fromJson({'id': '1', 'name': 'N', 'tier': 'institutional'}).tierLabel, 'Industry body');
      // Anything unrecognised is a brand, which is the safe default for a wall
      // that is mostly brands.
      expect(LogoPartner.fromJson({'id': '1', 'name': 'N'}).tier, PartnerTier.brand);
    });

    test('published defaults to true', () {
      expect(LogoPartner.fromJson({'id': '1', 'name': 'N'}).published, isTrue);
      expect(LogoPartner.fromJson({'id': '1', 'name': 'N', 'published': false}).published, isFalse);
    });
  });

  group('taxonomy mirrors', () {
    test('division ids are unique and resolvable', () {
      final ids = adminDivisions.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final d in adminDivisions) {
        expect(divisionName(d.id), d.name);
      }
    });

    test('an unknown division id falls back to itself rather than blank', () {
      expect(divisionName('nope'), 'nope');
    });
  });
}

void _placeLabelGuards() {
  group('Session.placeLabel — regression guard', () {
    Session at({String city = '', String state = ''}) =>
        Session(id: '1', mode: 'workshop', title: 't', city: city, state: state);

    test('joins a city and its state', () {
      expect(at(city: 'Mumbai', state: 'Maharashtra').placeLabel, 'Mumbai · Maharashtra');
    });

    test('does not repeat a place that is its own state', () {
      // Regression: rendered "Delhi NCR · Delhi NCR" in the schedule.
      expect(at(city: 'Delhi NCR', state: 'Delhi NCR').placeLabel, 'Delhi NCR');
      expect(at(city: 'Goa', state: 'goa').placeLabel, 'Goa');
    });

    test('an online session shows only Online', () {
      expect(at(city: 'Online', state: 'Maharashtra').placeLabel, 'Online');
    });

    test('a missing state or city degrades cleanly', () {
      expect(at(city: 'Kochi').placeLabel, 'Kochi');
      expect(at().placeLabel, isEmpty);
    });
  });
}
