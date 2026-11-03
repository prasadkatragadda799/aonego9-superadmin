import 'package:flutter_test/flutter_test.dart';
import 'package:aonego9_superadmin/data/models/models.dart';

void main() {
  group('PaymentTxn', () {
    test('ledger rows keep their booking as the reference', () {
      final p = PaymentTxn.fromJson({
        'id': 'P1', 'booking_id': 'B-1', 'party': 'Meera', 'type': 'Commission',
        'amount': 4800, 'status': 'paid', 'method': 'Platform', 'date': '2026-11-03T10:00:00Z',
      });
      expect(p.reference, 'B-1');
      expect(p.type, 'commission');
      expect(p.status, PaymentStatus.paid);
    });

    test('payouts have no booking reference', () {
      final p = PaymentTxn.fromJson({'id': 'P2', 'booking_id': null, 'type': 'payout', 'amount': 100, 'status': 'payout'});
      expect(p.reference, isEmpty);
      expect(p.status, PaymentStatus.payout);
    });
  });
}
