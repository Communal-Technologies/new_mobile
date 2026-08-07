import 'package:communal_mobile/core/services/transaction_activity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('describesMovement', () {
    // These are the exact `type` values txnsvc sends on its debit and credit
    // alerts. If they drift apart, the home screen silently stops refreshing on
    // a deposit — the original bug.
    test('matches the alert types txnsvc sends', () {
      expect(
        TransactionActivityService.describesMovement({'type': 'transaction'}),
        isTrue,
      );
      expect(
        TransactionActivityService.describesMovement({
          'type': 'transaction-receipt',
        }),
        isTrue,
      );
    });

    test('matches the legacy route key the monolith sends', () {
      expect(
        TransactionActivityService.describesMovement({
          'route': 'transaction-receipt',
        }),
        isTrue,
      );
    });

    test('ignores pushes about anything other than money moving', () {
      expect(
        TransactionActivityService.describesMovement({'type': 'obligation'}),
        isFalse,
      );
      expect(
        TransactionActivityService.describesMovement({'type': 'loan'}),
        isFalse,
      );
      // The value txnsvc used to send, which the app never matched.
      expect(
        TransactionActivityService.describesMovement({
          'type': 'transaction_alert',
        }),
        isFalse,
      );
      expect(TransactionActivityService.describesMovement({}), isFalse);
    });

    test('tolerates padding and non-string values', () {
      expect(
        TransactionActivityService.describesMovement({
          'type': '  transaction  ',
        }),
        isTrue,
      );
      expect(
        TransactionActivityService.describesMovement({'type': 42}),
        isFalse,
      );
      expect(
        TransactionActivityService.describesMovement({'type': null}),
        isFalse,
      );
    });
  });

  group('ping', () {
    test('notifies listeners on every movement', () {
      final service = TransactionActivityService();
      var notifications = 0;
      service.revision.addListener(() => notifications++);

      service.ping();
      service.ping();

      expect(notifications, 2);
    });

    test('changes value each time so repeat deposits both register', () {
      final service = TransactionActivityService();
      final first = service.revision.value;
      service.ping();
      final second = service.revision.value;
      service.ping();

      expect(second, isNot(first));
      expect(service.revision.value, isNot(second));
    });
  });
}
