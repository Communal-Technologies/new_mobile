import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money_formatter.dart';

enum TransactionStatus { successful, pending, failed }

TransactionStatus transactionStatusFromApi(String? raw) {
  switch ((raw ?? '').toUpperCase().trim()) {
    case 'SUCCESSFUL':
    case 'SUCCESS':
    case 'COMPLETED':
    case 'RECEIVED':
    case 'SETTLED':
      return TransactionStatus.successful;
    case 'FAILED':
    case 'ERROR':
    case 'REJECTED':
      return TransactionStatus.failed;
    default:
      return TransactionStatus.pending;
  }
}

@immutable
class TransactionDetailsData {
  const TransactionDetailsData({
    required this.id,
    required this.counterpartyName,
    required this.counterpartyBank,
    required this.amount,
    required this.currencySymbol,
    required this.transactionType,
    required this.dateTime,
    required this.sessionId,
    required this.reference,
    required this.description,
    required this.paymentMethod,
    required this.fees,
    this.counterpartyAccount,
    this.note,
    this.failureReason,
    this.status = TransactionStatus.successful,
    this.isIncoming = true,
    this.bankLogoAsset,
  });

  final String id;
  final String counterpartyName;
  final String counterpartyBank;
  final String? counterpartyAccount;
  final double amount;
  final double fees;
  final String currencySymbol;
  final String transactionType;
  final DateTime dateTime;
  final String sessionId;
  final String description;
  final String reference;
  final String paymentMethod;
  final TransactionStatus status;
  final bool isIncoming;
  final String? bankLogoAsset;
  final String? note;
  /// Provider reason when status is failed (e.g. INSUFFICIENT_BALANCE).
  final String? failureReason;

  String get amountLabel => '$currencySymbol${formatMoney(amount)}';

  String get feesLabel => '$currencySymbol${formatMoney(fees)}';

  String get counterpartLabel => isIncoming ? 'Received from' : 'Sent to';

  String get counterpartyBankLine {
    if (counterpartyAccount == null || counterpartyAccount!.isEmpty) {
      return counterpartyBank;
    }
    return '$counterpartyBank | $counterpartyAccount';
  }

  String get formattedDate {
    final formatter = DateFormat('hh:mm a, MMM dd, yyyy');
    return formatter.format(dateTime).toUpperCase();
  }

  TransactionDetailsData copyWith({
    String? id,
    String? counterpartyName,
    String? counterpartyBank,
    String? counterpartyAccount,
    double? amount,
    double? fees,
    String? currencySymbol,
    String? transactionType,
    DateTime? dateTime,
    String? sessionId,
    String? reference,
    String? description,
    String? paymentMethod,
    TransactionStatus? status,
    bool? isIncoming,
    String? bankLogoAsset,
    String? note,
    String? failureReason,
    bool clearFailureReason = false,
  }) {
    return TransactionDetailsData(
      id: id ?? this.id,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      counterpartyBank: counterpartyBank ?? this.counterpartyBank,
      counterpartyAccount: counterpartyAccount ?? this.counterpartyAccount,
      amount: amount ?? this.amount,
      fees: fees ?? this.fees,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      transactionType: transactionType ?? this.transactionType,
      dateTime: dateTime ?? this.dateTime,
      sessionId: sessionId ?? this.sessionId,
      reference: reference ?? this.reference,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      isIncoming: isIncoming ?? this.isIncoming,
      bankLogoAsset: bankLogoAsset ?? this.bankLogoAsset,
      note: note ?? this.note,
      failureReason: clearFailureReason
          ? null
          : (failureReason ?? this.failureReason),
    );
  }
}

final TransactionDetailsData kSampleTransactionDetails = TransactionDetailsData(
  id: 'TRF25101806401',
  counterpartyName: 'Hosanna Baridule',
  counterpartyBank: 'GT Bank',
  counterpartyAccount: '2012112124',
  amount: 50000.0,
  fees: 0.0,
  currencySymbol: currencySymbolForCode('NGN'),
  transactionType: 'Cooperative Contribution',
  dateTime: DateTime(2025, 10, 18, 6, 40),
  sessionId: '06:40 AM',
  description: 'Cooperative Contribution',
  reference: 'TRF25101806401',
  paymentMethod: 'Wallet',
  status: TransactionStatus.successful,
  isIncoming: true,
  note:
      'This is a computer generated receipt and does not require a signature.',
  failureReason: null,
);
