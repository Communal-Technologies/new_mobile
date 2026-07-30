import 'package:communal_mobile/core/constants/constants.dart';

/// Centralized form validators for input fields.
///
/// Audit M22 / M24 / M25: each validator below mirrors the **actual**
/// backend rule shipped today, not the generic-app stub it used to be.
/// Where the backend distinguishes mobile from web, the mobile rule is
/// what's enforced here (this is the mobile app).
class FormValidator {
  /// Email validator. Same regex shape as before — broad enough for the
  /// real-world email surface we accept (includes `+` aliases) and matches
  /// what the backend's FILTER_VALIDATE_EMAIL rejects.
  static String? isValidEmail(String? email) {
    final RegExp emailRegExp =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (email == null || !emailRegExp.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// First-name validator. Audit M24: the legacy regex `^[a-zA-Z]{3,}$`
  /// rejected accents (María) and hyphenated names (Mary-Anne) — broken for
  /// any diaspora user. This version accepts Unicode letters, marks (for
  /// composed accents), spaces, hyphens, and apostrophes.
  static String? isValidFirstName(String? firstName) {
    if (firstName == null || firstName.isEmpty) {
      return 'Please enter your first name.';
    }
    final value = firstName.trim();
    if (value.length < 2) {
      return 'First name must be at least 2 characters.';
    }
    if (value.length > 85) {
      return 'First name must not exceed 85 characters.';
    }
    if (!_kNameRegExp.hasMatch(value)) {
      return 'Please enter a valid first name.';
    }
    return null;
  }

  /// Last-name validator. Same Unicode-aware rule as [isValidFirstName].
  static String? isValidLastName(String? lastName) {
    if (lastName == null || lastName.isEmpty) {
      return 'Please enter your last name.';
    }
    final value = lastName.trim();
    if (value.length < 2) {
      return 'Last name must be at least 2 characters.';
    }
    if (value.length > 85) {
      return 'Last name must not exceed 85 characters.';
    }
    if (!_kNameRegExp.hasMatch(value)) {
      return 'Please enter a valid last name.';
    }
    return null;
  }

  /// OTP validator. Audit M25: length is no longer hardcoded — it reads
  /// [AppConstants.otpLength] so a future backend bump (e.g. 6 → 8) is a
  /// single-line change. Today's value is 6, matching the OTP screens
  /// (verify-reset, session-takeover, phone-verification).
  static String? isValidOTP(String? data) {
    final expected = AppConstants.otpLength;
    if (data == null || data.isEmpty) {
      return 'Please enter the verification code.';
    }
    if (data.length != expected) {
      return 'Code must be $expected digits.';
    }
    if (!_kDigitsOnly.hasMatch(data)) {
      return 'Code must contain only digits.';
    }
    return null;
  }

  static String? isValidReferralCode(String? data) {
    if (data == null || data.isEmpty) return null;
    if (data.length != 6) {
      return 'Referral code must be 6 characters.';
    }
    return null;
  }

  static String? isValidPromoCode(String? data) {
    if (data == null || data.isEmpty) {
      return 'Please enter a promo code.';
    }
    if (data.length < 5) {
      return 'Promo code must be at least 5 characters.';
    }
    return null;
  }

  /// PIN/password validator. Audit M22: mobile uses a **6-digit numeric
  /// PIN**, not the generic 8-char password the legacy validator was
  /// checking against. Mirrors the backend `mobile_app` platform rules
  /// (`AuthController::resetPassword`): length 6, digits only, not all
  /// the same digit. The actual create-password flow validates inline in
  /// `AuthBloc._onCreatePasswordRequested` — this method is the shared
  /// helper any future form should use to get the same answer.
  static String? isValidPassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Please enter a PIN.';
    }
    if (password.length != 6) {
      return 'PIN must be exactly 6 digits.';
    }
    if (!_kDigitsOnly.hasMatch(password)) {
      return 'PIN must contain only digits.';
    }
    final firstChar = password[0];
    if (password.split('').every((c) => c == firstChar)) {
      return 'PIN cannot be all the same digit.';
    }
    return null;
  }

  static String? isValidPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return 'Please enter a phone number.';
    }
    if (phoneNumber.length > 14) {
      return 'Phone number must not exceed 14 digits.';
    }
    if (phoneNumber.length < 10) {
      return 'Phone number must have at least 10 digits.';
    }
    if (!_kPhoneRegExp.hasMatch(phoneNumber)) {
      return 'Phone number should only contain digits.';
    }
    return null;
  }

  /// Unicode letter (\p{L}) + combining marks (\p{M}) + space + hyphen +
  /// apostrophe. Length bounds enforced separately so the regex stays
  /// focused on character composition.
  static final RegExp _kNameRegExp =
      RegExp(r"^[\p{L}\p{M}][\p{L}\p{M}\s'\-]+$", unicode: true);

  static final RegExp _kDigitsOnly = RegExp(r'^\d+$');
  static final RegExp _kPhoneRegExp = RegExp(r'^\+?\d+$');
}
