import 'package:intl/intl.dart';

import 'package:communal_mobile/core/utils/money.dart';

/// One row in an obligation's payment history. Amounts are integer minor
/// units of [currency] (kobo for NGN, cents for USD…) — same convention as
/// the backend ledger and the cooperative dashboard.
class PaymentRecord {
  PaymentRecord({
    required this.title,
    required this.date,
    required this.amountMinor,
    required this.currency,
    required this.method,
    required this.reference,
    this.isOutflow = false,
  });

  final String title;
  final DateTime date;
  final int amountMinor;
  final String currency;
  final String method;
  final String reference;

  /// True when this row represents money leaving the obligation (i.e. the
  /// obligation was used as a *source* to pay another). Inflows from
  /// wallet, NIP transfer, etc. set this to false. Drives the sign on
  /// the formatted amount and is what tells the obligation-detail screen
  /// to render the row in the outflow palette.
  final bool isOutflow;

  String get dateLabel => DateFormat('MMM dd, yyyy').format(date);

  /// Signed, currency-symbol-prefixed amount label (e.g. `-₦5,000.00`).
  String get amountLabel {
    final formatted = Money(amountMinor, currency).format();
    return isOutflow ? '-$formatted' : formatted;
  }
}

/// Late-payment / penalty entry attached to an obligation. The backend
/// today does not yet populate this list — the structure exists so the
/// auto-fine cron (see `StartCommunalJobs`) can wire its output through
/// without UI changes when it ships.
class FineRecord {
  FineRecord({
    this.id = '',
    required this.amountMinor,
    this.amountPaidMinor = 0,
    required this.currency,
    required this.description,
    required this.status,
    required this.type,
    required this.date,
  });

  final String id;
  final int amountMinor;
  final int amountPaidMinor;
  final String currency;
  final String description;
  final String status;
  final String type;
  final DateTime date;

  int get outstandingMinor {
    final rem = amountMinor - amountPaidMinor;
    return rem < 0 ? 0 : rem;
  }

  bool get isPending => status.toLowerCase() == 'pending';

  String get amountLabel => Money(amountMinor, currency).format();
  String get outstandingLabel => Money(outstandingMinor, currency).format();
  String get dateLabel => DateFormat('MMM dd, yyyy').format(date);
}

/// Member-facing financial obligation. Money is stored as integer minor
/// units (kobo for NGN); use [Money] / `format*` helpers to display.
class Obligation {
  Obligation({
    this.id,
    this.accountCode = '',
    this.cooperativeId = '',
    this.currency = 'NGN',
    this.createdAt,
    this.updatedAt,
    required this.category,
    required this.status,
    required this.title,
    required this.description,
    required this.paidAmountMinor,
    required this.totalAmountMinor,
    required this.perInstallmentMinor,
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
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String category;
  final String status;
  final String title;
  final String description;
  final int paidAmountMinor;
  final int totalAmountMinor;
  final int perInstallmentMinor;
  final int installmentsPaid;
  final int totalInstallments;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime nextDueDate;
  final String frequency;
  final List<PaymentRecord> payments;
  final List<FineRecord> fines;
  final String? infoNote;

  int get balanceMinor {
    final remaining = totalAmountMinor - paidAmountMinor;
    if (remaining < 0) return 0;
    if (remaining > totalAmountMinor) return totalAmountMinor;
    return remaining;
  }

  double get progress =>
      totalAmountMinor == 0 ? 0 : paidAmountMinor / totalAmountMinor;

  String get progressLabel => '${(progress * 100).toStringAsFixed(0)}%';

  String get paidAmountLabel => Money(paidAmountMinor, currency).format();
  String get totalAmountLabel => Money(totalAmountMinor, currency).format();
  String get balanceLabel => Money(balanceMinor, currency).format();
  String get perInstallmentLabel =>
      Money(perInstallmentMinor, currency).format();

  String get amountBreakdown => '$paidAmountLabel of $totalAmountLabel';

  String get installmentsLabel =>
      'Installments paid: $installmentsPaid of $totalInstallments';

  /// Minimal instance for success / receipt flows that only need title +
  /// category. Everything else is zeroed out — callers should not read
  /// money fields off this.
  factory Obligation.forSuccessSummary({
    required String title,
    required String category,
    String currency = 'NGN',
  }) {
    final now = DateTime.now();
    return Obligation(
      currency: currency,
      category: category,
      status: 'Completed',
      title: title,
      description: '',
      paidAmountMinor: 0,
      totalAmountMinor: 0,
      perInstallmentMinor: 0,
      installmentsPaid: 0,
      totalInstallments: 0,
      startDate: now,
      endDate: now,
      nextDueDate: now,
      frequency: '',
      payments: const [],
    );
  }

  String get nextDueDateLabel => DateFormat('MMM dd, yyyy').format(nextDueDate);
  String get startDateLabel => DateFormat('MMM dd, yyyy').format(startDate);
  String get endDateLabel => DateFormat('MMM dd, yyyy').format(endDate);
  String get createdAtLabel =>
      createdAt == null ? 'N/A' : DateFormat('MMM dd, yyyy').format(createdAt!);
  String get updatedAtLabel =>
      updatedAt == null ? 'N/A' : DateFormat('MMM dd, yyyy').format(updatedAt!);

  /// Build from the backend `financial_obligations` row plus the matching
  /// `internal_accounts` row. Money columns on both tables are integer
  /// minor units (see the `FinancialObligation` and `InternalAccount`
  /// Eloquent models — `cast: integer` with the comment "Integer minor
  /// units of `currency`"). We keep them in minor units here so display
  /// and arithmetic stay on integers, mirroring the dashboard's
  /// `convertMinorToMajor` boundary.
  factory Obligation.fromBackend({
    required Map<String, dynamic> obligation,
    Map<String, dynamic>? account,
    String? fallbackCurrency,
  }) {
    final amountMinor = _asInt(obligation['amount']);
    final amountPaidMinor = _asInt(obligation['amount_paid']);
    final month = _asInt(obligation['month']);
    final year = _asInt(obligation['year']);
    final now = DateTime.now();
    final createdAt = _parseDate(obligation['created_at']);
    final hasPeriod = month > 0 && year > 0;
    // First day of the obligation period — i.e. the month this row is FOR.
    final periodStart = hasPeriod
        ? DateTime(year, month, 1)
        : DateTime(
            createdAt?.year ?? now.year,
            createdAt?.month ?? now.month,
            createdAt?.day ?? 1,
          );
    // The card's "Next Due" should show the upcoming payment cycle —
    // i.e. the FIRST OF THE FOLLOWING MONTH, not the start of the
    // current period. e.g. an April 2026 obligation rolls into a
    // May 1 due date for the next payment window.
    final nextCycle = DateTime(periodStart.year, periodStart.month + 1, 1);
    final minPayableMinor = _asInt(account?['min_amount_payable']);
    final totalShares = _asInt(account?['total_shares']);
    final costPerShareMinor = _asInt(account?['cost_per_share']);
    final accountType = account?['account_type']?.toString();
    final category = _resolveCategory(accountType);
    final title = account?['account_name']?.toString().trim().isNotEmpty == true
        ? account!['account_name'].toString()
        : '$category Obligation';
    final status = _resolveStatus(
      paidMinor: amountPaidMinor,
      totalMinor: amountMinor,
      dueDate: nextCycle,
      category: category,
    );

    var totalInstallments = 1;
    if (totalShares > 0) {
      totalInstallments = totalShares.clamp(1, 9999);
    } else if (minPayableMinor > 0 && amountMinor > 0) {
      totalInstallments =
          (amountMinor / minPayableMinor).ceil().clamp(1, 9999);
    }

    // Equity rows are share-priced — `cost_per_share` is the unit, not
    // `min_amount_payable`. Old logic preferred minPayable across all
    // categories, which made installmentsPaid wrong whenever both
    // values were sent for an equity row.
    int perInstallmentMinor;
    if (category == 'Equity' && costPerShareMinor > 0) {
      perInstallmentMinor = costPerShareMinor;
    } else if (minPayableMinor > 0) {
      perInstallmentMinor = minPayableMinor;
    } else if (totalShares > 0 && costPerShareMinor > 0) {
      perInstallmentMinor = costPerShareMinor;
    } else if (totalInstallments > 0 && amountMinor > 0) {
      perInstallmentMinor = (amountMinor / totalInstallments).round();
    } else {
      perInstallmentMinor = amountMinor > 0 ? amountMinor : 0;
    }

    var installmentsPaid = 0;
    if (perInstallmentMinor > 0) {
      installmentsPaid = (amountPaidMinor / perInstallmentMinor).floor();
    } else if (amountMinor > 0) {
      installmentsPaid = (amountPaidMinor / amountMinor).floor();
    }
    installmentsPaid = installmentsPaid.clamp(0, totalInstallments);

    final startDate = createdAt != null
        ? DateTime(createdAt.year, createdAt.month, createdAt.day)
        : periodStart;

    final currency = (obligation['currency']?.toString().trim().isNotEmpty == true
            ? obligation['currency'].toString()
            : (fallbackCurrency ?? 'NGN'))
        .toUpperCase();

    return Obligation(
      id: obligation['id']?.toString(),
      accountCode: obligation['account_code']?.toString() ?? '',
      cooperativeId: obligation['cooperative_id']?.toString() ?? '',
      currency: currency,
      createdAt: createdAt,
      updatedAt: _parseDate(obligation['updated_at']),
      category: category,
      status: status,
      title: title,
      description:
          account?['account_name']?.toString() ?? 'Member financial obligation',
      paidAmountMinor: amountPaidMinor,
      totalAmountMinor: amountMinor,
      perInstallmentMinor: perInstallmentMinor,
      installmentsPaid: installmentsPaid,
      totalInstallments: totalInstallments,
      startDate: startDate,
      endDate: nextCycle,
      // Next due = first of the month after the obligation period, so
      // an April 2026 row reads "next due May 1, 2026".
      nextDueDate: nextCycle,
      frequency: 'Monthly',
      payments: const [],
      fines: parseFines(obligation['fines'], currency),
    );
  }

  static List<FineRecord> parseFines(dynamic raw, String fallbackCurrency) {
    if (raw is! List) return const [];
    final out = <FineRecord>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final m = Map<String, dynamic>.from(entry);
      final amount = _asInt(m['amount']);
      if (amount <= 0) continue;
      final currency =
          (m['currency']?.toString().trim().isNotEmpty == true
                  ? m['currency'].toString()
                  : fallbackCurrency)
              .toUpperCase();
      final source = m['source']?.toString() ?? 'auto';
      final description = m['description']?.toString().trim() ?? '';
      final status = m['status']?.toString().trim();
      final date = _parseDate(m['created_at']) ??
          _parseDate(m['due_date']) ??
          DateTime.now();
      out.add(FineRecord(
        id: m['id']?.toString() ?? '',
        amountMinor: amount,
        amountPaidMinor: _asInt(m['amount_paid']),
        currency: currency,
        description: description.isEmpty ? 'Late payment fine' : description,
        status: (status == null || status.isEmpty) ? 'pending' : status,
        type: source == 'auto' ? 'Auto charge' : 'Manual',
        date: date,
      ));
    }
    return out;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return 0;
    return int.tryParse(value.toString()) ??
        double.tryParse(value.toString())?.toInt() ??
        0;
  }

  static String _resolveCategory(String? accountType) {
    switch ((accountType ?? '').trim()) {
      case '1523':
        return 'Equity';
      case '1524':
        return 'Patronage';
      case '1525':
        return 'Custom';
      // 1526 is the loan late-payment fine (and admin manual loan
      // fine) account type — written by the backend
      // LateFeeFineService into a per-cooperative `internal_accounts`
      // row of account_type=1526. Surfaces under the existing Fine
      // tab in financial_obligations_screen.dart.
      case '1526':
        return 'Fine';
      default:
        return 'Custom';
    }
  }

  static String _resolveStatus({
    required int paidMinor,
    required int totalMinor,
    required DateTime dueDate,
    String? category,
  }) {
    if (totalMinor > 0 && paidMinor >= totalMinor) return 'Completed';
    // Equity contributions are share-based, not time-bound — there's
    // no "overdue" state, only "fully subscribed" vs. "still active".
    // Patronage / custom obligations keep the standard date-based check.
    if (category != 'Equity' && dueDate.isBefore(DateTime.now())) {
      return 'Overdue';
    }
    return 'Active';
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}
