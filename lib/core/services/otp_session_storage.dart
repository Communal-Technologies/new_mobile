import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Which verification flow a persisted session belongs to. Each flow gets its
/// own prefs slot so a takeover session can't overwrite a signup session (or
/// vice versa), and so a user who abandons one flow doesn't poison another.
enum OtpFlow {
  /// Self-signup verification (PhoneVerificationScreen).
  signup,

  /// Continuation of signup after login-checker (VerifyResetScreen with
  /// isInitialSetup = true).
  initialSetup,

  /// Forgot-password reset (VerifyResetScreen with isForgotPassword = true).
  passwordReset,

  /// Plain verification / login OTP (VerifyResetScreen with neither flag).
  verification,

  /// Session takeover after a login on another device still has a session.
  sessionTakeover,
}

/// Snapshot of an in-flight OTP verification: which contact it was sent to,
/// how, and when. Persisted so that if the app is closed mid-flow (e.g. before
/// the resend timer expires), reopening it can resume the same verification
/// screen with the correct remaining countdown instead of losing the sent code
/// and starting over with a fresh resend.
///
/// Exactly one of [contact] / [challengeId] is required:
/// - signup / initialSetup / passwordReset / verification -> [contact]
/// - sessionTakeover -> [challengeId]
class PendingOtpSession {
  const PendingOtpSession({
    required this.flow,
    required this.contact,
    required this.challengeId,
    required this.isEmail,
    required this.methodKey,
    required this.userId,
    required this.sentAtMs,
    required this.resendWindowSeconds,
  });

  final OtpFlow flow;

  /// Phone number in API format or email address. Empty for sessionTakeover.
  final String contact;

  /// Backend challenge id. Only populated for sessionTakeover.
  final String? challengeId;

  final bool isEmail;

  /// One of 'email', 'sms', 'whatsapp', 'call', 'auto' — used only to match
  /// this session back to the right screen args, not sent to the backend.
  final String methodKey;

  /// Only populated for signup / initialSetup.
  final String? userId;

  /// Unix ms when the OTP was issued. The resend countdown is derived from
  /// this + [resendWindowSeconds], so a cold start resumes mid-countdown.
  final int sentAtMs;

  /// Length of the resend window the backend / screen agreed to, in seconds.
  /// Stored on the session so a later change to [AppConstants] doesn't
  /// retroactively extend a window that was already running.
  final int resendWindowSeconds;

  int get remainingSeconds {
    final elapsed =
        ((DateTime.now().millisecondsSinceEpoch - sentAtMs) / 1000).floor();
    final remaining = resendWindowSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  Map<String, dynamic> toJson() => {
        'flow': flow.name,
        'contact': contact,
        'challengeId': challengeId,
        'isEmail': isEmail,
        'methodKey': methodKey,
        'userId': userId,
        'sentAtMs': sentAtMs,
        'resendWindowSeconds': resendWindowSeconds,
      };

  factory PendingOtpSession.fromJson(Map<String, dynamic> json) =>
      PendingOtpSession(
        flow: OtpFlow.values.firstWhere(
          (f) => f.name == json['flow'],
          orElse: () => OtpFlow.signup,
        ),
        contact: json['contact'] as String? ?? '',
        challengeId: json['challengeId'] as String?,
        isEmail: json['isEmail'] as bool? ?? false,
        methodKey: json['methodKey'] as String? ?? 'sms',
        userId: json['userId'] as String?,
        sentAtMs: json['sentAtMs'] as int? ?? 0,
        resendWindowSeconds: json['resendWindowSeconds'] as int? ?? 600,
      );
}

/// SharedPreferences-backed store for [PendingOtpSession] — one slot per
/// [OtpFlow], so concurrent/abandoned flows don't collide.
class OtpSessionStorage {
  static const _keyPrefix = 'pending_otp_session_v2_';

  String _keyFor(OtpFlow flow) => '$_keyPrefix${flow.name}';

  Future<void> save(PendingOtpSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(session.flow), jsonEncode(session.toJson()));
  }

  Future<PendingOtpSession?> load(OtpFlow flow) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(flow));
    if (raw == null) return null;
    try {
      return PendingOtpSession.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt/old-shape entry — drop it rather than crash the app on launch.
      await clear(flow);
      return null;
    }
  }

  Future<void> clear(OtpFlow flow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(flow));
  }

  /// Wipe every flow's session. Used when we know the user is done with
  /// verification entirely (e.g. successful auth) and no stale timer should
  /// survive into a future session.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final flow in OtpFlow.values) {
      await prefs.remove(_keyFor(flow));
    }
  }
}