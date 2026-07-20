import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/models/obligation_withdrawal_request.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/amount_input_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class ObligationWithdrawalScreen extends StatefulWidget {
  const ObligationWithdrawalScreen({super.key, required this.obligation});

  final Obligation obligation;

  @override
  State<ObligationWithdrawalScreen> createState() =>
      _ObligationWithdrawalScreenState();
}

class _ObligationWithdrawalScreenState
    extends State<ObligationWithdrawalScreen> {
  final _repository = MemberObligationsRepository(getIt());
  final _amountController = TextEditingController();

  List<ObligationWithdrawalRequest> _requests = const [];
  bool _loadingRequests = false;
  bool _submitting = false;
  bool _revoking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRequests());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    setState(() => _loadingRequests = true);
    try {
      final all = await _repository.fetchWithdrawalRequests(auth.user);
      final filtered = all
          .where((r) => r.accountCode == widget.obligation.accountCode)
          .toList();
      if (!mounted) return;
      setState(() {
        _requests = filtered;
        _loadingRequests = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRequests = false);
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    final raw = _amountController.text.trim().replaceAll(',', '');
    if (raw.isEmpty) {
      AppToast.error('Please enter an amount');
      return;
    }
    final major = double.tryParse(raw);
    if (major == null || major <= 0) {
      AppToast.error('Enter a valid amount');
      return;
    }
    final amountMinor = (major * 100).round();
    if (amountMinor > widget.obligation.paidAmountMinor) {
      AppToast.error('Amount exceeds your available balance');
      return;
    }

    // Block if a pending request already exists for this account
    final hasPending = _requests.any((r) => r.isPending);
    if (hasPending) {
      AppToast.error(
        'You already have a pending request for this account. '
        'Cancel it first if you want to submit a new one.',
      );
      return;
    }

    final confirmed = await _showConfirmDialog(amountMinor);
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      await _repository.submitWithdrawalRequest(
        user: auth.user,
        accountCode: widget.obligation.accountCode,
        amountMinor: amountMinor,
      );
      if (!mounted) return;
      _amountController.clear();
      AppToast.success('Withdrawal request submitted');
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _revoke(ObligationWithdrawalRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request'),
        content: Text(
          'Cancel your ${request.amountLabel} withdrawal request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Yes, Cancel',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _revoking = true);
    try {
      await _repository.revokeWithdrawalRequest(request.id);
      if (!mounted) return;
      AppToast.success('Request cancelled');
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  Future<bool> _showConfirmDialog(int amountMinor) async {
    final label = _formatMinor(amountMinor, widget.obligation.currency);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Confirm Request',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request a withdrawal of $label from your '
              '${widget.obligation.title} account?',
              style: TextStyle(fontSize: 17.sp, height: 1.4),
            ),
            vSpace(12),
            Text(
              'An admin will review and process the payout.',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(fontSize: 17.sp)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7434FF),
              foregroundColor: Colors.white,
            ),
            child: Text('Submit', style: TextStyle(fontSize: 17.sp)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _formatMinor(int minor, String currency) {
    final major = minor / 100;
    final fmt = NumberFormat('#,##0.##', 'en_US');
    final symbol = currency == 'NGN' ? '₦' : currency;
    return '$symbol${fmt.format(major)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obligation = widget.obligation;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.cardColor,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          children: [
            Text(
              'Request Withdrawal',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            vSpace(2),
            Text(
              obligation.title,
              style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BalanceCard(obligation: obligation),
              vSpace(20),
              _AmountForm(
                amountController: _amountController,
                obligation: obligation,
                submitting: _submitting,
                onSubmit: _submit,
              ),
              vSpace(28),
              _RequestHistorySection(
                requests: _requests,
                loading: _loadingRequests,
                revoking: _revoking,
                onRevoke: _revoke,
              ),
              vSpace(20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Balance card ──────────────────────────────────────────────────────────── //

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.obligation});

  final Obligation obligation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: const LinearGradient(
          colors: [Color(0xFF7434FF), Color(0xFF5E2CD5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Balance',
            style: TextStyle(color: Colors.white70, fontSize: 17.sp),
          ),
          vSpace(6),
          Text(
            obligation.paidAmountLabel,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          vSpace(12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              obligation.category,
              style: TextStyle(color: Colors.white, fontSize: 15.sp),
            ),
          ),
          vSpace(10),
          Text(
            'Your admin will review the request and process the payout from a cooperative account.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Amount form ───────────────────────────────────────────────────────────── //

class _AmountForm extends StatelessWidget {
  const _AmountForm({
    required this.amountController,
    required this.obligation,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController amountController;
  final Obligation obligation;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symbol = obligation.currency == 'NGN' ? '₦' : obligation.currency;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Withdrawal Amount',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          vSpace(12),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              // Group thousands as the user types; the parse step strips commas.
              AmountInputFormatter(decimals: 2),
            ],
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              prefixText: '$symbol ',
              prefixStyle: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              hintText: '0.00',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              // Use onSurface-based border so it's always visible — dividerColor
              // (#2C2C2C) is nearly invisible against cardColor (#1E1E1E) in dark.
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: Color(0xFF7434FF), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 14.h,
              ),
            ),
          ),
          vSpace(16),
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7434FF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: submitting
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Submit Request',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Request history ───────────────────────────────────────────────────────── //

class _RequestHistorySection extends StatelessWidget {
  const _RequestHistorySection({
    required this.requests,
    required this.loading,
    required this.revoking,
    required this.onRevoke,
  });

  final List<ObligationWithdrawalRequest> requests;
  final bool loading;
  final bool revoking;
  final void Function(ObligationWithdrawalRequest) onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Requests',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          vSpace(12),
          if (loading)
            Center(
              // Branded loader matching the obligation Payment History panel.
              child: Image.asset(
                theme.brightness == Brightness.dark
                    ? Images.loaderWhite
                    : Images.loader,
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            )
          else if (requests.isEmpty)
            Text(
              'No withdrawal requests yet.',
              style: TextStyle(
                fontSize: 17.sp,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            )
          else
            for (int i = 0; i < requests.length; i++) ...[
              _RequestTile(
                request: requests[i],
                revoking: revoking,
                onRevoke: onRevoke,
              ),
              if (i != requests.length - 1)
                Divider(height: 1, color: theme.dividerColor),
            ],
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.revoking,
    required this.onRevoke,
  });

  final ObligationWithdrawalRequest request;
  final bool revoking;
  final void Function(ObligationWithdrawalRequest) onRevoke;

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case '1': return const Color(0xFF1AAE70);
      case '2': return const Color(0xFFD7263D);
      case '3': return Colors.grey;
      default:  return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(request.status, context);

    // Flat row (no inner card) so it doesn't read as a card-on-card inside the
    // My Requests panel; the status pill conveys state.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      request.amountLabel,
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    hSpace(8),
                    _StatusPill(
                      label: request.statusLabel,
                      color: statusColor,
                    ),
                  ],
                ),
                vSpace(4),
                Text(
                  request.createdAtLabel,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                if (request.isDeclined &&
                    request.declineReason != null &&
                    request.declineReason!.isNotEmpty) ...[
                  vSpace(4),
                  Text(
                    'Reason: ${request.declineReason}',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: const Color(0xFFD7263D),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (request.isPending)
            TextButton(
              onPressed: revoking ? null : () => onRevoke(request),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD7263D),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Increase background opacity in dark mode — at 15% the coloured tint
    // almost disappears against dark surfaces.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.28 : 0.14),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
