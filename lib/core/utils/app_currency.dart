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
String resolveCurrencyCode(UserModel user) {
  final w = user.walletCurrencyCode?.trim().toUpperCase();
  if (w != null && w.length == 3) return w;
  return currencyCodeFromCountryIso(user.countryIso);
}

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
