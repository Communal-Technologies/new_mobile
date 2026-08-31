import 'package:intl/intl.dart';

import 'package:communal_mobile/data/models/user_model.dart';

/// Maps profile country (ISO 3166-1 alpha-2) to a default ISO 4217 code when the
/// wallet does not send [UserModel.walletCurrencyCode]. Extend as you add markets.
String currencyCodeFromCountryIso(String? countryIso) {
  switch ((countryIso ?? '').trim().toUpperCase()) {
    case 'NG':
      return 'NGN';
    case 'GH':
      return 'GHS';
    case 'KE':
      return 'KES';
    case 'ZA':
      return 'ZAR';
    case 'UG':
      return 'UGX';
    case 'TZ':
      return 'TZS';
    case 'RW':
      return 'RWF';
    case 'SN':
    case 'CI':
      return 'XOF';
    case 'CM':
      return 'XAF';
    case 'US':
      return 'USD';
    case 'GB':
      return 'GBP';
    case 'DE':
    case 'FR':
    case 'IT':
    case 'ES':
    case 'NL':
      return 'EUR';
    default:
      return 'NGN';
  }
}

/// ISO 4217 code for display/formatting: prefer wallet when API provides it.
///
/// This is the WALLET's denomination — right for transfers and transaction
/// history, where the provider settled in its own currency. Cooperative money
/// (obligations, fines, loans, contributions) uses
/// [cooperativeCurrencyCode] instead.
String resolveCurrencyCode(UserModel user) {
  final w = user.walletCurrencyCode?.trim().toUpperCase();
  if (w != null && w.length == 3) return w;
  return currencyCodeFromCountryIso(user.countryIso);
}

/// Which side of the figure a currency symbol sits on.
enum CurrencySymbolPosition { left, right }

/// Reads the cooperative's `currency_symbol_position` setting. Anything other
/// than an explicit `right` is left, which is what most currencies want.
CurrencySymbolPosition currencySymbolPositionFrom(String? raw) =>
    (raw ?? '').trim().toLowerCase() == 'right'
        ? CurrencySymbolPosition.right
        : CurrencySymbolPosition.left;

/// How one cooperative writes its money: the currency, the symbol it prints and
/// the side that symbol goes on.
///
/// It belongs to the membership, not to the app. A member in two cooperatives
/// that chose different currencies must see each one's figures in its own, and
/// switching cooperatives has to change it — so nothing caches this beyond the
/// active [UserModel].
class CurrencyDisplay {
  const CurrencyDisplay({
    required this.code,
    required this.symbol,
    this.position = CurrencySymbolPosition.left,
  });

  final String code;
  final String symbol;
  final CurrencySymbolPosition position;

  /// Same cooperative preference, applied to a different currency — a wallet
  /// amount the provider settled in its own denomination.
  CurrencyDisplay forCurrency(String? currencyCode) {
    final other = (currencyCode ?? '').trim().toUpperCase();
    if (other.length != 3 || other == code) return this;
    return CurrencyDisplay(
      code: other,
      symbol: currencySymbolForCode(other),
      position: position,
    );
  }

  /// Puts the symbol on the chosen side. A symbol spelt in letters ("KSh",
  /// "CHF") gets a space so it does not read as part of the number; a glyph
  /// does not.
  String adorn(String figure) {
    final sym = symbol.trim().isEmpty ? currencySymbolForCode(code) : symbol.trim();
    final gap = RegExp(r'^[A-Za-z]+$').hasMatch(sym) ? ' ' : '';
    return position == CurrencySymbolPosition.right
        ? '$figure$gap$sym'
        : '$sym$gap$figure';
  }
}

/// ISO 4217 code the ACTIVE COOPERATIVE keeps its books in. Falls back to the
/// wallet and then the member's country for cooperatives that never set one.
String cooperativeCurrencyCode(UserModel user) {
  final c = user.cooperativeCurrency?.trim().toUpperCase();
  if (c != null && c.length == 3) return c;
  return resolveCurrencyCode(user);
}

/// The active cooperative's symbol — its own setting when it has one, so a
/// cooperative that writes "N" or "GH¢" gets what it asked for.
String cooperativeCurrencySymbol(UserModel user) {
  final s = user.cooperativeCurrencySymbol?.trim();
  if (s != null && s.isNotEmpty) return s;
  return currencySymbolForCode(cooperativeCurrencyCode(user));
}

/// Everything a screen needs to write the active cooperative's money.
CurrencyDisplay cooperativeCurrencyDisplay(UserModel user) => CurrencyDisplay(
      code: cooperativeCurrencyCode(user),
      symbol: cooperativeCurrencySymbol(user),
      position: currencySymbolPositionFrom(user.cooperativeCurrencySymbolPosition),
    );

/// The wallet's own denomination, written on the side the cooperative chose.
CurrencyDisplay walletCurrencyDisplay(UserModel user) =>
    cooperativeCurrencyDisplay(user).forCurrency(resolveCurrencyCode(user));

/// Localized currency symbol for [code] (e.g. NGN → ₦).
String currencySymbolForCode(String currencyCode) {
  final code = currencyCode.trim().toUpperCase();
  if (code.isEmpty) return '';
  try {
    return NumberFormat.simpleCurrency(name: code).currencySymbol;
  } catch (_) {
    return '$code ';
  }
}

String currencySymbolForUser(UserModel user) =>
    currencySymbolForCode(resolveCurrencyCode(user));

/// Major-unit name for "amount in words" style labels (English).
String majorCurrencyNameForCode(String currencyCode) {
  switch (currencyCode.trim().toUpperCase()) {
    case 'NGN':
      return 'Naira';
    case 'GHS':
      return 'Cedis';
    case 'KES':
      return 'Shillings';
    case 'ZAR':
      return 'Rand';
    case 'UGX':
      return 'Shillings';
    case 'TZS':
      return 'Shillings';
    case 'RWF':
      return 'Francs';
    case 'XOF':
    case 'XAF':
      return 'Francs';
    case 'USD':
      return 'Dollars';
    case 'EUR':
      return 'Euro';
    case 'GBP':
      return 'Pounds';
    default:
      return currencyCode.trim().toUpperCase();
  }
}
