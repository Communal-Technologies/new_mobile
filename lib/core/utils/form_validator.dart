import 'dart:developer';

class FormValidator {
  static String? isValidEmail(String? email) {
    final RegExp emailRegExp =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (!emailRegExp.hasMatch(email!)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? isValidFirstName(String? firstName) {
    if (firstName == null || firstName.isEmpty) {
      return 'Please enter your first name.';
    }

    final firstNameRegExp = RegExp(r'^[a-zA-Z]{3,}$');
    if (!firstNameRegExp.hasMatch(firstName)) {
      return 'Please enter a valid first name.';
    }

    if (firstName.length > 85) {
      return 'First name must not exceed 85 characters.';
    }

    return null;
  }

  static String? isValidLastName(String? lastName) {
    if (lastName == null || lastName.isEmpty) {
      return 'Please enter your last name.';
    }

    final lastNameRegExp = RegExp(r'^[a-zA-Z]{3,}$');
    if (!lastNameRegExp.hasMatch(lastName)) {
      return 'Please enter a valid last name.';
    }

    if (lastName.length > 85) {
      return 'Last name must not exceed 85 characters.';
    }

    return null;
  }

  static String? isValidOTP(
    String? data,
  ) {
    if (data == null || data.isEmpty) {
      return 'Please enter an OTP.';
    }
    if (data.length > 4) {
      return 'OTP must not exceed 4 characters.';
    }
    if (data.length < 4) {
      return 'OTP must be atleast 4 Characters';
    }
    return null;
  }

  static String? isValidReferralCode(
    String? data,
  ) {
    if (data == null || data.isEmpty) {
      return null;
    }
    if (data.length > 6) {
      return 'Referral must not exceed 6 characters.';
    }
    if (data.length < 6) {
      return 'Referral must be at least 6 characters';
    }
    return null;
  }

  static String? isValidPromoCode(
    String? data,
  ) {
    if (data == null || data.isEmpty) {
      return "Please enter a promo code.";
    }
    if (data.length < 6) {
      return 'Promo code must be at least 5 characters';
    }
    return null;
  }

  static String? isValidPassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Please enter a password.';
    }

    // Check for at least 8 characters
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    return null;
  }

  static String? isValidPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return 'Please enter a phone number.';
    }
    if (phoneNumber.length > 14) {
      return 'Phone number must not exceed 11 digits.';
    }
    if (phoneNumber.length < 10) {
      return 'Phone number must have at least 10 digits.';
    }
    if (!RegExp(r'^\+?\d+$').hasMatch(phoneNumber)) {
      return 'Phone number should only contain digits.';
    }

    return null;
  }
}
