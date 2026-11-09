import 'package:flutter_test/flutter_test.dart';
import 'package:communal_mobile/data/models/loan_scheme.dart';

void main() {
  Map<String, dynamic> scheme(Map<String, dynamic> extra) => {
        'id': 's1',
        'cooperative_id': 'Dco-8306',
        'title': 'Land Loan',
        'loan_code': 'LON6CBXB',
        'category': '1539',
        ...extra,
      };

  test('a scheme carries the category name the service resolved', () {
    final s = LoanScheme.fromBackend(scheme({'category_label': 'Mid Term Loan'}));
    expect(s.categoryLabel, 'Mid Term Loan');
    expect(s.category, '1539');
  });

  test('a response with no label leaves it empty rather than showing the code', () {
    final s = LoanScheme.fromBackend(scheme({}));
    expect(s.categoryLabel, '');
    expect(s.category, '1539');
  });

  test('a blank label is treated as absent', () {
    final s = LoanScheme.fromBackend(scheme({'category_label': '   '}));
    expect(s.categoryLabel, '');
  });
}
