import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money_formatter.dart';
import 'package:communal_mobile/data/models/user_model.dart';

/// Audit M21: pre-validate a proposed transfer / payment amount against
/// the user's KYC tier limits **before** navigating to the review screen
/// or making the network round-trip. Returns `null` when the amount is
/// allowed, or a user-facing error message ready for a snackbar / inline
/// field error when it isn't.
///
/// Two failure cases today:
///
/// 1. `tier_0` (or any pre-verification tier) — the user hasn't completed
///    KYC, so the backend will reject any transfer regardless of amount.
///    We surface that as "Complete identity verification to send money"
///    rather than letting the user enter an amount and then 4xx.
///
/// 2. Amount exceeds the current tier's `daily_transaction_limit_kobo` —
///    backend caps per-day spend at that ceiling. The simple per-tx check
///    here catches "user typed an amount that on its own exceeds the
///    daily cap". A future hardening could subtract today's already-spent
///    amount via `/api/v1/members/transfer/daily-usage` for an even
///    tighter check; that's filed as a follow-up.
///
/// When `user.tierLimits` is null (the `/get-loggedin-user` payload
/// hasn't included them yet) the function returns `null` — defer to
/// backend rather than block the UI on missing data.
String? checkTransferAgainstTierLimits({
  required UserModel user,
  required int amountMinor,
  required String currency,
}) {
  final limits = user.tierLimits;
  if (limits == null) return null;

  final current = limits.current;
  if (current.isPreVerificationTier) {
    return 'Complete identity verification to send money.';
  }

  final cap = current.dailyTransactionLimitKobo;
  if (cap > 0 && amountMinor > cap) {
    final symbol = currencySymbolForCode(currency);
    final formatted = formatMinor(cap, currency);
    return 'Amount exceeds your ${current.label} daily limit of '
        '$symbol$formatted.';
  }

  return null;
}
