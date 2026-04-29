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
import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
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
  });

  final TransactionDetailsData details;
  final ReceiptAction? initialAction;

  /// When the NIP transfer succeeds, post obligation payment then navigate to success.
  final ObligationNipSettlement? obligationNipSettlement;

  @override
  State<TransactionReceiptScreen> createState() =>
      _TransactionReceiptScreenState();
}

class _TransactionReceiptScreenState extends State<TransactionReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  final _repo = getIt<TransferRepository>();
  final _obligationsRepo = MemberObligationsRepository(getIt());
  late final ReceiptExportHelper _exporter;
  late TransactionDetailsData _details;
  Timer? _pollTimer;
  int _pollTicks = 0;
  static const int _maxPollTicks = 45;
  bool _obligationNipPosted = false;

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
      // Audit M38: pay-obligation is biometric-gated server-side. Even
      // though the upstream transfer was already biometric-signed, the
      // bookkeeping call is a separate request and gets its own
      // signature triple. UX shows a second biometric prompt — accepted
      // trade-off for keeping the security model strict (every gated
      // endpoint requires its own signature, no cross-call reuse).
      final biometricHeaders =
          (await getIt<BiometricSignerService>().signObligationIntent(
        promptTitle: 'Record obligation payment',
        promptSubtitle: 'Use biometrics to record this payment',
      ))
              .toHeaders();
      await _obligationsRepo.recordNipObligationPayment(
        user: auth.user,
        obligationAccountCode: settlement.obligationAccountCode,
        transferId: _details.id.trim(),
        cashRepositoryId: settlement.cashRepositoryId,
        amountMinor: settlement.amountMinor,
        biometricHeaders: biometricHeaders,
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
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF7F8FB),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 18.sp,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Transaction Status',
            style: TextStyle(
              fontSize: 17.sp,
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
                          background: const Color(0xFFF0E6FF),
                          foreground: theme.primaryColor,
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
                    background: const Color(0xFFEFE6FD),
                    foreground: theme.primaryColor,
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
    );
  }
}
