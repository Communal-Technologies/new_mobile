/// Result of `GET /v1/bills/customer-validation/{billerSlug}/{accountNumber}`.
///
/// Used to confirm a meter (electricity) or smartcard (television) is
/// registered to the right account before debiting the user. `address`
/// is populated for some electricity discos; null for cable TV.
class BillCustomer {
  const BillCustomer({
    required this.customerName,
    required this.customerNumber,
    this.address,
  });

  final String customerName;
  final String customerNumber;
  final String? address;

  factory BillCustomer.fromJson(Map<String, dynamic> json) {
    return BillCustomer(
      customerName: (json['customer_name'] ?? '').toString(),
      customerNumber: (json['customer_number'] ?? '').toString(),
      address: json['address']?.toString(),
    );
  }
}
