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
  final MemberObligationsRepository _repository =
      MemberObligationsRepository(getIt());
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
      final allObligations = await _repository.fetchMemberObligations(auth.user);
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
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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
                      _FinesSection(fine: _obligation.fines.first),
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
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.help_outline),
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
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
                      'Total Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 15.sp),
                    ),
                    vSpace(4),
                    Text(
                      obligation.totalAmountLabel,
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
              _Badge(
                label:
                    '${obligation.installmentsPaid} of ${obligation.totalInstallments}',
              ),
              const Spacer(),
              Text(
                'Next: ${obligation.nextDueDateLabel}',
                style: TextStyle(color: Colors.white, fontSize: 15.sp),
              ),
            ],
          ),
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
          style: TextStyle(color: Colors.white70, fontSize: 15.sp),
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
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
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
  const _AboutSection({
    required this.obligation,
    required this.paymentHistory,
  });

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
              fontSize: 17.sp,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
              fontSize: 17.sp,
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
          style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
        ),
        vSpace(4),
        Text(
          value,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _FinesSection extends StatelessWidget {
  const _FinesSection({required this.fine});

  final FineRecord fine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFFD7263D);
    return _InfoCard(
      title: 'Fines & Penalties',
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isDark
              ? accent.withValues(alpha: 0.16)
              : const Color(0xFFFFEEF0),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: accent,
                  size: 18.sp,
                ),
                hSpace(8),
                Text(
                  fine.amountLabel,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const Spacer(),
                _StatusChip(label: fine.status, color: accent),
              ],
            ),
            vSpace(8),
            Text(
              fine.description,
              style: TextStyle(
                fontSize: 15.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            vSpace(8),
            Text(
              'Type: ${fine.type}   ${fine.dateLabel}',
              style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentHistorySection extends StatelessWidget {
  const _PaymentHistorySection({
    required this.payments,
    required this.loading,
  });

  final List<PaymentRecord> payments;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Payment History',
      child: Column(
        children: [
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (payments.isEmpty)
            Text(
              'No payment history yet.',
              style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
            )
          else
            for (int i = 0; i < payments.length; i++) ...[
              _PaymentTile(record: payments[i]),
              if (i != payments.length - 1) vSpace(12),
            ],
          vSpace(12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total records (${payments.length})',
              style: TextStyle(
                fontSize: 15.sp,
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
    final iconData = outflow ? Icons.arrow_upward_rounded : Icons.check_circle;
    final iconColor = outflow ? const Color(0xFFD64545) : const Color(0xFF7B61FF);
    // Inflow rows used hardcoded `Colors.black` for the amount label,
    // which renders invisibly on the dark scaffold. Resolve from the
    // active theme's onSurface so the amount stays legible in both
    // modes; outflow keeps the red accent.
    final amountColor = outflow
        ? const Color(0xFFD64545)
        : Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(iconData, color: iconColor, size: 22.sp),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(4),
                Text(
                  '${record.dateLabel}  •  ${record.method}',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  record.reference,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            record.amountLabel,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
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
                  fontSize: 17.sp,
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
              fontSize: 15.sp,
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

  @override
  Widget build(BuildContext context) {
    final liveTheme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
        decoration: BoxDecoration(color: liveTheme.cardColor),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contacting admin...')),
                  );
                },
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: liveTheme.primaryColor,
                  size: 20.sp,
                ),
                label: Text(
                  'Contact Admin',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: liveTheme.colorScheme.onSurface,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 52.h),
                  side: BorderSide(color: liveTheme.dividerColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
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
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
