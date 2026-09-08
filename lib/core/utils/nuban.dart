/// NUBAN arithmetic, used to narrow the bank list while an account number is
/// still being typed.
///
/// A 10-digit NUBAN does **not** contain its bank code — it is a 9-digit serial
/// plus one check digit. But the check digit is *derived* from the bank's 3-digit
/// code (CBN NUBAN spec): concatenate `bankCode + serial` into 12 digits, weight
/// them 3,7,3 repeating, sum, and the check digit is `(10 - sum % 10) % 10`.
///
/// So the code cannot be read out of a number, but it can be *eliminated*: only
/// about one bank code in ten produces the check digit the member typed. That is
/// what turns a 750-entry list into a shortlist the moment the tenth digit
/// lands, with no network call.
///
/// Numbers that are not NUBANs — the 11-digit phone-number accounts OPay and
/// PalmPay issue — are left alone rather than guessed at.
library;

const List<int> _weights = [3, 7, 3, 3, 7, 3, 3, 7, 3, 3, 7, 3];

bool isNubanShaped(String accountNumber) =>
    accountNumber.length == 10 && _isAllDigits(accountNumber);

bool _isAllDigits(String value) {
  if (value.isEmpty) return false;
  for (final unit in value.codeUnits) {
    if (unit < 0x30 || unit > 0x39) return false;
  }
  return true;
}

/// The check digit a 9-digit `serial` would carry at the bank whose 3-digit
/// code is `bankCode`, or `null` when either input is not the right shape.
int? nubanCheckDigit(String bankCode, String serial) {
  if (bankCode.length != 3 || !_isAllDigits(bankCode)) return null;
  if (serial.length != 9 || !_isAllDigits(serial)) return null;

  final digits = '$bankCode$serial';
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += (digits.codeUnitAt(i) - 0x30) * _weights[i];
  }
  return (10 - sum % 10) % 10;
}

/// Whether `accountNumber` could have been issued by the bank whose 3-digit
/// code is `bankCode`.
///
/// Answers `true` for anything it cannot check — a short number, an 11-digit
/// fintech account, a bank whose code is not three digits. Narrowing is a
/// convenience, so an unknown must never hide a bank the member wants.
bool nubanMatchesBank(String accountNumber, String bankCode) {
  if (!isNubanShaped(accountNumber)) return true;
  final expected = nubanCheckDigit(bankCode, accountNumber.substring(0, 9));
  if (expected == null) return true;
  return expected == accountNumber.codeUnitAt(9) - 0x30;
}

/// The subset of `codes` that could have issued `accountNumber`.
///
/// Returns every code unchanged when the number is not checkable, and also when
/// nothing matches — an empty shortlist would be a dead end for the member, and
/// a bank whose registry code is not its NUBAN issuer code is the likelier
/// explanation than the number being wrong.
List<String> banksMatchingNuban(String accountNumber, Iterable<String> codes) {
  if (!isNubanShaped(accountNumber)) return codes.toList();
  final matches = codes.where((c) => nubanMatchesBank(accountNumber, c)).toList();
  return matches.isEmpty ? codes.toList() : matches;
}
