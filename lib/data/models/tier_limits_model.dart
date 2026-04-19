import 'package:equatable/equatable.dart';

/// From `GET /get-loggedin-user` → `tier_limits` (member only).
class TierLimitsSnapshot extends Equatable {
  final List<TierCatalogEntry> catalog;
  final TierCurrent current;
  final String? nextTierKey;
  final TierCatalogEntry? nextTier;

  const TierLimitsSnapshot({
    required this.catalog,
    required this.current,
    this.nextTierKey,
    this.nextTier,
  });

  bool get isFullyVerified => current.tierKey == 'tier_2';

  factory TierLimitsSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TierLimitsSnapshot(
        catalog: const [],
        current: TierCurrent.fallback(),
      );
    }
    final catRaw = json['catalog'];
    final catalog = <TierCatalogEntry>[];
    if (catRaw is List) {
      for (final e in catRaw) {
        if (e is Map) {
          catalog.add(TierCatalogEntry.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final curRaw = json['current'];
    final current = curRaw is Map
        ? TierCurrent.fromJson(Map<String, dynamic>.from(curRaw))
        : TierCurrent.fallback();

    final nextKey = json['next_tier_key']?.toString();
    final nextRaw = json['next_tier'];
    TierCatalogEntry? nextTier;
    if (nextRaw is Map) {
      nextTier = TierCatalogEntry.fromJson(Map<String, dynamic>.from(nextRaw));
    }

    return TierLimitsSnapshot(
      catalog: catalog,
      current: current,
      nextTierKey: nextKey != null && nextKey.isNotEmpty ? nextKey : null,
      nextTier: nextTier,
    );
  }

  @override
  List<Object?> get props =>
      [catalog, current, nextTierKey, nextTier];
}

class TierCatalogEntry extends Equatable {
  final String tierKey;
  final String label;
  final int dailyTransactionLimitKobo;
  final int maxBalanceKobo;
  final int sortOrder;

  const TierCatalogEntry({
    required this.tierKey,
    required this.label,
    required this.dailyTransactionLimitKobo,
    required this.maxBalanceKobo,
    this.sortOrder = 0,
  });

  factory TierCatalogEntry.fromJson(Map<String, dynamic> json) {
    return TierCatalogEntry(
      tierKey: json['tier_key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      dailyTransactionLimitKobo:
          int.tryParse(json['daily_transaction_limit_kobo']?.toString() ?? '') ??
              0,
      maxBalanceKobo:
          int.tryParse(json['max_balance_kobo']?.toString() ?? '') ?? 0,
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [tierKey, label, dailyTransactionLimitKobo, maxBalanceKobo, sortOrder];
}

class TierCurrent extends Equatable {
  final String tierKey;
  final String label;
  final int dailyTransactionLimitKobo;
  final int maxBalanceKobo;

  const TierCurrent({
    required this.tierKey,
    required this.label,
    required this.dailyTransactionLimitKobo,
    required this.maxBalanceKobo,
  });

  factory TierCurrent.fallback() => const TierCurrent(
        tierKey: 'tier_0',
        label: 'Not verified',
        dailyTransactionLimitKobo: 0,
        maxBalanceKobo: 0,
      );

  factory TierCurrent.fromJson(Map<String, dynamic> json) {
    return TierCurrent(
      tierKey: json['tier_key']?.toString() ?? 'tier_0',
      label: json['label']?.toString() ?? 'Not verified',
      dailyTransactionLimitKobo:
          int.tryParse(json['daily_transaction_limit_kobo']?.toString() ?? '') ??
              0,
      maxBalanceKobo:
          int.tryParse(json['max_balance_kobo']?.toString() ?? '') ?? 0,
    );
  }

  /// Human-readable tier label (1 or 2) for headings; tier_0 → "Getting started".
  String get displayTierTitle {
    switch (tierKey) {
      case 'tier_1':
        return 'Tier 1';
      case 'tier_2':
        return 'Tier 2';
      default:
        return 'Verification';
    }
  }

  /// No Anchor/Communal KYC tier assigned yet (limits apply after Tier 1+).
  bool get isPreVerificationTier {
    switch (tierKey) {
      case 'tier_1':
      case 'tier_2':
        return false;
      default:
        return true;
    }
  }

  @override
  List<Object?> get props =>
      [tierKey, label, dailyTransactionLimitKobo, maxBalanceKobo];
}
