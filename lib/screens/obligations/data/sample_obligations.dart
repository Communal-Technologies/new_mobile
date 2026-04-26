import 'package:intl/intl.dart';
import 'package:communal_mobile/core/utils/money_formatter.dart';

class PaymentRecord {
  PaymentRecord({
    required this.title,
    required this.date,
    required this.amount,
    required this.method,
    required this.reference,
  });

  final String title;
  final DateTime date;
  final double amount;
  final String method;
  final String reference;

  String get dateLabel => DateFormat('MMM dd, yyyy').format(date);
  String get amountLabel => '₦${_currencyFormat(amount)}';
}

class FineRecord {
  FineRecord({
    required this.amount,
    required this.description,
    required this.status,
    required this.type,
    required this.date,
  });

  final double amount;
  final String description;
  final String status;
  final String type;
  final DateTime date;

  String get amountLabel => '₦${_currencyFormat(amount)}';
  String get dateLabel => DateFormat('MMM dd, yyyy').format(date);
}

class Obligation {
  Obligation({
    this.id,
    this.accountCode = '',
    this.cooperativeId = '',
    this.createdAt,
    this.updatedAt,
    required this.category,
    required this.status,
    required this.title,
    required this.description,
    required this.paidAmount,
    required this.totalAmount,
    required this.perInstallment,
    required this.installmentsPaid,
    required this.totalInstallments,
    required this.startDate,
    required this.endDate,
    required this.nextDueDate,
    required this.frequency,
    required this.payments,
    this.fines = const [],
    this.infoNote,
  });

  final String? id;
  final String accountCode;
  final String cooperativeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String category;
  final String status;
  final String title;
  final String description;
  final double paidAmount;
  final double totalAmount;
  final double perInstallment;
  final int installmentsPaid;
  final int totalInstallments;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime nextDueDate;
  final String frequency;
  final List<PaymentRecord> payments;
  final List<FineRecord> fines;
  final String? infoNote;

  double get balance => (totalAmount - paidAmount).clamp(0, totalAmount);
  double get progress => totalAmount == 0 ? 0 : paidAmount / totalAmount;

  String get progressLabel => '${(progress * 100).toStringAsFixed(0)}%';

  String get amountBreakdown =>
      '₦${_currencyFormat(paidAmount)} of ₦${_currencyFormat(totalAmount)}';

  String get perInstallmentLabel => '₦${_currencyFormat(perInstallment)}';

  String get installmentsLabel =>
      'Installments paid: $installmentsPaid of $totalInstallments';

  String get nextDueDateLabel => DateFormat('MMM dd, yyyy').format(nextDueDate);
  String get startDateLabel => DateFormat('MMM dd, yyyy').format(startDate);
  String get endDateLabel => DateFormat('MMM dd, yyyy').format(endDate);
  String get createdAtLabel =>
      createdAt == null ? 'N/A' : DateFormat('MMM dd, yyyy').format(createdAt!);
  String get updatedAtLabel =>
      updatedAt == null ? 'N/A' : DateFormat('MMM dd, yyyy').format(updatedAt!);

  factory Obligation.fromBackend({
    required Map<String, dynamic> obligation,
    Map<String, dynamic>? account,
  }) {
    final amount = _asDouble(obligation['amount']);
    final amountPaid = _asDouble(obligation['amount_paid']);
    final month = _asInt(obligation['month']);
    final year = _asInt(obligation['year']);
    final now = DateTime.now();
    final dueDate = (month > 0 && year > 0)
        ? DateTime(year, month, 1)
        : DateTime(now.year, now.month, 1);
    final amountMajor = amount / 100;
    final amountPaidMajor = amountPaid / 100;
    final minPayableMajor = _asDouble(account?['min_amount_payable']) / 100;
    final category = _resolveCategory(account?['account_type']?.toString());
    final title = account?['account_name']?.toString().trim().isNotEmpty == true
        ? account!['account_name'].toString()
        : '$category Obligation';
    final status = _resolveStatus(amountPaid: amountPaid, amount: amount, dueDate: dueDate);
    final installmentsPaid =
        amount <= 0 ? 0 : (amountPaid / amount).floor().clamp(0, 9999);

    return Obligation(
      id: obligation['id']?.toString(),
      accountCode: obligation['account_code']?.toString() ?? '',
      cooperativeId: obligation['cooperative_id']?.toString() ?? '',
      createdAt: _parseDate(obligation['created_at']),
      updatedAt: _parseDate(obligation['updated_at']),
      category: category,
      status: status,
      title: title,
      description: account?['account_name']?.toString() ?? 'Member financial obligation',
      paidAmount: amountPaidMajor,
      totalAmount: amountMajor,
      perInstallment: minPayableMajor > 0 ? minPayableMajor : (amountMajor > 0 ? amountMajor : 0),
      installmentsPaid: installmentsPaid,
      totalInstallments: 1,
      startDate: dueDate,
      endDate: dueDate,
      nextDueDate: dueDate,
      frequency: 'Monthly',
      payments: const [],
      fines: const [],
    );
  }

  static String _currencyFormat(double value) {
    return formatMoney(value);
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _resolveCategory(String? accountType) {
    switch ((accountType ?? '').trim()) {
      case '1523':
        return 'Equity';
      case '1524':
        return 'Patronage';
      case '1525':
        return 'Custom';
      default:
        return 'Custom';
    }
  }

  static String _resolveStatus({
    required double amountPaid,
    required double amount,
    required DateTime dueDate,
  }) {
    if (amount > 0 && amountPaid >= amount) return 'Completed';
    if (dueDate.isBefore(DateTime.now())) return 'Overdue';
    return 'Active';
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}

class SampleObligations {
  static final List<Obligation> all = [
    Obligation(
      category: 'Equity',
      status: 'Active',
      title: 'Monthly Contribution',
      description:
          'Monthly equity contribution for cooperative ownership. This helps build the collective capital of the cooperative and increases your stake in shared profits.',
      paidAmount: 300000,
      totalAmount: 500000,
      perInstallment: 50000,
      installmentsPaid: 6,
      totalInstallments: 10,
      startDate: DateTime(2024, 1, 15),
      endDate: DateTime(2024, 10, 15),
      nextDueDate: DateTime(2024, 11, 15),
      frequency: 'Monthly',
      payments: [
        PaymentRecord(
          title: 'Installment #6',
          date: DateTime(2024, 10, 15),
          amount: 50000,
          method: 'Wallet',
          reference: 'REF-2024-001234',
        ),
        PaymentRecord(
          title: 'Installment #5',
          date: DateTime(2024, 9, 15),
          amount: 50000,
          method: 'Bank Transfer',
          reference: 'REF-2024-001187',
        ),
        PaymentRecord(
          title: 'Installment #4',
          date: DateTime(2024, 8, 15),
          amount: 50000,
          method: 'Wallet',
          reference: 'REF-2024-001098',
        ),
      ],
      fines: [
        FineRecord(
          amount: 5000,
          description: 'Late payment - 3 days overdue',
          status: 'pending',
          type: 'Auto charge',
          date: DateTime(2024, 10, 18),
        ),
      ],
      infoNote:
          'Your consistent payments qualify you for cooperative loans at competitive rates.',
    ),
    Obligation(
      category: 'Patronage',
      status: 'Completed',
      title: 'Patronage Dividend',
      description:
          'Returns from the cooperative’s surplus earnings distributed to members based on their patronage.',
      paidAmount: 150000,
      totalAmount: 150000,
      perInstallment: 50000,
      installmentsPaid: 3,
      totalInstallments: 3,
      startDate: DateTime(2024, 3, 1),
      endDate: DateTime(2024, 9, 1),
      nextDueDate: DateTime(2024, 9, 1),
      frequency: 'Quarterly',
      payments: [
        PaymentRecord(
          title: 'Dividend #3',
          date: DateTime(2024, 9, 1),
          amount: 50000,
          method: 'Wallet',
          reference: 'REF-2024-005001',
        ),
        PaymentRecord(
          title: 'Dividend #2',
          date: DateTime(2024, 6, 1),
          amount: 50000,
          method: 'Wallet',
          reference: 'REF-2024-004675',
        ),
        PaymentRecord(
          title: 'Dividend #1',
          date: DateTime(2024, 3, 1),
          amount: 50000,
          method: 'Wallet',
          reference: 'REF-2024-003987',
        ),
      ],
    ),
    Obligation(
      category: 'Fine',
      status: 'Overdue',
      title: 'Late Payment Penalty',
      description:
          'Penalty applied to accounts with overdue installments beyond the grace period.',
      paidAmount: 10000,
      totalAmount: 50000,
      perInstallment: 5000,
      installmentsPaid: 2,
      totalInstallments: 10,
      startDate: DateTime(2024, 7, 1),
      endDate: DateTime(2025, 4, 1),
      nextDueDate: DateTime(2024, 11, 5),
      frequency: 'Monthly',
      payments: [
        PaymentRecord(
          title: 'Penalty Payment #2',
          date: DateTime(2024, 9, 5),
          amount: 5000,
          method: 'Wallet',
          reference: 'REF-2024-009210',
        ),
        PaymentRecord(
          title: 'Penalty Payment #1',
          date: DateTime(2024, 8, 5),
          amount: 5000,
          method: 'Wallet',
          reference: 'REF-2024-009045',
        ),
      ],
      fines: [
        FineRecord(
          amount: 2000,
          description: 'Missed payment fee',
          status: 'pending',
          type: 'Manual',
          date: DateTime(2024, 10, 1),
        ),
      ],
    ),
    Obligation(
      category: 'Custom',
      status: 'Active',
      title: 'Community Development Levy',
      description:
          'Contribution towards community projects including healthcare, education, and infrastructure.',
      paidAmount: 150000,
      totalAmount: 250000,
      perInstallment: 50000,
      installmentsPaid: 3,
      totalInstallments: 5,
      startDate: DateTime(2024, 4, 10),
      endDate: DateTime(2024, 12, 10),
      nextDueDate: DateTime(2024, 11, 20),
      frequency: 'Monthly',
      payments: [
        PaymentRecord(
          title: 'Installment #3',
          date: DateTime(2024, 9, 20),
          amount: 50000,
          method: 'Wallet',
          reference: 'REF-2024-007654',
        ),
        PaymentRecord(
          title: 'Installment #2',
          date: DateTime(2024, 8, 20),
          amount: 50000,
          method: 'Wallet',
          reference: 'REF-2024-007432',
        ),
        PaymentRecord(
          title: 'Installment #1',
          date: DateTime(2024, 7, 20),
          amount: 50000,
          method: 'Wallet',
          reference: 'REF-2024-007210',
        ),
      ],
      infoNote:
          'Keep contributing to stay eligible for community matching grants.',
    ),
  ];
}

String _currencyFormat(double value) {
  final formatter = NumberFormat('#,##0', 'en_NG');
  return formatter.format(value);
}
