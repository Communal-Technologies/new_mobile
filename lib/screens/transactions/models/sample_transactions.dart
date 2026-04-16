import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';

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

  String get signedAmountLabel =>
      '${isCredit ? '+' : '-'}${details.amountLabel}';

  Color get amountColor =>
      isCredit ? const Color(0xFF1AAE70) : const Color(0xFFD7263D);
}

class SampleTransactions {
  SampleTransactions._();

  static final LinkedHashMap<String, List<TransactionListItem>>
  transactionsByMonth = LinkedHashMap.from({
    'October 2025': [
      _buildItem(
        title: 'Cooperative Contribution',
        dateTime: DateTime(2025, 10, 18, 6, 40),
        amount: 50000,
        isIncoming: true,
        icon: Icons.people,
        iconColor: Colors.white,
        iconBgColor: const Color(0xFF742CE7),
        reference: 'TRF25101806401',
      ),
      _buildItem(
        title: 'Loan Disbursement',
        dateTime: DateTime(2025, 10, 16, 10, 12),
        amount: 120000,
        isIncoming: true,
        icon: Icons.account_balance_wallet,
        iconColor: Colors.white,
        iconBgColor: const Color(0xFF4CAF50),
        reference: 'TRF25101610120',
      ),
      _buildItem(
        title: 'Transfer to Mary John',
        dateTime: DateTime(2025, 10, 15, 14, 30),
        amount: 5000,
        isIncoming: false,
        icon: Icons.send,
        iconColor: const Color(0xFF742CE7),
        iconBgColor: const Color(0xFFF0E6FF),
        reference: 'TRF25101514300',
        counterpartyName: 'Mary John',
      ),
      _buildItem(
        title: 'Loan Payment',
        dateTime: DateTime(2025, 10, 12, 9, 45),
        amount: 15000,
        isIncoming: true,
        icon: Icons.people_outline,
        iconColor: const Color(0xFF00BCD4),
        iconBgColor: const Color(0xFFE0F7FA),
        reference: 'TRF25101209450',
      ),
    ],
    'September 2025': [
      _buildItem(
        title: 'Bill Payment - Electricity',
        dateTime: DateTime(2025, 9, 27, 11, 10),
        amount: 15000,
        isIncoming: false,
        icon: Icons.flash_on,
        iconColor: Colors.white,
        iconBgColor: Colors.orange,
        reference: 'TRF25092711100',
        counterpartyName: 'Electric Utility',
      ),
      _buildItem(
        title: 'Interest Earned',
        dateTime: DateTime(2025, 9, 20, 8, 0),
        amount: 1274,
        isIncoming: true,
        icon: Icons.trending_up,
        iconColor: Colors.white,
        iconBgColor: const Color(0xFF00BCD4),
        reference: 'TRF25092008000',
      ),
      _buildItem(
        title: 'Savings Deposit',
        dateTime: DateTime(2025, 9, 10, 17, 20),
        amount: 100000,
        isIncoming: false,
        icon: Icons.account_balance_wallet,
        iconColor: Colors.white,
        iconBgColor: const Color(0xFF742CE7),
        reference: 'TRF25091017200',
      ),
    ],
  });

  static List<TransactionListItem> get recentTransactions {
    final list = transactionsByMonth.values.expand((e) => e).toList();
    list.sort((a, b) => b.details.dateTime.compareTo(a.details.dateTime));
    return list;
  }

  static TransactionListItem _buildItem({
    required String title,
    required DateTime dateTime,
    required double amount,
    required bool isIncoming,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String reference,
    String counterpartyName = 'Hosanna Baridule',
    String counterpartyBank = 'GT Bank',
  }) {
    final sessionFormat = DateFormat('hh:mm a');

    final details = TransactionDetailsData(
      id: reference,
      counterpartyName: counterpartyName,
      counterpartyBank: counterpartyBank,
      counterpartyAccount: '2012112124',
      amount: amount,
      fees: 0,
      currencySymbol: '₦',
      transactionType: title,
      dateTime: dateTime,
      sessionId: sessionFormat.format(dateTime),
      description: title,
      reference: reference,
      paymentMethod: 'Wallet',
      status: TransactionStatus.successful,
      isIncoming: isIncoming,
      note:
          'This is a computer generated receipt and does not require a signature.',
    );

    return TransactionListItem(
      details: details,
      title: title,
      icon: icon,
      iconColor: iconColor,
      iconBgColor: iconBgColor,
    );
  }
}
