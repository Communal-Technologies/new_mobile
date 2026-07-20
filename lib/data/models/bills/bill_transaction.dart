/// One bill purchase (airtime or data) from the backend's perspective.
///
/// Returned by `POST /v1/bills/{airtime|data}/purchase` and by
/// `GET /v1/bills/transactions/{reference}`. `status` mirrors the
/// `transactions.status` column on the server: `pending`, `completed`,
/// `failed`, or `reversed`.
enum BillStatus { pending, completed, failed, reversed, unknown }

BillStatus _parseStatus(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'pending':
      return BillStatus.pending;
    case 'completed':
    case 'successful':
    case 'success':
      return BillStatus.completed;
    case 'failed':
    case 'error':
      return BillStatus.failed;
    case 'reversed':
      return BillStatus.reversed;
    default:
      return BillStatus.unknown;
  }
}

enum BillType { airtime, data, unknown }

BillType _parseType(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'airtime_purchase':
      return BillType.airtime;
    case 'data_purchase':
      return BillType.data;
    default:
      return BillType.unknown;
  }
}

class BillTransaction {
  const BillTransaction({
    required this.reference,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.type,
    this.id,
    this.externalReference,
    this.senderAccount,
    this.receiverAccount,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String reference;
  final String? externalReference;
  final BillType type;
  final int amountMinor;
  final String currency;
  final BillStatus status;
  final String? senderAccount;
  final String? receiverAccount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTerminal =>
      status == BillStatus.completed ||
      status == BillStatus.failed ||
      status == BillStatus.reversed;

  factory BillTransaction.fromJson(Map<String, dynamic> json) {
    // billsvc returns `amount` in naira (float); convert to kobo for storage.
    // Legacy path may have returned kobo directly; the naira branch handles both.
    final amountRaw = json['amount'];
    final int amountMinorValue;
    if (amountRaw is double) {
      amountMinorValue = (amountRaw * 100).round();
    } else if (amountRaw is num) {
      // Could be an integer naira value from billsvc — treat as naira.
      amountMinorValue = (amountRaw.toDouble() * 100).round();
    } else {
      amountMinorValue =
          int.tryParse('${amountRaw ?? ''}') ?? 0;
    }

    // billsvc sends `transaction_type`; legacy/docs used `type`.
    final typeRaw =
        json['transaction_type']?.toString() ?? json['type']?.toString();
    return BillTransaction(
      id: json['id']?.toString(),
      reference: (json['reference'] ?? '').toString(),
      externalReference: json['external_reference']?.toString(),
      type: _parseType(typeRaw),
      amountMinor: amountMinorValue,
      currency: (json['currency'] ?? 'NGN').toString(),
      status: _parseStatus(json['status']?.toString()),
      senderAccount: json['sender_account']?.toString(),
      receiverAccount:
          (json['receiver_account'] ?? json['recipient'])?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
    );
  }
}
