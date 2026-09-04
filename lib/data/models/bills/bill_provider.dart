/// One row from `GET /api/bills/v2/billers`.
///
/// `slug` is what we send back to the backend on purchase
/// (e.g. `mtn`, `airtel`). `id` is Anchor's biller id, used to fetch
/// products via `GET /api/bills/v2/billers/{id}/products`.
class BillProvider {
  const BillProvider({
    required this.id,
    required this.name,
    required this.slug,
    this.billerCode,
    this.category,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String slug;

  /// Anchor biller code used in data / electricity / cable purchase requests.
  /// Different from [slug] — this is Anchor's internal identifier, not a
  /// human-readable slug. Empty for airtime providers (not needed for airtime).
  final String? billerCode;
  final String? category;

  /// Absolute URL to the provider's mark. Anchor sends no artwork at all; billsvc
  /// appends this from its own pack and omits it for a slug it holds none for.
  final String? logoUrl;

  factory BillProvider.fromJson(Map<String, dynamic> json) {
    return BillProvider(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString().toLowerCase(),
      billerCode: json['biller_code']?.toString(),
      category: json['category']?.toString(),
      logoUrl: json['logo_url']?.toString(),
    );
  }
}
