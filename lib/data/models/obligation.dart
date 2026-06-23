import 'package:intl/intl.dart';

import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/data/models/obligation_category.dart';

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

  /// Obligation contributed balance immediately after / before this entry, in
  /// minor units. Populated by the repository in a newest→oldest pass from the
  /// obligation's current paid balance, so the receipt can show a running
  /// balance. Null when it couldn't be derived.
  int? balanceAfterMinor;
  int? balanceBeforeMinor;

  String get dateLabel => DateFormat('MMM dd, yyyy').format(date);

  String? get balanceAfterLabel =>
      balanceAfterMinor == null ? null : Money(balanceAfterMinor!, currency).format();
  String? get balanceBeforeLabel =>
      balanceBeforeMinor == null ? null : Money(balanceBeforeMinor!, currency).format();

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
    this.accountType,
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
  /// Raw `account_type` code from the backend (e.g. '1523', '1524').
  /// Used to resolve cooperative-specific display names from
  /// [ObligationCategoriesCubit] at the UI layer without re-parsing.
  final String? accountType;
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

  /// True for share-based obligations (code 1523 / Equity). Drives
  /// the card UI: progress bar, %, and installments are shown only for
  /// share-based. Open-ended monthly contributions (1524/1525/custom)
  /// have no cap so those elements are hidden.
  bool get isShareBased => ObligationCategory.isShareBasedCode(
      accountType, ObligationCategory.defaults);

  int get balanceMinor {
    final remaining = totalAmountMinor - paidAmountMinor;
    if (remaining < 0) return 0;
    if (remaining > totalAmountMinor) return totalAmountMinor;
    return remaining;
  }

  double get progress => isShareBased && totalAmountMinor > 0
      ? paidAmountMinor / totalAmountMinor
      : 0;

  String get progressLabel =>
      isShareBased ? '${(progress * 100).toStringAsFixed(0)}%' : '';

  String get paidAmountLabel => Money(paidAmountMinor, currency).format();
  String get totalAmountLabel => Money(totalAmountMinor, currency).format();
  String get balanceLabel => Money(balanceMinor, currency).format();
  String get perInstallmentLabel =>
      Money(perInstallmentMinor, currency).format();

  /// For share-based: "₦X of ₦Y". For open-ended: just "₦X paid".
  String get amountBreakdown =>
      isShareBased ? '$paidAmountLabel of $totalAmountLabel' : paidAmountLabel;

  String get installmentsLabel =>
      'Installments paid: $installmentsPaid of $totalInstallments';

  /// Returns the cooperative-specific display name for this obligation's
  /// account type, looked up from [categories]. Falls back to the value
  /// already stored in [category] (resolved from defaults at parse time)
  /// when the code is absent or not found in the provided list.
  String resolveCategory(List<ObligationCategory> categories) {
    if (accountType == null || accountType!.trim().isEmpty) return category;
    return ObligationCategory.resolveDisplayName(accountType, categories);
  }

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
    // Period end = first of the month after the obligation's period.
    final periodEnd = DateTime(periodStart.year, periodStart.month + 1, 1);
    // "Next Due" = the upcoming due date. When the period-derived date has
    // already passed (a stale period row — e.g. an April row viewed in June),
    // roll forward to the first of next month from today so it shows a real
    // future date instead of a fixed past one.
    final thisMonthStart = DateTime(now.year, now.month, 1);
    // Prefer the server-computed next-due (obligations-svc: last_updated +
    // type frequency). Fall back to the period-derived date only when the
    // backend doesn't provide it.
    final serverNextDue = _parseDate(obligation['next_due_date']);
    final nextCycle = serverNextDue ??
        (periodEnd.isBefore(thisMonthStart)
            ? DateTime(now.year, now.month + 1, 1)
            : periodEnd);
    final minPayableMinor = _asInt(account?['min_amount_payable']);
    final totalShares = _asInt(account?['total_shares']);
    final costPerShareMinor = _asInt(account?['cost_per_share']);
    final accountType = account?['account_type']?.toString();
    final isShareBased = ObligationCategory.isShareBasedCode(
        accountType ?? '', ObligationCategory.defaults);
    // Share-based (1523) has a fixed cap = total_shares × cost_per_share.
    // Open-ended (1524/1525/custom) use the monthly obligation amount as the
    // period target; they have no cap and never show a progress bar or %.
    final totalAmountMinor = isShareBased &&
            totalShares > 0 &&
            costPerShareMinor > 0
        ? totalShares * costPerShareMinor
        : amountMinor;
    final category = _resolveCategory(accountType);
    final title = account?['account_name']?.toString().trim().isNotEmpty == true
        ? account!['account_name'].toString()
        : '$category Obligation';
    final status = _resolveStatus(
      paidMinor: amountPaidMinor,
      totalMinor: totalAmountMinor,
      isShareBased: isShareBased,
    );

    // Installment count (share-based only): cap / monthly payment.
    var totalInstallments = 1;
    if (minPayableMinor > 0 && totalAmountMinor > 0) {
      totalInstallments =
          (totalAmountMinor / minPayableMinor).ceil().clamp(1, 9999);
    } else if (totalShares > 0) {
      totalInstallments = totalShares.clamp(1, 9999);
    }

    // Per-installment divisor: always the configured monthly payment amount.
    final int perInstallmentMinor = minPayableMinor > 0 ? minPayableMinor : 0;

    var installmentsPaid = 0;
    if (perInstallmentMinor > 0) {
      installmentsPaid = (amountPaidMinor / perInstallmentMinor).floor();
    } else if (totalAmountMinor > 0) {
      installmentsPaid = (amountPaidMinor / totalAmountMinor).floor();
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
      accountType: accountType,
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
      totalAmountMinor: totalAmountMinor,
      perInstallmentMinor: perInstallmentMinor,
      installmentsPaid: installmentsPaid,
      totalInstallments: totalInstallments,
      startDate: startDate,
      endDate: periodEnd,
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
    required bool isShareBased,
  }) {
    // Only share-based (1523) obligations have a cap and can reach Completed.
    // Open-ended monthly contributions (1524/1525/custom) are always Active —
    // there is no cap to hit and no Overdue state (fines handle late payments).
    if (isShareBased && totalMinor > 0 && paidMinor >= totalMinor) {
      return 'Completed';
    }
    return 'Active';
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}
