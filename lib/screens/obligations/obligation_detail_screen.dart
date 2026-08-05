import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/screens/obligations/widgets/fine_detail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/injection.dart';

class ObligationDetailScreen extends StatefulWidget {
  const ObligationDetailScreen({super.key, required this.obligation});

  final Obligation obligation;

  @override
  State<ObligationDetailScreen> createState() => _ObligationDetailScreenState();
}

class _ObligationDetailScreenState extends State<ObligationDetailScreen> {
  final MemberObligationsRepository _repository = MemberObligationsRepository(
    getIt(),
  );
  late Obligation _obligation;
  List<PaymentRecord> _history = const [];
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _obligation = widget.obligation;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetails());
  }

  Future<void> _loadDetails() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    setState(() => _loadingHistory = true);
    try {
      final allObligations = await _repository.fetchMemberObligations(
        auth.user,
      );
      final updated = allObligations.firstWhere(
        (e) => e.accountCode == _obligation.accountCode,
        orElse: () => _obligation,
      );
      final history = await _repository.fetchObligationPaymentHistory(
        user: auth.user,
        obligation: updated,
      );
      if (!mounted) return;
      setState(() {
        _obligation = updated;
        _history = history;
        _loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  String _cooperativeSubtitle(AuthState auth) {
    if (auth is AuthAuthenticated) {
      final line = auth.user.cooperativeDisplayName.trim();
      if (line.isNotEmpty && line != '—') return line;
    }
    final id = _obligation.cooperativeId.trim();
    if (id.isNotEmpty) return id;
    return 'Cooperative';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _DetailAppBar(
            title: _obligation.title,
            subtitle: _cooperativeSubtitle(auth),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryCard(obligation: _obligation),
                        vSpace(20),
                        _AboutSection(
                          obligation: _obligation,
                          paymentHistory: _history,
                        ),
                        if (_obligation.fines.isNotEmpty) ...[
                          vSpace(20),
                          _FinesSection(obligation: _obligation),
                        ],
                        vSpace(20),
                        _PaymentHistorySection(
                          payments: _history,
                          loading: _loadingHistory,
                        ),
                        vSpace(20),
                        _LoanPromoCard(note: _obligation.infoNote),
                        vSpace(20),
                      ],
                    ),
                  ),
                ),
                _BottomActions(obligation: _obligation, theme: theme),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DetailAppBar({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Size get preferredSize => Size.fromHeight(64.h);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).cardColor,
      centerTitle: true,
      title: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        // IconButton(
        //   onPressed: () {},
        //   icon: const Icon(Icons.help_outline),
        //   color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        // ),
        
        hSpace(8),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.obligation});

  final Obligation obligation;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF1AAE70);
      case 'overdue':
        return const Color(0xFFD7263D);
      default:
        return const Color(0xFF52E1A2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(obligation.status);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: const LinearGradient(
          colors: [Color(0xFF7434FF), Color(0xFF5E2CD5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      obligation.isShareBased ? 'Target Amount' : 'Amount Paid',
                      style: TextStyle(color: Colors.white70, fontSize: 17.sp),
                    ),
                    vSpace(4),
                    Text(
                      obligation.isShareBased
                          ? obligation.totalAmountLabel
                          : obligation.paidAmountLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: obligation.status, color: statusColor),
            ],
          ),
          if (obligation.isShareBased) ...[
            vSpace(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AmountColumn(label: 'Paid', value: obligation.paidAmountLabel),
                _AmountColumn(label: 'Balance', value: obligation.balanceLabel),
              ],
            ),
            vSpace(16),
            LinearProgressIndicator(
              value: obligation.progress.clamp(0, 1),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
            vSpace(12),
            Row(
              children: [
                if (obligation.perInstallmentMinor > 0) ...[
                  _Badge(
                    label:
                        '${obligation.installmentsPaid} of ${obligation.totalInstallments}',
                  ),
                  const Spacer(),
                ],
                Text(
                  'Next: ${obligation.nextDueDateLabel}',
                  style: TextStyle(color: Colors.white, fontSize: 17.sp),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  const _AmountColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 17.sp),
        ),
        vSpace(4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 16.sp),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.obligation, required this.paymentHistory});

  final Obligation obligation;
  final List<PaymentRecord> paymentHistory;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'About This Obligation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            obligation.description,
            style: TextStyle(
              fontSize: 19.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          vSpace(16),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Created At',
                  value: obligation.createdAtLabel,
                ),
              ),
              hSpace(16),
              Expanded(
                child: _InfoTile(
                  label: 'Updated At',
                  value: obligation.updatedAtLabel,
                ),
              ),
            ],
          ),
          vSpace(12),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Frequency',
                  value: _deriveFrequency(paymentHistory, obligation.frequency),
                ),
              ),
              hSpace(16),
              if (obligation.perInstallmentMinor > 0)
                Expanded(
                  child: _InfoTile(
                    label: 'Per Installment',
                    value: obligation.perInstallmentLabel,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _deriveFrequency(List<PaymentRecord> records, String fallback) {
    if (records.length < 2) {
      final text = fallback.trim();
      return text.isEmpty ? 'Not specified' : text;
    }
    final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));
    final days = sorted.first.date.difference(sorted[1].date).inDays.abs();
    if (days <= 10) return 'Weekly';
    if (days <= 45) return 'Monthly';
    if (days <= 110) return 'Quarterly';
    return 'Irregular';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(12),
          child,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
        ),
        vSpace(4),
        Text(
          value,
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _FinesSection extends StatelessWidget {
  const _FinesSection({required this.obligation});

  final Obligation obligation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only show the card while there are outstanding (unpaid) fines; once every
    // fine is cleared, hide it entirely.
    final outstanding =
        obligation.fines.where((f) => f.outstandingMinor > 0).toList();
    if (outstanding.isEmpty) return const SizedBox.shrink();
    final outstandingMinor =
        outstanding.fold<int>(0, (s, f) => s + f.outstandingMinor);
    final subtitle =
        '${outstanding.length} unpaid fine${outstanding.length == 1 ? '' : 's'}';

    // Use the shared FineDetailCard as-is (summed amount), with just a label
    // above it indicating these are fines — not wrapped in another card.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fines & Penalties',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        vSpace(10),
        FineDetailCard(
          fine: outstanding.first,
          cooperativeId: obligation.cooperativeId,
          amountMinorOverride: outstandingMinor,
          subtitleOverride: subtitle,
          onTap: () => context.pushNamed('fine-details', extra: obligation),
        ),
      ],
    );
  }
}

class _PaymentHistorySection extends StatefulWidget {
  const _PaymentHistorySection({required this.payments, required this.loading});

  final List<PaymentRecord> payments;
  final bool loading;

  @override
  State<_PaymentHistorySection> createState() => _PaymentHistorySectionState();
}

class _PaymentHistorySectionState extends State<_PaymentHistorySection> {
  /// Initial visible rows. Anything beyond this is collapsed behind a
  /// "View all" toggle so the obligation page doesn't run for screens
  /// when payments accumulate.
  static const int _collapsedLimit = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final payments = widget.payments;
    final loading = widget.loading;
    final showAll = _expanded || payments.length <= _collapsedLimit;
    final visible = showAll
        ? payments
        : payments.take(_collapsedLimit).toList();
    final hiddenCount = payments.length - visible.length;
    return _InfoCard(
      title: 'Payment History',
      child: Column(
        children: [
          if (loading)
            Center(
              // Themed branded loader (matches the transactions history screen):
              // pre-tinted asset per theme, self-animating GIF — no rotation.
              child: Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? Images.loaderWhite
                    : Images.loader,
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            )
          else if (payments.isEmpty)
            Text(
              'No payment history yet.',
              style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
            )
          else
            for (int i = 0; i < visible.length; i++) ...[
              _PaymentTile(record: visible[i]),
              if (i != visible.length - 1)
                Divider(height: 1, color: Theme.of(context).dividerColor),
            ],
          if (hiddenCount > 0) ...[
            vSpace(12),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _expanded = true),
                child: Text(
                  'View all $hiddenCount more',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          ] else if (_expanded && payments.length > _collapsedLimit) ...[
            vSpace(12),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _expanded = false),
                child: Text(
                  'Show less',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          ],
          vSpace(12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total records (${payments.length})',
              style: TextStyle(
                fontSize: 17.sp,
                color: const Color(0xFF5B5CE2),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.record});

  final PaymentRecord record;

  @override
  Widget build(BuildContext context) {
    final outflow = record.isOutflow;
    // Directional arrows (no check icon) in a soft tinted circle. The amount
    // stays legible in both themes — outflow keeps the red accent.
    final accent = outflow ? const Color(0xFFD64545) : const Color(0xFF1AAE70);
    final amountColor = outflow
        ? const Color(0xFFD64545)
        : Theme.of(context).colorScheme.onSurface;
    // Flat row (no inner card) so it doesn't read as a card-on-card inside the
    // Payment History panel. Tappable → detail sheet with the running balance.
    return InkWell(
      onTap: () => _showPaymentDetail(context, record),
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              outflow ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: accent,
              size: 20.sp,
            ),
          ),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(4),
                Text(
                  '${record.dateLabel}  •  ${record.method}',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          hSpace(8),
          Text(
            record.amountLabel,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Detail sheet for a single obligation payment-history entry — shows the
/// running balance (before/after) plus the standard transaction fields.
void _showPaymentDetail(BuildContext context, PaymentRecord record) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final onSurface = theme.colorScheme.onSurface;
      final outflow = record.isOutflow;
      final amountColor =
          outflow ? const Color(0xFFD64545) : const Color(0xFF1AAE70);

      Widget row(String label, String value, {Color? valueColor}) => Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                hSpace(12),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? onSurface,
                    ),
                  ),
                ),
              ],
            ),
          );

      return SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              vSpace(16),
              Text(
                record.title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              vSpace(4),
              Text(
                record.amountLabel,
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
              ),
              vSpace(12),
              Divider(height: 1, color: theme.dividerColor),
              row('Date', record.dateLabel),
              row('Payment method', record.method),
              if (record.balanceBeforeLabel != null)
                row('Balance before', record.balanceBeforeLabel!),
              if (record.balanceAfterLabel != null)
                row('Balance after', record.balanceAfterLabel!),
              if (record.reference.isNotEmpty)
                row('Reference', record.reference),
            ],
          ),
        ),
      );
    },
  );
}

class _LoanPromoCard extends StatelessWidget {
  const _LoanPromoCard({this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF5B5CE2);
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        // Soft blue notice tile — keep the tint visible on dark mode
        // by mixing the accent with the surface, otherwise the fixed
        // 0xFFE9F2FF reads as a near-white block on the dark
        // scaffold.
        color: isDark
            ? accent.withValues(alpha: 0.16)
            : const Color(0xFFE9F2FF),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trending_up, color: accent),
              ),
              hSpace(12),
              Text(
                'Need a Loan?',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          vSpace(12),
          Text(
            note ??
                'Your consistent payments qualify you for cooperative loans at competitive rates.',
            style: TextStyle(
              fontSize: 17.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          vSpace(12),
          ElevatedButton(
            onPressed: () => context.goNamed('loans'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B5CE2),
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 48.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            child: const Text(
              'View Loan Options',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.obligation, required this.theme});

  final Obligation obligation;
  final ThemeData theme;

  bool get _canWithdraw =>
      !obligation.isShareBased && obligation.paidAmountMinor > 0;

  @override
  Widget build(BuildContext context) {
    final liveTheme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
        decoration: BoxDecoration(color: liveTheme.cardColor),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      context.pushNamed('help-support');
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 52.h),
                      side: BorderSide(color: liveTheme.dividerColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                    ),
                    child: Text(
                      'Contact Admin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w600,
                        color: liveTheme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                hSpace(12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        context.pushNamed('obligation-payment', extra: obligation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7434FF),
                      elevation: 0,
                      minimumSize: Size(double.infinity, 52.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                    ),
                    child: Text(
                      'Pay Now',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_canWithdraw) ...[
              vSpace(8),
              Builder(
                builder: (ctx) {
                  // #7434FF (primary purple) on the dark card (#1E1E1E) only
                  // achieves ~2.9:1 contrast — below AA. The theme's
                  // secondaryHeaderColor (#B09FFF) is a lighter purple that
                  // reaches ~6.9:1 on dark surfaces; use it in dark mode.
                  final isDark =
                      Theme.of(ctx).brightness == Brightness.dark;
                  final accentColor = isDark
                      ? liveTheme.secondaryHeaderColor
                      : const Color(0xFF7434FF);
                  return SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: OutlinedButton(
                      onPressed: () => ctx.pushNamed(
                        'obligation-withdrawal',
                        extra: obligation,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                      ),
                      child: Text(
                        'Request Withdrawal',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
