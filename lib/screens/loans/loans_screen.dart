import 'package:flutter/material.dart';
import 'package:communal_mobile/core/widgets/back_to_exit_wrapper.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/cooperative_sidebar.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/loan_application.dart';
import 'package:communal_mobile/data/models/loan_eligibility.dart';
import 'package:communal_mobile/data/models/loan_scheme.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/loans/widgets/active_loan_card.dart';
import 'package:communal_mobile/screens/loans/widgets/loan_offer_card.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final LoanRepository _repo = LoanRepository(getIt());
  final int _currentNavIndex = 3;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loading = false;
  String? _error;
  List<LoanApplication> _loans = const [];
  List<LoanScheme> _schemes = const [];
  int _balanceMinor = 0;

  /// Eligibility envelope — read for `canApply` / `sundryDebtMinor` so
  /// we can render the sundry banner and short-circuit the Apply CTA
  /// before the user fills the form. Null while still loading or when
  /// the cooperative isn't resolved.
  LoanEligibility? _eligibility;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final user = auth.user;
    final coopId = user.cooperativeId?.trim();
    final ledger = user.ledgerNumber?.trim();
    if (coopId == null || coopId.isEmpty || ledger == null || ledger.isEmpty) {
      setState(() => _error = 'Cooperative not linked to your profile');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.fetchMyLoans(user),
        _repo.fetchSchemes(coopId),
        _repo.fetchLoanBalanceMinor(ledger),
        _repo.fetchEligibility(coopId),
      ]);
      if (!mounted) return;
      setState(() {
        _loans = results[0] as List<LoanApplication>;
        _schemes = results[1] as List<LoanScheme>;
        _balanceMinor = results[2] as int;
        _eligibility = results[3] as LoanEligibility?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Front-line gate for the Apply Now button and every per-scheme
  /// Apply card. The backend rejects with 409 in two cases: a pending
  /// application already exists, or the member has unsettled sundry
  /// debt with this cooperative. Checking here stops the user from
  /// filling out three steps before learning that. Active / declined /
  /// cancelled / closed loans don't block — only status `pending` does.
  void _onApplyTapped({LoanScheme? scheme}) {
    final el = _eligibility;
    if (el != null && !el.canApply) {
      // The banner above the Quick Actions row already explains the
      // sundry debt; the toast is a redundant tap-time confirmation
      // for users who didn't read it.
      AppToast.error(
        'Settle your sundry debt of ${el.sundryDebtLabel} before requesting a new loan.',
      );
      return;
    }
    final hasPending = _loans.any((l) => l.status == LoanStatus.pending);
    if (hasPending) {
      AppToast.error(
        'You already have a loan application awaiting approval. '
        'Wait for it to be approved or declined before submitting a new one.',
      );
      return;
    }
    context.pushNamed(
      'loan-application',
      extra: scheme == null ? null : {'scheme': scheme},
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackToExitWrapper(child: _buildRootBody(context));
  }

  Widget _buildRootBody(BuildContext context) {
    final showFullLoader = _loading && _loans.isEmpty && _schemes.isEmpty;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).cardColor,
        drawer: const CooperativeSidebar(),
        drawerEdgeDragWidth: 50.w,
        drawerScrimColor: Colors.black.withValues(alpha: 0.4),
        body: showFullLoader
            ? const LoaderOverlay()
            : SafeArea(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        vSpace(24),
                        _buildSummaryCard(),
                        vSpace(24),
                        if (_eligibility?.canApply == false) ...[
                          _buildSundryBanner(_eligibility!),
                          vSpace(20),
                        ],
                        _buildQuickActions(),
                        vSpace(24),
                        if (_error != null)
                          _buildErrorBanner(_error!)
                        else
                          _buildBody(),
                        vSpace(32),
                      ],
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: showFullLoader
            ? null
            : BottomNavBar(
                currentIndex: _currentNavIndex,
                onTap: (index) {
                  if (index == _currentNavIndex) return;
                  switch (index) {
                    case 0:
                      context.goNamed('home');
                      break;
                    case 1:
                      context.goNamed('obligations');
                      break;
                    case 2:
                      context.goNamed('community');
                      break;
                    case 4:
                      context.goNamed('account-settings');
                      break;
                  }
                },
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        Expanded(
          child: Text(
            'Loans',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loading ? null : _load,
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user : null;
    final currency = user != null ? resolveCurrencyCode(user) : 'NGN';
    final activeCount = _loans
        .where((l) => l.status == LoanStatus.approved)
        .length;
    final pendingCount = _loans
        .where((l) => l.status == LoanStatus.pending)
        .length;
    final balanceLabel = Money(_balanceMinor, currency).format();

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE67E22),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Outstanding Loan Balance',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          vSpace(8),
          Text(
            balanceLabel,
            style: TextStyle(
              fontSize: 36.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          vSpace(12),
          Row(
            children: [
              _summaryChip('$activeCount active'),
              hSpace(8),
              if (pendingCount > 0) _summaryChip('$pendingCount pending'),
            ],
          ),
          if (user?.cooperativeName != null &&
              user!.cooperativeName!.trim().isNotEmpty) ...[
            vSpace(12),
            Row(
              children: [
                Icon(
                  Icons.bookmark,
                  size: 16.sp,
                  color: Colors.white.withOpacity(0.8),
                ),
                hSpace(6),
                Expanded(
                  child: Text(
                    user.cooperativeDisplayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Red surface that appears above the quick actions when the
  /// cooperative has flagged the member as carrying unsettled sundry
  /// debt. The Apply CTA is also gated in [_onApplyTapped]; this
  /// banner is the proactive explanation that keeps the gate from
  /// feeling arbitrary.
  Widget _buildSundryBanner(LoanEligibility el) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade700,
              size: 20.sp,
            ),
          ),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sundry debt outstanding',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade900,
                  ),
                ),
                vSpace(4),
                Text(
                  'You have ${el.sundryDebtLabel} of unsettled sundry debt with this cooperative. '
                  'New loan requests are blocked until it is cleared.',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.red.shade900.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.calculate_outlined,
                label: 'Loan Calculator',
                onTap: () => context.pushNamed('loan-calculator'),
              ),
            ),
            hSpace(12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.attach_money,
                label: 'Apply Now',
                onTap: _onApplyTapped,
              ),
            ),
            hSpace(12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.handshake_outlined,
                label: 'Guarantor Requests',
                onTap: () => context.pushNamed('guarantor-requests'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, size: 20.sp, color: const Color(0xFFE67E22)),
            ),
            vSpace(8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loans.isNotEmpty) _buildLoansSection(),
        if (_loans.isNotEmpty) vSpace(24),
        _buildSchemesSection(),
      ],
    );
  }

  Widget _buildLoansSection() {
    final visible = _loans
        .where(
          (l) =>
              l.status == LoanStatus.approved || l.status == LoanStatus.pending,
        )
        .toList();
    // Always offer the View all entry when at least one loan exists,
    // even if the hub's pending+approved filter happens to be empty
    // (e.g. only declined / closed history). Without this the member
    // had no way to reach declined-or-closed history once the active
    // bucket emptied.
    if (_loans.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'My Loans',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.pushNamed('loans-history'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: const Color(0xFFE67E22),
              ),
              child: Text(
                'View all',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (visible.isEmpty) ...[
          vSpace(8),
          Text(
            'No active or pending applications. Tap View all to see your '
            'declined / cancelled / closed history.',
            style: TextStyle(
              fontSize: 17.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
        vSpace(16),
        ...visible.map(
          (loan) => Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: ActiveLoanCard(
              loan: loan,
              onViewDetails: () =>
                  context.pushNamed('loan-detail', extra: {'loan': loan}),
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

  Widget _buildSchemesSection() {
    if (_schemes.isEmpty) {
      return _emptyCard(
        icon: Icons.lightbulb_outline,
        title: 'No loan products available',
        subtitle: 'Check back later or ask your cooperative admin.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available for You',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(16),
        ..._schemes.map((scheme) {
          final auth = context.read<AuthBloc>().state;
          final currency = auth is AuthAuthenticated
              ? resolveCurrencyCode(auth.user)
              : 'NGN';
          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: LoanOfferCard(
              scheme: scheme,
              currency: currency,
              onApply: () => _onApplyTapped(scheme: scheme),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFE74C3C).withValues(alpha: 0.16)
            : const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFE74C3C).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20.sp,
            color: const Color(0xFFE74C3C),
          ),
          hSpace(12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 17.sp, color: const Color(0xFFE74C3C)),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32.sp,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          vSpace(12),
          Text(
            title,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
