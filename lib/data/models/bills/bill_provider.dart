/// One row from `GET /v1/bills/{airtime|data}/providers`.
///
/// `slug` is what we send back to the backend on purchase
/// (e.g. `mtn`, `airtel`). `id` is Anchor's biller id, used to fetch
/// products via `GET /v1/bills/billers/{id}/products`.
class BillProvider {
  const BillProvider({
    required this.id,
    required this.name,
    required this.slug,
    this.category,
  });

  final String id;
  final String name;
  final String slug;
  final String? category;

  factory BillProvider.fromJson(Map<String, dynamic> json) {
    return BillProvider(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString().toLowerCase(),
      category: json['category']?.toString(),
    );
  }
}
