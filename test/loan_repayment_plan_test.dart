import 'package:communal_mobile/data/models/loan_scheme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Instalments loans-svc builds for ₦500,000 at 18% over 12 months, first
/// repayment 2 months after a 31 Jan 2026 disbursement, interest held back for 4:
/// [due date, principal kobo, interest kobo].
const _fromService = <String, List<List<Object>>>{
  '': [
    ['2026-03-31', 3834000, 750000], ['2026-04-30', 3891510, 692490],
    ['2026-05-31', 3949883, 634117], ['2026-06-30', 4009131, 574869],
    ['2026-07-31', 4069268, 514732], ['2026-08-31', 4130307, 453693],
    ['2026-09-30', 4192261, 391739], ['2026-10-31', 4255145, 328855],
    ['2026-11-30', 4318973, 265027], ['2026-12-31', 4383757, 200243],
    ['2027-01-31', 4449514, 134486], ['2027-02-28', 4516251, 67744],
  ],
  kDeferralInterestFree: [
    ['2026-03-31', 4166666, 0], ['2026-04-30', 4166666, 0],
    ['2026-05-31', 4166666, 0], ['2026-06-30', 4166666, 0],
    ['2026-07-31', 3952801, 500000], ['2026-08-31', 4012093, 440708],
    ['2026-09-30', 4072274, 380527], ['2026-10-31', 4133358, 319443],
    ['2026-11-30', 4195359, 257442], ['2026-12-31', 4258289, 194512],
    ['2027-01-31', 4322164, 130637], ['2027-02-28', 4386998, 65805],
  ],
  kDeferralCollectLater: [
    ['2026-03-31', 4166666, 0], ['2026-04-30', 4166666, 0],
    ['2026-05-31', 4166666, 0], ['2026-06-30', 4166666, 0],
    ['2026-07-31', 4166666, 626000], ['2026-08-31', 4166666, 626000],
    ['2026-09-30', 4166666, 626000], ['2026-10-31', 4166666, 626000],
    ['2026-11-30', 4166666, 626000], ['2026-12-31', 4166666, 626000],
    ['2027-01-31', 4166666, 626000], ['2027-02-28', 4166674, 626000],
  ],
  kDeferralPrincipalFirst: [
    ['2026-03-31', 12500000, 0], ['2026-04-30', 12500000, 0],
    ['2026-05-31', 12500000, 0], ['2026-06-30', 12500000, 0],
    ['2026-07-31', 0, 626000], ['2026-08-31', 0, 626000],
    ['2026-09-30', 0, 626000], ['2026-10-31', 0, 626000],
    ['2026-11-30', 0, 626000], ['2026-12-31', 0, 626000],
    ['2027-01-31', 0, 626000], ['2027-02-28', 0, 626000],
  ],
};

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  for (final entry in _fromService.entries) {
    test('matches the service schedule for "${entry.key}"', () {
      final plan = planRepayments(
        principalMinor: 50000000,
        months: 12,
        annualRate: 18,
        firstDueAfterMonths: 2,
        deferralMode: entry.key.isEmpty ? null : entry.key,
        deferralMonths: 4,
        start: DateTime(2026, 1, 31),
      );
      expect(
        [for (final i in plan) [_day(i.dueDate), i.principalMinor, i.interestMinor]],
        entry.value,
      );
    });
  }
}
