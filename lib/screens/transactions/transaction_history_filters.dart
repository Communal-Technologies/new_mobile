import 'package:communal_mobile/screens/transactions/models/sample_transactions.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';

/// User-confirmed statement window + delivery choices.
class StatementExportRequest {
  const StatementExportRequest({
    required this.startInclusive,
    required this.endInclusive,
    required this.delivery,
    required this.formatLabel,
    this.email,
  });

  final DateTime startInclusive;
  final DateTime endInclusive;
  final String delivery;
  final String formatLabel;
  final String? email;
}

/// Map period chip label to [start, end] inclusive (local calendar days).
(DateTime start, DateTime end) statementRangeForPeriodChip(String label) {
  final now = DateTime.now();
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  switch (label) {
    case 'Last Week':
      final s = now.subtract(const Duration(days: 7));
      return (
        DateTime(s.year, s.month, s.day),
        end,
      );
    case 'Last Month':
      final s = now.subtract(const Duration(days: 30));
      return (
        DateTime(s.year, s.month, s.day),
        end,
      );
    case 'Last 3 Months':
      final s = now.subtract(const Duration(days: 90));
      return (
        DateTime(s.year, s.month, s.day),
        end,
      );
    default:
      final s = now.subtract(const Duration(days: 7));
      return (
        DateTime(s.year, s.month, s.day),
        end,
      );
  }
}

/// Result when user confirms category / payment filters.
class CategoryFilterResult {
  const CategoryFilterResult({
    required this.direction,
    required this.paymentType,
  });

  /// `All`, `Money In`, or `Money Out`.
  final String direction;

  /// e.g. `All Categories`, `Transfers`, …
  final String paymentType;
}

bool _statusMatches(TransactionDetailsData d, String statusLabel) {
  switch (statusLabel) {
    case 'All Status':
      return true;
    case 'Successful':
      return d.status == TransactionStatus.successful;
    case 'Pending':
      return d.status == TransactionStatus.pending;
    case 'Failed':
      return d.status == TransactionStatus.failed;
    default:
      return true;
  }
}

bool _directionMatches(TransactionListItem t, String direction) {
  switch (direction) {
    case 'All':
      return true;
    case 'Money In':
      return t.isCredit;
    case 'Money Out':
      return !t.isCredit;
    default:
      return true;
  }
}

bool _paymentTypeMatches(TransactionListItem t, String paymentType) {
  if (paymentType == 'All Categories') return true;
  final type = t.details.transactionType.toLowerCase();
  final title = t.title.toLowerCase();
  final hay = '$type $title';
  switch (paymentType) {
    case 'Transfers':
      return hay.contains('transfer') ||
          hay.contains('nip') ||
          hay.contains('book');
    case 'Contributions':
      return hay.contains('contribution') || hay.contains('cooperative');
    case 'Loans':
      return hay.contains('loan');
    case 'Interest Earned':
      return hay.contains('interest');
    case 'Withdrawals':
      return hay.contains('withdraw');
    case 'Bill Payments':
      return hay.contains('bill') || hay.contains('electric');
    case 'Savings':
      return hay.contains('saving');
    default:
      return true;
  }
}

List<TransactionListItem> applyTransactionHistoryFilters(
  List<TransactionListItem> items, {
  required String direction,
  required String paymentType,
  required String statusLabel,
}) {
  return items.where((t) {
    return _directionMatches(t, direction) &&
        _paymentTypeMatches(t, paymentType) &&
        _statusMatches(t.details, statusLabel);
  }).toList(growable: false);
}

String buildTransactionStatementCsv({
  required List<TransactionListItem> items,
  required String currencySymbol,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  String accountLabel = 'Wallet',
}) {
  final buf = StringBuffer();
  buf.writeln(
    'Communal transaction statement ($accountLabel); '
    'from ${rangeStart.toIso8601String().split('T').first} '
    'to ${rangeEnd.toIso8601String().split('T').first}',
  );
  buf.writeln(
    'Date,Description,Category,Status,Direction,Amount ($currencySymbol),Reference',
  );
  final startDay = DateTime(
    rangeStart.year,
    rangeStart.month,
    rangeStart.day,
  );
  final endDay = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
  final inRange = items.where((t) {
    final d = t.details.dateTime;
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(startDay) && !day.isAfter(endDay);
  }).toList()
    ..sort((a, b) => b.details.dateTime.compareTo(a.details.dateTime));

  for (final t in inRange) {
    final d = t.details;
    final dir = d.isIncoming ? 'In' : 'Out';
    final status = switch (d.status) {
      TransactionStatus.successful => 'Successful',
      TransactionStatus.pending => 'Pending',
      TransactionStatus.failed => 'Failed',
    };
    final amount = '${d.isIncoming ? '' : '-'}${formatMoneyForCsv(d.amount)}';
    buf.writeln(
      [
        d.dateTime.toIso8601String(),
        _csvEscape(t.title),
        _csvEscape(d.transactionType),
        status,
        dir,
        amount,
        _csvEscape(d.reference),
      ].join(','),
    );
  }
  return buf.toString();
}

String formatMoneyForCsv(double amount) {
  final s = amount.toStringAsFixed(2);
  return s;
}

String _csvEscape(String s) {
  final t = s.replaceAll('"', '""');
  if (t.contains(',') || t.contains('\n') || t.contains('"')) {
    return '"$t"';
  }
  return t;
}
