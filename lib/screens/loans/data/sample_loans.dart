import 'package:intl/intl.dart';

class Loan {
  Loan({
    required this.id,
    required this.title,
    required this.loanId,
    required this.status,
    required this.balance,
    required this.nextPayment,
    required this.dueDate,
    required this.repaymentProgress,
    required this.totalAmount,
    required this.interestRate,
    required this.termMonths,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String title;
  final String loanId;
  final String status;
  final double balance;
  final double nextPayment;
  final DateTime dueDate;
  final double repaymentProgress; // 0.0 to 1.0
  final double totalAmount;
  final double interestRate;
  final int termMonths;
  final DateTime startDate;
  final DateTime endDate;

  String get balanceLabel => '₦${_currencyFormat(balance)}';
  String get nextPaymentLabel => '₦${_currencyFormat(nextPayment)}';
  String get dueDateLabel => DateFormat('MMM dd').format(dueDate);
  String get progressLabel => '${(repaymentProgress * 100).toStringAsFixed(0)}%';

  static String _currencyFormat(double value) {
    final formatter = NumberFormat('#,##0', 'en_NG');
    return formatter.format(value);
  }
}

class LoanOffer {
  LoanOffer({
    required this.id,
    required this.title,
    required this.badge,
    required this.description,
    required this.maxAmount,
    required this.interestRate,
    required this.maxTermMonths,
  });

  final String id;
  final String title;
  final String badge;
  final String description;
  final double maxAmount;
  final double interestRate;
  final int maxTermMonths;

  String get maxAmountLabel => '₦${_currencyFormat(maxAmount)}';
  String get interestRateLabel => '${interestRate.toStringAsFixed(0)}% interest';

  static String _currencyFormat(double value) {
    final formatter = NumberFormat('#,##0', 'en_NG');
    return formatter.format(value);
  }
}

class LoanEligibility {
  LoanEligibility({
    required this.score,
    required this.rating,
    required this.communityName,
  });

  final int score; // 0-100
  final String rating; // "Excellent", "Good", etc.
  final String communityName;

  String get scoreLabel => score.toString();
}

class SampleLoans {
  static final LoanEligibility eligibility = LoanEligibility(
    score: 85,
    rating: 'Excellent',
    communityName: 'Total Lenders Forum',
  );

  static final List<Loan> activeLoans = [
    Loan(
      id: 'loan-1',
      title: 'Business Equipment Loan',
      loanId: 'LN-2024-001234',
      status: 'Active',
      balance: 300000,
      nextPayment: 41667,
      dueDate: DateTime(2024, 11, 20),
      repaymentProgress: 0.40,
      totalAmount: 500000,
      interestRate: 12.0,
      termMonths: 12,
      startDate: DateTime(2024, 8, 1),
      endDate: DateTime(2025, 8, 1),
    ),
    Loan(
      id: 'loan-2',
      title: 'Personal Emergency Loan',
      loanId: 'LN-2024-001189',
      status: 'Active',
      balance: 125000,
      nextPayment: 20833,
      dueDate: DateTime(2024, 11, 25),
      repaymentProgress: 0.50,
      totalAmount: 250000,
      interestRate: 15.0,
      termMonths: 12,
      startDate: DateTime(2024, 7, 1),
      endDate: DateTime(2025, 7, 1),
    ),
  ];

  static final List<LoanOffer> availableOffers = [
    LoanOffer(
      id: 'offer-1',
      title: 'Quick Cash Loan',
      badge: 'Pre-approved',
      description: 'Get up to ₦500,000 instantly',
      maxAmount: 500000,
      interestRate: 10.0,
      maxTermMonths: 12,
    ),
  ];
}

