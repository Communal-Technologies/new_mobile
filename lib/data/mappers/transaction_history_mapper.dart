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

int? _intOrNull(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
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

// Shared icon palette so a given kind of transaction looks the same whether it
// came from the communal wallet feed or the cooperative ledger. (icon, fg, bg).
const _ipBank = (Icons.swap_horiz_rounded, Colors.white, Color(0xFF742CE7));
const _ipReceive = (Icons.south_west_rounded, Colors.white, Color(0xFF1AAE70));
const _ipSend = (Icons.north_east_rounded, Colors.white, Color(0xFF742CE7));
const _ipDeposit = (
  Icons.account_balance_wallet_rounded,
  Colors.white,
  Color(0xFF1AAE70),
);
const _ipWithdraw = (Icons.payments_rounded, Colors.white, Color(0xFFE6A502));
const _ipLoan = (Icons.handshake_rounded, Colors.white, Color(0xFF00BCD4));
const _ipFine = (Icons.gavel_rounded, Colors.white, Color(0xFFD7263D));
const _ipSavings = (Icons.savings_rounded, Colors.white, Color(0xFF742CE7));
const _ipEquity = (Icons.pie_chart_rounded, Colors.white, Color(0xFF3F51B5));
const _ipElectric = (Icons.bolt_rounded, Colors.white, Color(0xFFE6A502));
const _ipAirtime = (Icons.smartphone_rounded, Colors.white, Color(0xFF3F51B5));
const _ipData = (Icons.wifi_rounded, Colors.white, Color(0xFF0288D1));
const _ipTv = (Icons.live_tv_rounded, Colors.white, Color(0xFF8E24AA));
const _ipBill = (Icons.receipt_long_rounded, Colors.white, Color(0xFF607D8B));

// Classify a bill/utility from free text so cable/airtime/data/electricity each
// get their own glyph instead of a generic receipt.
(IconData, Color, Color)? _billIconFromText(String t) {
  if (t.contains('electric') ||
      t.contains('meter') ||
      t.contains('power') ||
      t.contains('disco') ||
      t.contains('prepaid') ||
      t.contains('postpaid')) {
    return _ipElectric;
  }
  if (t.contains('airtime') || t.contains('recharge')) return _ipAirtime;
  if (t.contains('data bundle') ||
      t.contains('data plan') ||
      t.contains(' data') ||
      t.contains('internet')) {
    return _ipData;
  }
  if (t.contains('cable') ||
      t.contains('tv') ||
      t.contains('dstv') ||
      t.contains('gotv') ||
      t.contains('startimes') ||
      t.contains('showmax')) {
    return _ipTv;
  }
  if (t.contains('bill')) return _ipBill;
  return null;
}

(IconData, Color, Color) _iconStyleCommunal(String rawType, bool incoming) {
  final t = rawType.toLowerCase();
  final bill = _billIconFromText(t);
  if (bill != null) return bill;
  if (t.contains('nip') || t.contains('book') || t.contains('transfer')) {
    return incoming ? _ipReceive : _ipSend;
  }
  if (t.contains('deposit') || t.contains('fund')) return _ipDeposit;
  if (t.contains('credit')) return _ipReceive;
  if (t.contains('withdraw')) return _ipWithdraw;
  if (t.contains('loan')) return _ipLoan;
  if (t.contains('fine')) return _ipFine;
  if (t.contains('obligation') || t.contains('cooperative')) return _ipSavings;
  return incoming ? _ipReceive : _ipSend;
}

(IconData, Color, Color) _iconStyleLedger(
  String obligationType,
  String description,
  bool incoming,
) {
  final text = '${obligationType.toLowerCase()} ${description.toLowerCase()}';
  if (text.contains('fine') || text.contains('penalt')) return _ipFine;
  if (text.contains('loan')) return _ipLoan;
  final bill = _billIconFromText(text);
  if (bill != null) return bill;
  if (text.contains('equity') || text.contains('share')) return _ipEquity;
  if (text.contains('transfer')) return _ipBank;
  if (text.contains('withdraw') || text.contains('payout')) return _ipWithdraw;
  return _ipSavings;
}

String _humanizeType(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return 'Transaction';
  // NIPTransfer/BookTransfer arrive as camelCase with no separator, so the
  // generic underscore/whitespace splitter below collapses them into
  // "Niptransfer"/"Booktransfer" instead of recognising two words.
  switch (s.toLowerCase()) {
    case 'niptransfer':
      return 'NIP Transfer';
    case 'booktransfer':
      return 'Book Transfer';
  }
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

/// Ledger `trx_ref_id` values are internal idempotency keys that pack several
/// fields with `|` (e.g. `nip_obl|TXNID|CODE`, `fine|LEDGER|ID|AMT`).
/// Surface the most reference-like segment (the longest one — usually the
/// transfer/txn id) so the receipt shows a clean reference, not the raw key.
String _cleanReference(String raw) {
  final r = raw.trim();
  if (!r.contains('|')) return r;
  final parts = r.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty);
  String best = '';
  for (final p in parts) {
    // Skip obviously non-id segments (pure words / short tokens / amounts).
    if (p.length > best.length) best = p;
  }
  return best.isEmpty ? r : best;
}

/// Turn a backend `payment_mode`/gateway token into a human payment method.
String _humanizePaymentMethod(String paymentMode) {
  final m = paymentMode.toLowerCase();
  if (m.contains('nip')) return 'Bank transfer (NIP)';
  if (m.contains('book')) return 'Wallet transfer';
  if (m.contains('obligation')) return 'From obligation balance';
  if (m.contains('brought forward')) return 'Brought forward';
  if (m.contains('wallet')) return 'Wallet';
  if (m.contains('cash')) return 'Cash';
  if (paymentMode.trim().isEmpty) return 'Ledger';
  return _humanizeType(paymentMode);
}

/// Map a biller/network code to a display name. Falls back to a humanized
/// version of the raw code when it isn't one we recognise.
String _humanizeProvider(String raw) {
  final key = raw.trim().toLowerCase();
  if (key.isEmpty) return '';
  const known = {
    'mtn': 'MTN',
    'glo': 'Glo',
    'airtel': 'Airtel',
    '9mobile': '9mobile',
    'etisalat': '9mobile',
    'gotv': 'GOtv',
    'dstv': 'DStv',
    'startimes': 'StarTimes',
    'showmax': 'Showmax',
    'ikedc': 'Ikeja Electric',
    'ekedc': 'Eko Electric',
    'aedc': 'Abuja Electric',
    'phedc': 'Port Harcourt Electric',
    'kedco': 'Kano Electric',
    'eedc': 'Enugu Electric',
    'ibedc': 'Ibadan Electric',
    'jedc': 'Jos Electric',
    'kaedco': 'Kaduna Electric',
    'bedc': 'Benin Electric',
    'abedc': 'Aba Electric',
    'yedc': 'Yola Electric',
  };
  return known[key] ?? _humanizeType(raw);
}

/// Turn a data-plan product code (e.g. `mtn_data_1_5gb_30_days_`) into a
/// readable plan label (e.g. `1.5GB · 30 days`). Best-effort: an unparseable
/// code is just cleaned of separators.
String _humanizeDataPlan(String raw, String providerCode) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return '';
  final p = providerCode.trim().toLowerCase();
  if (p.isNotEmpty) {
    s = s.replaceFirst(RegExp('^${RegExp.escape(p)}[_-]?'), '');
  }
  s = s
      .replaceFirst(RegExp(r'^data[_-]?'), '')
      .replaceAll(RegExp(r'[_-]+$'), '');
  s = s.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  // 1_5gb -> "1 5gb" -> "1.5GB"; standalone "<n>gb"/"<n>mb" -> upper unit.
  s = s.replaceAllMapped(
    RegExp(r'(\d+)\s+(\d+)\s*gb'),
    (m) => '${m[1]}.${m[2]}GB',
  );
  s = s.replaceAllMapped(RegExp(r'(\d+)\s*gb'), (m) => '${m[1]}GB');
  s = s.replaceAllMapped(RegExp(r'(\d+)\s*mb'), (m) => '${m[1]}MB');
  return s.trim();
}

/// Consumer-facing receipt details for a bill/utility purchase from the
/// communal feed. Returns null when the row isn't a recognised bill type so the
/// caller keeps its default handling.
typedef _BillView = ({
  String title,
  String type,
  String
  provider, // display provider/biller, e.g. "MTN", "GOtv", "Ikeja Electric"
  String recipient, // consumer identifier: phone / smartcard / meter number
  List<MapEntry<String, String>> extras,
  (IconData, Color, Color) icon,
});

_BillView? _billViewFromJson(Map<String, dynamic> json) {
  final rawType = (json['transaction_type'] ?? '').toString().toLowerCase();
  final billerCode = (json['bill_provider'] ?? '').toString();
  final provider = _humanizeProvider(billerCode);
  final recipient =
      (json['bill_recipient'] ?? json['counterparty_account'] ?? '')
          .toString()
          .trim();
  final product = (json['bill_product'] ?? '').toString().trim();
  final meterType = (json['bill_meter_type'] ?? '').toString().trim();
  final extras = <MapEntry<String, String>>[];

  String join2(String a, String b) =>
      [if (a.isNotEmpty) a, if (b.isNotEmpty) b].join(' · ');

  if (rawType.contains('airtime')) {
    if (provider.isNotEmpty) extras.add(MapEntry('Network', provider));
    if (recipient.isNotEmpty) extras.add(MapEntry('Phone number', recipient));
    return (
      title: join2('Airtime', provider),
      type: 'Airtime purchase',
      provider: provider,
      recipient: recipient,
      extras: extras,
      icon: _ipAirtime,
    );
  }
  if (rawType.contains('data')) {
    final plan = _humanizeDataPlan(product, billerCode);
    if (provider.isNotEmpty) extras.add(MapEntry('Network', provider));
    if (recipient.isNotEmpty) extras.add(MapEntry('Phone number', recipient));
    if (plan.isNotEmpty) extras.add(MapEntry('Data plan', plan));
    return (
      title: join2('Data', provider),
      type: 'Data bundle',
      provider: provider,
      recipient: recipient,
      extras: extras,
      icon: _ipData,
    );
  }
  if (rawType.contains('television') ||
      rawType.contains('cable') ||
      rawType.contains('tv')) {
    if (provider.isNotEmpty) extras.add(MapEntry('Provider', provider));
    if (recipient.isNotEmpty) {
      extras.add(MapEntry('Smartcard number', recipient));
    }
    if (product.isNotEmpty) {
      extras.add(MapEntry('Package', _humanizeType(product)));
    }
    return (
      title: join2(provider.isNotEmpty ? provider : 'TV', recipient),
      type: 'TV subscription',
      provider: provider.isNotEmpty ? provider : 'Cable TV',
      recipient: recipient,
      extras: extras,
      icon: _ipTv,
    );
  }
  if (rawType.contains('electric') || rawType.contains('power')) {
    // Disco codes often pin the meter type onto the biller code
    // (e.g. `ikeja_electric_prepaid`); strip it since `meter_type` already
    // carries prepaid/postpaid, then humanize → "Ikeja Electric".
    final discoCode = billerCode.replaceFirst(
      RegExp(r'[_-]?(prepaid|postpaid)$', caseSensitive: false),
      '',
    );
    final disco = _humanizeProvider(discoCode);
    if (disco.isNotEmpty) extras.add(MapEntry('Disco', disco));
    if (meterType.isNotEmpty) {
      extras.add(MapEntry('Purchase type', _humanizeType(meterType)));
    }
    if (recipient.isNotEmpty) extras.add(MapEntry('Meter number', recipient));
    return (
      title: join2(disco.isNotEmpty ? disco : 'Electricity', recipient),
      type: 'Electricity purchase',
      provider: disco.isNotEmpty ? disco : 'Electricity',
      recipient: recipient,
      extras: extras,
      icon: _ipElectric,
    );
  }
  return null;
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
  final cpBank = json['counterparty_bank']?.toString().trim();
  final titleBase = _humanizeType(typeRaw);
  // For transfers, show direction + the other party rather than the technical
  // rail name ("Book Transfer"/"NIP Transfer"). Fall back to the account
  // number, then to a generic sent/received label when the party is unknown
  // (e.g. older rows or external recipients without a stored name).
  final isTransfer = typeRaw.toLowerCase().contains('transfer');
  final who = (cpName != null && cpName.isNotEmpty)
      ? cpName
      : (cpAcct != null && cpAcct.isNotEmpty ? cpAcct : null);
  // Bills/utilities carry consumer details (provider, phone/smartcard/meter,
  // plan) so the receipt says exactly what was bought and for whom.
  final bill = _billViewFromJson(json);
  // A settlement payment (fine, obligation contribution, loan repayment) knows
  // what it was for; the rail it travelled on does not. `purpose` names it, so
  // it wins over "Transfer to ******8198", and `narration` is what the payer
  // typed. Both are absent on a plain transfer.
  final purpose = json['purpose']?.toString().trim() ?? '';
  final narration = json['narration']?.toString().trim() ?? '';
  final String title;
  if (bill != null) {
    title = bill.title;
  } else if (purpose.isNotEmpty) {
    title = purpose;
  } else if (isTransfer) {
    if (incoming) {
      title = who != null ? 'Received from $who' : 'Money Received';
    } else {
      title = who != null ? 'Transfer to $who' : 'Money Sent';
    }
  } else {
    title = (cpName != null && cpName.isNotEmpty)
        ? '$titleBase · $cpName'
        : titleBase;
  }
  final iconPack = bill?.icon ?? _iconStyleCommunal(typeRaw, incoming);
  final sessionFmt = DateFormat('hh:mm a');

  final details = TransactionDetailsData(
    id: id.isNotEmpty ? id : trxRef,
    // For bills the "recipient" is the biller/provider and the consumer
    // identifier (phone/smartcard/meter) — the full breakdown lives in
    // extraDetails, so the generic recipient row is suppressed downstream.
    counterpartyName: bill != null
        ? (bill.provider.isNotEmpty ? bill.provider : bill.type)
        : ((cpName != null && cpName.isNotEmpty) ? cpName : 'Communal'),
    // Show the recipient's actual bank for transfers (from the persisted
    // beneficiary) instead of a misleading "Communal Wallet". Book transfers
    // and unknown rows fall back to "Communal".
    counterpartyBank: bill != null
        ? ''
        : (isTransfer
              ? ((cpBank != null && cpBank.isNotEmpty) ? cpBank : 'Communal')
              : 'Communal Wallet'),
    counterpartyAccount: bill != null
        ? (bill.recipient.isNotEmpty ? bill.recipient : null)
        : ((cpAcct != null && cpAcct.isNotEmpty) ? cpAcct : null),
    amount: amountNaira,
    fees: 0,
    currencySymbol: currencySymbol,
    transactionType: bill != null ? bill.type : titleBase,
    dateTime: dt,
    sessionId: sessionFmt.format(dt),
    // The payer's narration is the real description; the purpose stands in when
    // there is none. Bills carry their own breakdown, and a plain transfer's
    // type already says "NIP/Book Transfer", so neither repeats it here.
    description: narration.isNotEmpty
        ? narration
        : (purpose.isNotEmpty
              ? purpose
              : ((bill != null || isTransfer) ? '' : titleBase)),
    reference: trxRef.isNotEmpty ? trxRef : extRef,
    paymentMethod: bill != null
        ? 'Bill payment'
        : (isTransfer
              ? (typeRaw.toLowerCase().contains('nip')
                    ? 'Bank transfer (NIP)'
                    : (typeRaw.toLowerCase().contains('book')
                          ? 'Wallet transfer'
                          : 'Wallet'))
              : 'Wallet'),
    status: status,
    isIncoming: incoming,
    extraDetails: bill?.extras ?? const [],
    balanceBeforeMinor: _intOrNull(json['balance_before']),
    balanceAfterMinor: _intOrNull(json['balance_after']),
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
  // The server-side `description` is the descriptive, at-a-glance line —
  // it names the obligation/fine involved (e.g. "Payment for Zain Shares via
  // NIP …", "Late payment fine for Esusu — cycle due Jun 18, 2026"). Prefer it
  // for the tile title (the tile's only descriptive line; the subtitle is just
  // the date). Fall back to the humanized type/code only when no description
  // was stored on the row.
  final modeLower = paymentMode.toLowerCase();
  final usedDesc = desc.isNotEmpty;
  final titleBase = usedDesc
      ? desc
      : modeLower.contains('loan repayment')
      ? 'Loan re-payment'
      : obligation.isNotEmpty
      ? _humanizeType(obligation)
      : 'Ledger transaction';

  // Payment method from the backend gateway/payment_mode token.
  final paymentMethod = _humanizePaymentMethod(paymentMode);

  // The "Transaction Type" row is the category — kept distinct from the
  // descriptive title so they don't read as the same line. Detect fine / loan /
  // contribution from the row's text.
  final classText = '${obligation.toLowerCase()} ${desc.toLowerCase()}';
  final String txnTypeLabel;
  if (classText.contains('fine') || classText.contains('penalt')) {
    txnTypeLabel = 'Fine payment';
  } else if (classText.contains('loan')) {
    txnTypeLabel = 'Loan repayment';
  } else if (classText.contains('transfer between') ||
      classText.contains('transfer from')) {
    txnTypeLabel = 'Obligation transfer';
  } else if (classText.contains('withdraw') || classText.contains('payout')) {
    txnTypeLabel = 'Obligation withdrawal';
  } else {
    txnTypeLabel = incoming ? 'Obligation credit' : 'Obligation payment';
  }

  // Recipient account: obligation/fine NIP descriptions carry the cooperative
  // cash account as "via NIP <number>". Surface it so "Recipient Details" shows
  // the account the payment landed in instead of a bare label.
  final acctMatch = RegExp(r'via NIP\s+([0-9]{6,})').firstMatch(desc);
  final coopAccount = acctMatch?.group(1);

  // When the title is the rich description it already carries enough context;
  // appending the cooperative label only bloats it. Keep the suffix only for
  // the short type/code fallback so personal-tab mirrored rows stay attributable.
  final title = usedDesc ? titleBase : '$titleBase · $cooperativeLabel';
  final iconPack = _iconStyleLedger(obligation, desc, incoming);

  final details = TransactionDetailsData(
    id: id.isNotEmpty ? id : trxRef,
    counterpartyName: cooperativeLabel,
    counterpartyBank: coopAccount != null
        ? 'Cooperative cash account'
        : 'Cooperative ledger',
    counterpartyAccount: coopAccount,
    amount: amountNaira,
    fees: 0,
    currencySymbol: currencySymbol,
    transactionType: txnTypeLabel,
    dateTime: dt,
    sessionId: '',
    description: desc.isNotEmpty ? desc : titleBase,
    reference: _cleanReference(trxRef),
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
