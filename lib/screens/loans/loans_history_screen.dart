import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/loan_application.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/loans/widgets/active_loan_card.dart';

/// Full list of every loan application on the signed-in member's
/// ledger, grouped by status. The loans hub only surfaces the active +
/// pending subset so the screen stays scannable; this is where the
/// member sees declined / cancelled / closed history too.
class LoansHistoryScreen extends StatefulWidget {
  const LoansHistoryScreen({super.key});

  @override
  State<LoansHistoryScreen> createState() => _LoansHistoryScreenState();
}

class _LoansHistoryScreenState extends State<LoansHistoryScreen> {
  final LoanRepository _repo = LoanRepository(getIt());

  bool _loading = false;
  List<LoanApplication> _loans = const [];

  /// Order surfaced sections so the most actionable groups land at
  /// the top. Pending first (the user is waiting on someone),
  /// approved next (live debt), then the terminal states.
  static const List<LoanStatus> _displayOrder = [
    LoanStatus.pending,
    LoanStatus.approved,
    LoanStatus.declined,
    LoanStatus.cancelled,
    LoanStatus.unknown,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    setState(() => _loading = true);
    try {
      final loans = await _repo.fetchMyLoans(auth.user);
      if (!mounted) return;
      setState(() {
        _loans = loans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showLoader = _loading && _loans.isEmpty;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(theme),
      child: Scaffold(
        backgroundColor: theme.cardColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: theme.cardColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'My Loans',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        body: showLoader
            ? const LoaderOverlay()
            : RefreshIndicator(
                onRefresh: _load,
                child: _loans.isEmpty
                    ? _buildEmptyState(theme)
                    : _buildBody(theme),
              ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // One pass over the list, bucketed by status so we don't
    // re-iterate per section. Buckets render in `_displayOrder`,
    // empty ones are skipped.
    final byStatus = <LoanStatus, List<LoanApplication>>{};
    for (final loan in _loans) {
      byStatus.putIfAbsent(loan.status, () => []).add(loan);
    }
    // Most recent first inside each bucket.
    for (final list in byStatus.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final sections = <Widget>[];
    for (final status in _displayOrder) {
      final group = byStatus[status];
      if (group == null || group.isEmpty) continue;
      sections.add(_buildSection(theme, status, group));
      sections.add(vSpace(20));
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections,
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme,
    LoanStatus status,
    List<LoanApplication> group,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              status.label,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            hSpace(8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                '${group.length}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
        vSpace(12),
        ...group.map(
          (loan) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: ActiveLoanCard(
              loan: loan,
              onViewDetails: () =>
                  context.pushNamed('loan-detail', extra: {'loan': loan}),
              // Repayment only makes sense for approved loans with a
              // remaining balance — same gate as the hub.
              onMakePayment:
                  loan.status == LoanStatus.approved && loan.balanceMinor > 0
                  ? () => context.pushNamed('loan-payment', extra: loan)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      // Keep RefreshIndicator usable when the list is empty.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 80.h),
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 72.sp,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        vSpace(16),
        Text(
          'No loan applications yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        vSpace(8),
        Text(
          'Apply for a loan from the Loans hub. Your applications will show '
          'up here with their current status.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.sp,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
