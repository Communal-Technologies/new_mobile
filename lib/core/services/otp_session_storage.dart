import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot of an in-flight signup OTP verification: which contact it was
/// sent to, how, and when. Persisted so that if the app is closed mid-flow
/// (e.g. before the resend timer expires), reopening it can resume the same
/// verification screen instead of losing the sent code and starting over.
class PendingOtpSession {
  const PendingOtpSession({
    required this.contact,
    required this.isEmail,
    required this.methodKey,
    required this.userId,
    required this.sentAtMs,
  });

  final String contact;
  final bool isEmail;

  /// One of 'email', 'sms', 'whatsapp', 'call' — used only to match this
  /// session back to the right screen args, not sent to the backend.
  final String methodKey;

  final String? userId;
  final int sentAtMs;

  Map<String, dynamic> toJson() => {
        'contact': contact,
        'isEmail': isEmail,
        'methodKey': methodKey,
        'userId': userId,
        'sentAtMs': sentAtMs,
      };

  factory PendingOtpSession.fromJson(Map<String, dynamic> json) =>
      PendingOtpSession(
        contact: json['contact'] as String,
        isEmail: json['isEmail'] as bool? ?? false,
        methodKey: json['methodKey'] as String? ?? 'sms',
        userId: json['userId'] as String?,
        sentAtMs: json['sentAtMs'] as int,
      );
}

/// Thin SharedPreferences-backed store for [PendingOtpSession].
///
/// Only one pending session is tracked at a time (a user can only be mid-way
/// through one signup verification at once), so a single fixed key is fine.
class OtpSessionStorage {
  static const _key = 'pending_otp_session_v1';

  Future<void> save(PendingOtpSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session.toJson()));
  }

  Future<PendingOtpSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return PendingOtpSession.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt/old-shape entry — drop it rather than crash the app on launch.
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
