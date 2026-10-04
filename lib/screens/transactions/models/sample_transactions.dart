// File name kept as `sample_transactions.dart` for the bulk of the
// transaction-history surface that imports from it; the real
// production type here is [TransactionListItem]. The hardcoded
// `SampleTransactions` mock catalog used to live alongside the model
// for early development — it has been removed since no production
// code references it (the history list is served by
// `TransactionsRepository.fetchPersonalHistoryMerged`). When the
// next round of refactoring lands, this file can be renamed to
// `transaction_list_item.dart` and the import updated everywhere.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/screens/transactions/receipt/receipt_status_style.dart';

class TransactionListItem {
  const TransactionListItem({
    required this.details,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  final TransactionDetailsData details;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  static final DateFormat _tileDateFormat = DateFormat('MMM dd, yyyy · h:mm a');

  bool get isCredit => details.isIncoming;

  String get subtitle => _tileDateFormat.format(details.dateTime);

  String get signedAmountLabel {
    if (details.status == TransactionStatus.failed) {
      return details.amountLabel;
    }
    return '${isCredit ? '+' : '-'}${details.amountLabel}';
  }

  /// Green/red state a debit or credit that has actually happened. A pending
  /// transfer has not moved anyone's money yet, so it carries the same warning
  /// colour the receipt uses for that status rather than claiming an outcome.
  Color get amountColor {
    switch (details.status) {
      case TransactionStatus.failed:
        return Colors.grey.shade700;
      case TransactionStatus.pending:
        return const Color(0xFFE6A502);
      case TransactionStatus.successful:
        return isCredit ? const Color(0xFF1AAE70) : const Color(0xFFD7263D);
    }
  }

  /// Human status word ("Successful"/"Pending"/"Failed"), shown in place of the
  /// amount on the dashboard when balances are hidden. Single-sourced from the
  /// receipt's status style so the wording never drifts from the receipt.
  String get statusLabel => ReceiptStatusStyle(status: details.status).statusLabel;

  /// Colour for [statusLabel] — the receipt's canonical status coding: green
  /// successful, amber pending, red failed. Independent of credit/debit direction,
  /// which the hidden amount is not revealing.
  Color get statusColor => ReceiptStatusStyle(status: details.status).statusColor;
}

