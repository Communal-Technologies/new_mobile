/// One row from the `members/loan/search-guarantors` typeahead endpoint.
class MemberSearchResult {
  const MemberSearchResult({
    required this.ledgerNumber,
    required this.name,
  });

  final String ledgerNumber;
  final String name;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    if (parts.isEmpty) {
      return ledgerNumber.isNotEmpty
          ? ledgerNumber.substring(0, 1).toUpperCase()
          : '?';
    }
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory MemberSearchResult.fromJson(Map<String, dynamic> m) {
    return MemberSearchResult(
      ledgerNumber: m['ledger_number']?.toString() ?? '',
      name: (m['name']?.toString() ?? '').trim(),
    );
  }
}
