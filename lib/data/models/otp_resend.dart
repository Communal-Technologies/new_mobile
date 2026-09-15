/// What authsvc reported after resending a sign-in code. Both figures are the
/// server's own, in seconds, so a screen never has to guess its countdowns.
class OtpResendResult {
  const OtpResendResult({this.otpExpiresIn, this.resendAvailableIn});

  /// How long the new code — and the sign-in step carrying it — stays valid.
  final int? otpExpiresIn;

  /// How long until another resend will be accepted.
  final int? resendAvailableIn;
}

/// A resend the server refused, with what the screen needs to react to it.
class OtpResendException implements Exception {
  const OtpResendException(
    this.message, {
    this.retryAfterSeconds,
    this.challengeExpired = false,
  });

  final String message;

  /// Set when the refusal was a cooldown: resend opens again after this long.
  final int? retryAfterSeconds;

  /// The sign-in step itself is gone; only logging in again can continue.
  final bool challengeExpired;

  @override
  String toString() => message;
}
