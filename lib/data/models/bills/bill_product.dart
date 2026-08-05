/// One row from `GET /api/bills/v2/billers/{id}/products`.
///
/// The billsvc returns `code` (product identifier) and `amount` (naira float).
/// [slug] is populated from `code` for use in purchase requests.
/// [priceMinor] is stored in kobo (amount × 100).
class BillProduct {
  const BillProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.priceMinor,
    required this.priceType,
  });

  final String id;
  final String name;

  /// Product code / slug — the value sent as `product_code` on purchase.
  final String slug;

  /// Price in kobo. 0 for range-priced products (airtime).
  final int priceMinor;

  /// 'fixed' or 'range'. Derived from price when not in the response.
  final String priceType;

  bool get isFixed => priceType.toLowerCase() == 'fixed';

  factory BillProduct.fromJson(Map<String, dynamic> json) {
    // billsvc sends `amount` (naira, float); legacy path sent `price` (kobo, int).
    final rawAmount = json['amount'];
    final rawPrice = json['price'];
    int priceMinorValue;
    if (rawAmount != null) {
      priceMinorValue = ((rawAmount as num).toDouble() * 100).round();
    } else if (rawPrice != null) {
      priceMinorValue =
          rawPrice is num ? rawPrice.toInt() : int.tryParse('$rawPrice') ?? 0;
    } else {
      priceMinorValue = 0;
    }

    // billsvc sends `code`; legacy path sent `slug`.
    final slug = (json['code'] ?? json['slug'] ?? '').toString();

    final rawPriceType = json['price_type'] ?? json['priceType'];
    final priceType = rawPriceType?.toString() ??
        (priceMinorValue > 0 ? 'fixed' : 'range');

    return BillProduct(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: slug,
      priceMinor: priceMinorValue,
      priceType: priceType,
    );
  }
}
