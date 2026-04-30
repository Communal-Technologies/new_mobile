/// One row from `GET /v1/bills/billers/{id}/products`.
///
/// Airtime products are typically `Range`-priced (the user picks any
/// amount within bounds); data products are `Fixed` (price equals what
/// the backend will accept). `priceMinor` is in kobo for NGN.
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
  final String slug;
  final int priceMinor;
  final String priceType;

  bool get isFixed => priceType.toLowerCase() == 'fixed';

  factory BillProduct.fromJson(Map<String, dynamic> json) {
    final raw = json['price'];
    final price = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
    return BillProduct(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      priceMinor: price,
      priceType: (json['price_type'] ?? json['priceType'] ?? '').toString(),
    );
  }
}
