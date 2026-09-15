/// What authsvc reported after resending a sign-in code. All figures are the
/// server's own, in seconds, so a screen never has to guess its countdowns.
class OtpResendResult {
  const OtpResendResult({
    this.otpExpiresIn,
    this.resendAvailableIn,
    this.challengeExpiresIn,
  });

  /// How long the new code stays valid.
  final int? otpExpiresIn;

  /// How long until another resend will be accepted — when that code expires.
  final int? resendAvailableIn;

  /// How long until the sign-in step itself closes and only a new login continues.
  final int? challengeExpiresIn;
}

/// A resend the server refused, with what the screen needs to react to it.
class OtpResendException implements Exception {
  const OtpResendException(
    this.message, {
    this.retryAfterSeconds,
    this.challengeExpired = false,
  });

  final String message;

  /// Set when resend is not open yet: it opens again after this long.
  final int? retryAfterSeconds;

  /// The sign-in step itself is gone; only logging in again can continue.
  final bool challengeExpired;

  @override
  String toString() => message;
}
