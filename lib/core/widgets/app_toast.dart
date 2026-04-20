import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// App-wide toasts (aligned with sabi_vendor_hub_mobile): top slide-in via [toastification].
///
/// - **Success**: light card, green circle + check, dark message.
/// - **Error**: red fill, white text.
class AppToast {
  AppToast._();

  static const Duration _successDuration = Duration(seconds: 4);
  static const Duration _errorDuration = Duration(seconds: 9);
  static const Alignment _alignment = Alignment.topCenter;

  static const Color _successGreen = Color(0xFF22C55E);
  static const Color _errorRed = Color(0xFFE53935);
  static const Color _onSurface = Color(0xFF1A1A1A);

  static void success(String message) {
    toastification.showCustom(
      alignment: _alignment,
      autoCloseDuration: _successDuration,
      builder: (context, holder) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: _successGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: _onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Errors stay longer so users can read API / validation messages.
  static void error(String message, {Duration? autoCloseDuration}) {
    toastification.showCustom(
      alignment: _alignment,
      autoCloseDuration: autoCloseDuration ?? _errorDuration,
      builder: (context, holder) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _errorRed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
