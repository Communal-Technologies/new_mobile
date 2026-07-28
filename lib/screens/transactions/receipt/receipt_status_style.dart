import 'package:flutter/material.dart';

import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';

/// Audit M39: pulls the 11 status-driven styling values that used to live
/// as `extension` getters on `_ReceiptCard` into a plain value class.
///
/// Why split it out
/// ----------------
/// - **Testability** — every property here is now a pure function of
///   `(status, failureReason)`. The receipt-screen widget tests don't
///   need to render the whole card to assert that "failed" yields the
///   red palette.
/// - **Single source of truth** — the same status mapping was repeated
///   across hero / pill / footer / status-label getters. One value
///   object means a tweak (new colour, new copy) updates one file.
/// - **Composability** — sub-widgets ([ReceiptStatusHero],
///   [ReceiptAmountPill], [ReceiptFooterNote]) take a [ReceiptStatusStyle]
///   instead of a `TransactionStatus`, so they don't have to know the
///   colour palette themselves.
class ReceiptStatusStyle {
  ReceiptStatusStyle({
    required this.status,
    String? failureReason,
    this.brightness = Brightness.light,
  }) : _failureReason = failureReason?.trim();

  final TransactionStatus status;
  final String? _failureReason;

  /// Active theme brightness — controls whether the hero / footer
  /// tints render as the original light pastels or as a dark-mode-safe
  /// mix of the status accent + surface. Defaults to light so the
  /// pure-function getters stay drop-in for tests / receipt export.
  final Brightness brightness;

  bool get _isDark => brightness == Brightness.dark;

  /// Large hero amount duplicates the pill on failed/pending; keep pill only.
  bool get showHeroAmount => status == TransactionStatus.successful;

  IconData get heroIcon {
    switch (status) {
      case TransactionStatus.pending:
        return Icons.access_time_rounded;
      case TransactionStatus.failed:
        return Icons.cancel_rounded;
      case TransactionStatus.successful:
        return Icons.check_circle;
    }
  }

  Color get heroBackground {
    if (_isDark) {
      // Mix the status accent with the dark surface so the hero
      // halo stays perceptible without rendering as a bright pastel
      // block on the dark card.
      return statusColor.withValues(alpha: 0.16);
    }
    switch (status) {
      case TransactionStatus.pending:
        return const Color(0xFFFFF4E6);
      case TransactionStatus.failed:
        return const Color(0xFFFFEEF0);
      case TransactionStatus.successful:
        return const Color(0xFFE4FAF1);
    }
  }

  String get title {
    switch (status) {
      case TransactionStatus.pending:
        return 'Transaction Pending';
      case TransactionStatus.failed:
        return 'Sorry, Payment Failed';
      case TransactionStatus.successful:
        return 'Transfer Successful!';
    }
  }

  String get subtitle {
    switch (status) {
      case TransactionStatus.pending:
        return 'Your transaction is being processed';
      case TransactionStatus.failed:
        if (_failureReason != null && _failureReason.isNotEmpty) {
          return _humanizeTransferFailure(_failureReason);
        }
        return 'Your transfer request was not successful';
      case TransactionStatus.successful:
        return 'Your money has been sent successfully';
    }
  }

  String get cardHeaderTitle {
    switch (status) {
      case TransactionStatus.successful:
        return 'Transaction Receipt';
      case TransactionStatus.pending:
      case TransactionStatus.failed:
        return 'Transfer details';
    }
  }

  String footerNote(String? overrideNote) {
    switch (status) {
      case TransactionStatus.successful:
        return overrideNote ??
            'This is a computer generated receipt and does not require a signature.';
      case TransactionStatus.pending:
        return 'This transfer is still processing. Reference and status update '
            'automatically. Download and share are available only after the '
            'transfer succeeds.';
      case TransactionStatus.failed:
        if (_failureReason != null && _failureReason.isNotEmpty) {
          return '${_humanizeTransferFailure(_failureReason)} If you need help, '
              'contact support.';
        }
        return 'This transfer did not complete successfully. If you need help, '
            'contact support.';
    }
  }

  Color get footerInfoBackground {
    if (_isDark) {
      return footerInfoIconColor.withValues(alpha: 0.16);
    }
    switch (status) {
      case TransactionStatus.successful:
        return const Color(0xFFE6FBFF);
      case TransactionStatus.pending:
        return const Color(0xFFFFF4E6);
      case TransactionStatus.failed:
        return const Color(0xFFFFEEF0);
    }
  }

  Color get footerInfoIconColor {
    switch (status) {
      case TransactionStatus.successful:
        return const Color(0xFF4CB0C9);
      case TransactionStatus.pending:
        return const Color(0xFFE6A502);
      case TransactionStatus.failed:
        return const Color(0xFFD7263D);
    }
  }

  List<Color> get amountPillGradient {
    switch (status) {
      case TransactionStatus.pending:
        return const [Color(0xFFFF9800), Color(0xFFF57C00)];
      case TransactionStatus.failed:
        return const [Color(0xFFFB5A5A), Color(0xFFED1B2D)];
      case TransactionStatus.successful:
        return const [Color(0xFF00C950), Color(0xFF00A63E)];
    }
  }

  Color get statusColor {
    switch (status) {
      case TransactionStatus.pending:
        return const Color(0xFFE6A502);
      case TransactionStatus.failed:
        return const Color(0xFFD7263D);
      case TransactionStatus.successful:
        return const Color(0xFF1AAE70);
    }
  }

  String get statusLabel {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.successful:
        return 'Successful';
    }
  }
}

String _humanizeTransferFailure(String code) {
  final normalized = code.toUpperCase().trim().replaceAll(' ', '_');
  switch (normalized) {
    case 'INSUFFICIENT_BALANCE':
      return 'Insufficient balance to complete this transfer.';
    case 'ACCOUNT_FROZEN':
    case 'DESTINATION_ACCOUNT_FROZEN':
    case 'BENEFICIARY_ACCOUNT_FROZEN':
      return 'The receiving account is frozen and cannot accept transfers. '
          'Contact the cooperative to have it unfrozen, or pay to a different account.';
    case 'SOURCE_ACCOUNT_FROZEN':
      return 'Your account is frozen and cannot send transfers. Contact support.';
    case 'INVALID_BANK_ID':
    case 'INVALID_BANK_CODE':
      return 'The receiving account has an invalid bank setting. '
          'Ask the cooperative administrator to re-select the bank for this account.';
    case 'ACCOUNT_NOT_FOUND':
    case 'INVALID_ACCOUNT_NUMBER':
      return 'The receiving account number could not be found at its bank.';
    case 'LIMIT_EXCEEDED':
    case 'TRANSACTION_LIMIT_EXCEEDED':
      return 'This transfer exceeds your transaction limit.';
    default:
      final t = code.replaceAll('_', ' ').trim().toLowerCase();
      return t.isEmpty ? 'This transfer could not be completed.' : t;
  }
}
