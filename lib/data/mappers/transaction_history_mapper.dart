import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/screens/transactions/models/sample_transactions.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';

double _amountNairaFromKoboField(dynamic raw) {
  if (raw == null) return 0;
  final n = (raw is num)
      ? raw.toDouble()
      : double.tryParse(raw.toString()) ?? 0;
  return n / 100.0;
}

TransactionStatus _mapRecordStatus(String? raw) {
  switch ((raw ?? '').toLowerCase().trim()) {
    case 'completed':
    case 'successful':
    case 'success':
    case 'settled':
    case 'received':
      return TransactionStatus.successful;
    case 'failed':
    case 'error':
    case 'reversed':
      return TransactionStatus.failed;
    default:
      return TransactionStatus.pending;
  }
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

(IconData, Color, Color) _iconStyleCommunal(String rawType, bool incoming) {
  final t = rawType.toLowerCase();
  if (t.contains('nip')) {
    return (
      Icons.send_rounded,
      incoming ? Colors.white : const Color(0xFF742CE7),
      incoming ? const Color(0xFF742CE7) : const Color(0xFFF0E6FF),
    );
  }
  if (t.contains('book')) {
    return (
      Icons.swap_horiz_rounded,
      incoming ? Colors.white : const Color(0xFF742CE7),
      incoming ? const Color(0xFF4CAF50) : const Color(0xFFF0E6FF),
    );
  }
  if (t.contains('deposit') || t.contains('credit')) {
    return (
      Icons.account_balance_wallet_rounded,
      Colors.white,
      const Color(0xFF742CE7),
    );
  }
  if (t.contains('withdraw')) {
    return (Icons.north_east_rounded, Colors.white, Colors.orange.shade700);
  }
  if (t.contains('loan')) {
    return (Icons.handshake_rounded, Colors.white, const Color(0xFF00BCD4));
  }
  if (t.contains('obligation') || t.contains('cooperative')) {
    return (Icons.groups_rounded, Colors.white, const Color(0xFF742CE7));
  }
  return (Icons.receipt_long_rounded, Colors.white, Colors.blueGrey.shade300);
}

(IconData, Color, Color) _iconStyleLedger(
  String obligationType,
  String description,
  bool incoming,
) {
  final d = description.toLowerCase();
  final o = obligationType.toLowerCase();
  if (o.contains('loan') || d.contains('loan')) {
    return (Icons.handshake_rounded, Colors.white, const Color(0xFF00BCD4));
  }
  if (d.contains('electric') || d.contains('bill')) {
    return (Icons.flash_on_rounded, Colors.white, Colors.orange);
  }
  return (Icons.groups_rounded, Colors.white, const Color(0xFF742CE7));
}

String _humanizeType(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return 'Transaction';
  return s
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .map((w) {
        if (w.length <= 2) return w.toUpperCase();
        return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
      })
      .join(' ');
}

bool ledgerRowShouldMirrorOnPersonalTab(Map<String, dynamic> json) {
  final o = json['obligation_type']?.toString().trim().toLowerCase() ?? '';
  if (o.isEmpty || o == '0' || o == '-' || o == 'none' || o == 'n/a') {
    final desc = json['description']?.toString().toLowerCase() ?? '';
    return desc.contains('obligation');
  }
  return true;
}

TransactionListItem mapCommunalTransactionToListItem(
  Map<String, dynamic> json, {
  required String currencySymbol,
}) {
  final id = json['id']?.toString() ?? '';
  final trxRef = json['trx_reference']?.toString() ?? '';
  final extRef = json['external_reference']?.toString() ?? '';
  final typeRaw = json['transaction_type']?.toString() ?? '';
  final flow = json['type']?.toString().toLowerCase() ?? '';
  final incoming = flow == 'credit';
  final amountNaira = _amountNairaFromKoboField(json['amount']);
  final dt = _parseDate(json['created_at']) ?? DateTime.now();
  final status = _mapRecordStatus(json['status']?.toString());
  final cpName = json['counterparty_name']?.toString().trim();
  final cpAcct = json['counterparty_account']?.toString().trim();
  final titleBase = _humanizeType(typeRaw);
  final title = (cpName != null && cpName.isNotEmpty)
      ? '$titleBase · $cpName'
      : titleBase;
  final iconPack = _iconStyleCommunal(typeRaw, incoming);
  final sessionFmt = DateFormat('hh:mm a');

  final details = TransactionDetailsData(
    id: id.isNotEmpty ? id : trxRef,
    counterpartyName: (cpName != null && cpName.isNotEmpty)
        ? cpName
        : 'Communal',
    counterpartyBank: 'Communal Wallet',
    counterpartyAccount: (cpAcct != null && cpAcct.isNotEmpty) ? cpAcct : null,
    amount: amountNaira,
    fees: 0,
    currencySymbol: currencySymbol,
    transactionType: titleBase,
    dateTime: dt,
    sessionId: sessionFmt.format(dt),
    description: titleBase,
    reference: trxRef.isNotEmpty ? trxRef : extRef,
    paymentMethod: 'Wallet',
    status: status,
    isIncoming: incoming,
  );

  return TransactionListItem(
    details: details,
    title: title,
    icon: iconPack.$1,
    iconColor: iconPack.$2,
    iconBgColor: iconPack.$3,
  );
}

TransactionListItem mapLedgerRowToListItem(
  Map<String, dynamic> json, {
  required String cooperativeLabel,
  required String currencySymbol,
}) {
  final id = json['id']?.toString() ?? '';
  final trxRef = json['trx_ref_id']?.toString() ?? '';
  final trxType = json['trx_type']?.toString() ?? '';
  final incoming = trxType == '1';
  final amountNaira = _amountNairaFromKoboField(json['amount']);
  final dt = _parseDate(json['created_at']) ?? DateTime.now();
  final obligation = json['obligation_type']?.toString().trim() ?? '';
  final desc = json['description']?.toString().trim() ?? '';
  final paymentMode = json['payment_mode']?.toString().trim() ?? '';

  // Derive a friendly transaction-type label. The backend's `payment_mode`
  // is the source of truth — it already says "Loan repayment from
  // wallet (NIP)" / "Loan repayment from obligation" — so loan repayments
  // surface as "Loan re-payment" instead of the bare obligation_type
  // ("Loan"). Other rows fall back to the obligation_type → description
  // ladder we used before.
  final modeLower = paymentMode.toLowerCase();
  final titleBase = modeLower.contains('loan repayment')
      ? 'Loan re-payment'
      : obligation.isNotEmpty
      ? _humanizeType(obligation)
      : (desc.isNotEmpty ? desc : 'Ledger transaction');

  // Derive a payment method that matches reality instead of hardcoding
  // "Ledger" (which obscures whether the row was a NIP transfer, an
  // obligation move, or a manual posting). The strings emitted server-side
  // are stable — see LoanApplicationController::payLoan and
  // FinancialObligationController::processPayment.
  String paymentMethod;
  if (modeLower.contains('(nip)') || modeLower.contains('nip transfer')) {
    paymentMethod = 'NIP transfer';
  } else if (modeLower.contains('from obligation')) {
    paymentMethod = 'Obligation';
  } else if (modeLower.contains('brought forward')) {
    paymentMethod = 'Brought forward';
  } else if (paymentMode.isNotEmpty) {
    paymentMethod = paymentMode;
  } else {
    paymentMethod = 'Ledger';
  }

  final title = '$titleBase · $cooperativeLabel';
  final iconPack = _iconStyleLedger(obligation, desc, incoming);
  final sessionFmt = DateFormat('hh:mm a');

  final details = TransactionDetailsData(
    id: id.isNotEmpty ? id : trxRef,
    counterpartyName: cooperativeLabel,
    counterpartyBank: 'Cooperative ledger',
    counterpartyAccount: null,
    amount: amountNaira,
    fees: 0,
    currencySymbol: currencySymbol,
    transactionType: titleBase,
    dateTime: dt,
    sessionId: sessionFmt.format(dt),
    description: desc.isNotEmpty ? desc : titleBase,
    reference: trxRef,
    paymentMethod: paymentMethod,
    status: TransactionStatus.successful,
    isIncoming: incoming,
  );

  return TransactionListItem(
    details: details,
    title: title,
    icon: iconPack.$1,
    iconColor: iconPack.$2,
    iconBgColor: iconPack.$3,
  );
}

List<TransactionListItem> mergePersonalWithObligationLedgerRows({
  required List<TransactionListItem> communal,
  required List<TransactionListItem> ledgerCandidates,
}) {
  final seen = <String>{};
  for (final i in communal) {
    final r = i.details.reference.trim();
    if (r.isNotEmpty) seen.add(r);
  }
  final out = [...communal];
  for (final i in ledgerCandidates) {
    final r = i.details.reference.trim();
    if (r.isNotEmpty && seen.contains(r)) continue;
    if (r.isNotEmpty) seen.add(r);
    out.add(i);
  }
  out.sort((a, b) => b.details.dateTime.compareTo(a.details.dateTime));
  return out;
}

Map<String, List<TransactionListItem>> groupTransactionsByMonth(
  List<TransactionListItem> items,
) {
  final buckets = <String, List<TransactionListItem>>{};
  final monthFmt = DateFormat('MMMM yyyy');
  for (final i in items) {
    final k = monthFmt.format(i.details.dateTime);
    buckets.putIfAbsent(k, () => []).add(i);
  }
  for (final list in buckets.values) {
    list.sort((a, b) => b.details.dateTime.compareTo(a.details.dateTime));
  }
  final keys = buckets.keys.toList()
    ..sort((a, b) {
      final da = buckets[a]!.first.details.dateTime;
      final db = buckets[b]!.first.details.dateTime;
      return db.compareTo(da);
    });
  return <String, List<TransactionListItem>>{
    for (final k in keys) k: buckets[k]!,
  };
}
