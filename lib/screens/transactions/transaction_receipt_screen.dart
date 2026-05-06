import 'dart:async';

import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/loans/data/loan_nip_settlement.dart';
import 'package:communal_mobile/screens/obligations/data/fine_nip_settlement.dart';
import 'package:communal_mobile/screens/obligations/data/obligation_nip_settlement.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/screens/transactions/receipt/receipt_export_helper.dart';
import 'package:communal_mobile/screens/transactions/receipt/widgets/receipt_action_button.dart';
import 'package:communal_mobile/screens/transactions/receipt/widgets/receipt_card.dart';

enum ReceiptAction { preview, download, share }

/// Audit M39: refactored from a 905-line monolith into a thin orchestrator.
/// The card visuals live in `receipt/widgets/receipt_card.dart`, the
/// status palette / copy lives in `receipt/receipt_status_style.dart`,
/// and capture / save / share / permission lives in
/// `receipt/receipt_export_helper.dart`. This file owns:
///
/// - the `_details` state + the pending-status poller
/// - the optional obligation-NIP record-payment side-effect
/// - the build tree (Scaffold + RepaintBoundary(ReceiptCard) + buttons)
/// - the wire from the action buttons to the export helper
class TransactionReceiptScreen extends StatefulWidget {
  const TransactionReceiptScreen({
    super.key,
    required this.details,
    this.initialAction,
    this.obligationNipSettlement,
    this.loanNipSettlement,
    this.fineNipSettlement,
  });

  final TransactionDetailsData details;
  final ReceiptAction? initialAction;

  /// When the NIP transfer succeeds, post obligation payment then navigate to success.
  final ObligationNipSettlement? obligationNipSettlement;

  /// Same idea but for loan repayments. Receipt screen records the
  /// loan repayment via the no-biometric record route once the
  /// upstream transfer reports successful.
  final LoanNipSettlement? loanNipSettlement;

  /// Same idea but for fine payments.
  final FineNipSettlement? fineNipSettlement;

  @override
  State<TransactionReceiptScreen> createState() =>
      _TransactionReceiptScreenState();
}

class _TransactionReceiptScreenState extends State<TransactionReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  final _repo = getIt<TransferRepository>();
  final _obligationsRepo = MemberObligationsRepository(getIt());
  final _loanRepo = LoanRepository(getIt());
  late final ReceiptExportHelper _exporter;
  late TransactionDetailsData _details;
  Timer? _pollTimer;
  int _pollTicks = 0;
  static const int _maxPollTicks = 45;
  bool _obligationNipPosted = false;
  bool _loanNipPosted = false;
  bool _fineNipPosted = false;

  @override
  void initState() {
    super.initState();
    _details = widget.details;
    _exporter = ReceiptExportHelper(onMessage: _showSnack);

    if (widget.initialAction != null &&
        _details.status == TransactionStatus.successful) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        switch (widget.initialAction!) {
          case ReceiptAction.download:
            // ignore: unawaited_futures
            _downloadReceipt();
            break;
          case ReceiptAction.share:
            // ignore: unawaited_futures
            _shareReceipt();
            break;
          case ReceiptAction.preview:
            break;
        }
      });
    }
    // Wallet balance refresh on terminal status. Pending lands in the
    // poll loop below (refresh fires when it flips to successful), but
    // a transfer that returns SUCCESSFUL on the initial response (book
    // transfers commonly do) used to skip the refresh entirely — so
    // the home/transfer screens kept showing the pre-transfer balance
    // until the user navigated away and back. Schedule a refresh on
    // first frame for any non-pending arrival.
    if (_details.status != TransactionStatus.pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AuthBloc>().add(AuthRefreshUserRequested());
      });
    }
    if (_details.status == TransactionStatus.pending &&
        _details.id.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: unawaited_futures
        _refreshTransferStatus();
        _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          if (!mounted) return;
          if (_details.status != TransactionStatus.pending) {
            _pollTimer?.cancel();
            _pollTimer = null;
            return;
          }
          if (_pollTicks >= _maxPollTicks) {
            _pollTimer?.cancel();
            _pollTimer = null;
            return;
          }
          // ignore: unawaited_futures
          _refreshTransferStatus();
        });
      });
    } else if (widget.obligationNipSettlement != null &&
        _details.status == TransactionStatus.successful) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: unawaited_futures
        _postObligationNipIfNeeded();
      });
    } else if (widget.loanNipSettlement != null &&
        _details.status == TransactionStatus.successful) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: unawaited_futures
        _postLoanNipIfNeeded();
      });
    } else if (widget.fineNipSettlement != null &&
        _details.status == TransactionStatus.successful) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: unawaited_futures
        _postFineNipIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshTransferStatus() async {
    if (_details.status != TransactionStatus.pending) return;
    _pollTicks++;
    try {
      final remote = await _repo.fetchTransferStatus(_details.id);
      if (!mounted) return;
      final mapped = transactionStatusFromApi(remote.statusRaw);
      final ref = remote.reference.trim().isNotEmpty
          ? remote.reference.trim()
          : _details.reference;
      setState(() {
        _details = _details.copyWith(
          status: mapped,
          reference: ref,
          amount: remote.amountKobo != null
              ? remote.amountKobo! / 100.0
              : _details.amount,
          dateTime: remote.providerOccurredAt ?? _details.dateTime,
          failureReason: mapped == TransactionStatus.failed
              ? remote.failureReason
              : null,
          clearFailureReason: mapped != TransactionStatus.failed,
          note: mapped == TransactionStatus.successful
              ? (_details.note ??
                  'This is a computer generated receipt and does not require a signature.')
              : _details.note,
        );
      });
      if (mapped != TransactionStatus.pending) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
      if (mapped == TransactionStatus.successful) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<AuthBloc>().add(AuthRefreshUserRequested());
          // ignore: unawaited_futures
          _postObligationNipIfNeeded();
          // ignore: unawaited_futures
          _postLoanNipIfNeeded();
          // ignore: unawaited_futures
          _postFineNipIfNeeded();
        });
      }
    } catch (_) {
      // Keep showing last-known state; user can leave screen.
    }
  }

  Future<void> _postObligationNipIfNeeded() async {
    final settlement = widget.obligationNipSettlement;
    if (settlement == null || _obligationNipPosted) return;
    if (_details.status != TransactionStatus.successful) return;

    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    _obligationNipPosted = true;
    try {
      // The record step hits the no-biometric `/record-nip-obligation-payment`
      // endpoint. The upstream `/transfer/initiate` already required a
      // biometric signature (or PIN fallback), and the backend
      // independently re-verifies this transfer belongs to this member
      // and completed at Anchor for the right amount + cash repo. A
      // second biometric prompt here used to silently fail when the
      // user dismissed it or hadn't enrolled — wallet debited but
      // obligation never incremented.
      await _obligationsRepo.recordNipObligationPayment(
        user: auth.user,
        obligationAccountCode: settlement.obligationAccountCode,
        transferId: _details.id.trim(),
        cashRepositoryId: settlement.cashRepositoryId,
        amountMinor: settlement.amountMinor,
      );
      if (!mounted) return;
      final ref = _details.reference.trim().isNotEmpty
          ? _details.reference.trim()
          : _details.id.trim();
      context.goNamed(
        'obligation-payment-success',
        extra: {
          'obligation': Obligation.forSuccessSummary(
            title: settlement.obligationTitle,
            category: settlement.obligationCategory,
            currency: settlement.currency,
          ),
          'amountMinor': settlement.amountMinor,
          'method': 'Bank transfer',
          'reference': ref,
          'date': DateTime.now(),
        },
      );
    } catch (e) {
      _obligationNipPosted = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transfer succeeded but the obligation could not be updated. '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  /// Loan analogue of [_postObligationNipIfNeeded]. Same shape: posts
  /// to the no-biometric `/record-nip-payment` route after the
  /// upstream transfer reports successful, leaves the user on the
  /// receipt screen (no separate loan-success screen yet — the receipt
  /// IS the success).
  Future<void> _postLoanNipIfNeeded() async {
    final settlement = widget.loanNipSettlement;
    if (settlement == null || _loanNipPosted) return;
    if (_details.status != TransactionStatus.successful) return;

    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    _loanNipPosted = true;
    try {
      await _loanRepo.recordNipLoanPayment(
        user: auth.user,
        loanId: settlement.loanId,
        transferId: _details.id.trim(),
        cashRepositoryId: settlement.cashRepositoryId,
        amountMinor: settlement.amountMinor,
      );
    } catch (e) {
      _loanNipPosted = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transfer succeeded but the loan could not be updated. '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _postFineNipIfNeeded() async {
    final settlement = widget.fineNipSettlement;
    if (settlement == null || _fineNipPosted) return;
    if (_details.status != TransactionStatus.successful) return;

    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    _fineNipPosted = true;
    try {
      await _obligationsRepo.recordNipFinePayment(
        user: auth.user,
        fineId: settlement.fineId,
        transferId: _details.id.trim(),
        cashRepositoryId: settlement.cashRepositoryId,
        amountMinor: settlement.amountMinor,
        cooperativeId: settlement.cooperativeId,
      );
    } catch (e) {
      _fineNipPosted = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transfer succeeded but the fine could not be updated. '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _downloadReceipt() async {
    final bytes = await _exporter.captureImage(_receiptKey);
    if (!mounted) return;
    if (_details.status != TransactionStatus.successful) {
      _showSnack('Receipt is available after the transfer succeeds.');
      return;
    }
    if (bytes == null) {
      _showSnack('Could not prepare receipt for download.');
      return;
    }
    await _exporter.saveToGallery(
      bytes,
      fileName: 'communal_receipt_'
          '${_receiptIdentifier}_'
          '${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> _shareReceipt() async {
    final bytes = await _exporter.captureImage(_receiptKey);
    if (!mounted) return;
    if (_details.status != TransactionStatus.successful) {
      _showSnack('Receipt is available after the transfer succeeds.');
      return;
    }
    if (bytes == null) {
      _showSnack('Unable to capture receipt.');
      return;
    }
    await _exporter.share(
      bytes,
      shareText:
          'Transaction receipt • ${_details.transactionType} • ${_details.amountLabel}',
    );
  }

  String get _receiptIdentifier {
    final raw = _details.reference;
    final sanitized = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    return sanitized.isEmpty ? 'transaction' : sanitized;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: PopScope(
        // Intercept the system back gesture so it routes by status, the
        // same way the AppBar arrow now does. canPop:false stops the
        // default pop; we handle navigation in onPopInvokedWithResult.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleReceiptBack();
        },
        child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: theme.scaffoldBackgroundColor,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 18.sp,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: _handleReceiptBack,
          ),
          title: Text(
            'Transaction Status',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
            child: Column(
              children: [
                RepaintBoundary(
                  key: _receiptKey,
                  child: ReceiptCard(details: _details),
                ),
                vSpace(24),
                if (_details.status == TransactionStatus.successful) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ReceiptActionButton(
                          label: 'Download',
                          icon: Iconsax.import,
                          background: theme.brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFF0E6FF),
                          foreground: theme.brightness == Brightness.dark
                              ? Colors.white
                              : theme.primaryColor,
                          onTap: _downloadReceipt,
                        ),
                      ),
                      hSpace(12),
                      Expanded(
                        child: ReceiptActionButton(
                          label: 'Share',
                          icon: Iconsax.export_1,
                          background: theme.primaryColor,
                          foreground: Colors.white,
                          onTap: _shareReceipt,
                        ),
                      ),
                    ],
                  ),
                  vSpace(16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ReceiptActionButton(
                    label: 'Make Another Transfer',
                    icon: Iconsax.arrow_swap_horizontal,
                    background: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFEFE6FD),
                    foreground: theme.brightness == Brightness.dark
                        ? Colors.white
                        : theme.primaryColor,
                    onTap: () => context.goNamed('transfer'),
                  ),
                ),
                vSpace(10),
                SizedBox(
                  width: double.infinity,
                  child: ReceiptActionButton(
                    label: 'Back to Home',
                    icon: Iconsax.home,
                    background: theme.primaryColor,
                    foreground: Colors.white,
                    onTap: () => context.goNamed('home'),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  /// Receipt back-button routing.
  ///
  /// Successful + pending: skip the prior verify/amount screens and
  /// drop the user back on Home — they're done with this transfer
  /// either way and the back-stack is noisy with confirmation steps.
  ///
  /// Failed: show a sheet asking whether to retry. Yes pops back to
  /// the verify/amount screen so the user can re-submit; No goes
  /// straight to Home.
  void _handleReceiptBack() {
    switch (_details.status) {
      case TransactionStatus.successful:
      case TransactionStatus.pending:
        context.goNamed('home');
        break;
      case TransactionStatus.failed:
        _showRetrySheet();
        break;
    }
  }

  Future<void> _showRetrySheet() async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
                vSpace(16),
                Text(
                  'Try this transfer again?',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                vSpace(6),
                Text(
                  'We\'ll take you back to the amount screen so you can '
                  'fix anything and resend. Choose No to head home.',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.65),
                  ),
                ),
                vSpace(20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          side: BorderSide(color: theme.dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'No, go home',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    hSpace(12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(true),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Yes, retry',
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (result == true) {
      // Pop back to whatever screen launched the receipt — usually
      // the verify screen, which was navigated from the amount
      // screen. maybePop handles either case (and is a no-op if the
      // receipt is the only route on the stack, in which case Home
      // is the safest fallback).
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.goNamed('home');
      }
    } else if (result == false) {
      context.goNamed('home');
    }
    // result == null → user dismissed by tapping the scrim; stay on
    // the receipt rather than navigating somewhere they didn't ask for.
  }
}
