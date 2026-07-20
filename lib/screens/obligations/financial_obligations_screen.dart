import 'dart:async';

import 'package:flutter/material.dart';
import 'package:communal_mobile/core/widgets/back_to_exit_wrapper.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/cooperative_sidebar.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/animated_logo_loader.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/cubits/obligation_categories/obligation_categories_cubit.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/models/obligation_category.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/obligations/widgets/fine_detail_card.dart';
import 'package:communal_mobile/screens/obligations/widgets/obligation_card.dart';

class FinancialObligationsScreen extends StatefulWidget {
  const FinancialObligationsScreen({super.key});

  @override
  State<FinancialObligationsScreen> createState() =>
      _FinancialObligationsScreenState();
}

class _FinancialObligationsScreenState extends State<FinancialObligationsScreen>
    with WidgetsBindingObserver {
  final MemberObligationsRepository _repository = MemberObligationsRepository(
    getIt(),
  );
  final _searchController = TextEditingController();
  List<Obligation> _obligations = const [];
  List<FineRecord> _memberFines = const [];

  String _selectedCategory = '';
  final int _currentNavIndex = 1;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = false;
  bool _loadingFines = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Seed the selected tab from the cubit's category list (excludes Fine).
      final cubit = context.read<ObligationCategoriesCubit>();
      final nonFine = cubit.categories.where((c) => c.code != '1526');
      if (_selectedCategory.isEmpty && nonFine.isNotEmpty) {
        setState(() => _selectedCategory = nonFine.first.displayName);
      }
      _loadObligations();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-fetch on foreground so an admin's dashboard edit (cap,
    // installment amount, equity settings) reflects in the member app
    // without forcing the user to navigate away and back. Without this
    // hook the screen's initState fires once and keeps showing the
    // snapshot it loaded at first paint.
    if (state == AppLifecycleState.resumed && mounted && !_loading) {
      _loadObligations();
    }
  }

  Future<void> _loadObligations() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repository.fetchMemberObligations(authState.user);
      if (!mounted) return;
      final cats = context.read<ObligationCategoriesCubit>().categories;
      // Resolve each obligation's display name from the cubit categories so
      // renamed categories (e.g. 'Equity' → 'Shares') are reflected in the UI.
      final resolved = rows.map((o) => _withResolvedCategory(o, cats)).toList();
      final availableCategories = resolved.map((e) => e.category).toSet();
      setState(() {
        _obligations = resolved;
        if (_selectedCategory.isEmpty ||
            (resolved.isNotEmpty && !availableCategories.contains(_selectedCategory))) {
          final nonFine = cats.where((c) => c.code != '1526');
          _selectedCategory = nonFine.isNotEmpty
              ? nonFine.first.displayName
              : (resolved.isNotEmpty ? resolved.first.category : '');
        }
        _loading = false;
      });
      unawaited(_loadFines(authState.user));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Returns a copy of [o] with [Obligation.category] replaced by the
  /// cooperative-specific display name from [categories].
  Obligation _withResolvedCategory(Obligation o, List<ObligationCategory> categories) {
    final resolved = o.resolveCategory(categories);
    if (resolved == o.category) return o;
    return Obligation(
      id: o.id,
      accountCode: o.accountCode,
      accountType: o.accountType,
      cooperativeId: o.cooperativeId,
      currency: o.currency,
      createdAt: o.createdAt,
      updatedAt: o.updatedAt,
      category: resolved,
      status: o.status,
      title: o.title,
      description: o.description,
      paidAmountMinor: o.paidAmountMinor,
      totalAmountMinor: o.totalAmountMinor,
      perInstallmentMinor: o.perInstallmentMinor,
      installmentsPaid: o.installmentsPaid,
      totalInstallments: o.totalInstallments,
      startDate: o.startDate,
      endDate: o.endDate,
      nextDueDate: o.nextDueDate,
      frequency: o.frequency,
      payments: o.payments,
      fines: o.fines,
      infoNote: o.infoNote,
    );
  }

  Future<void> _loadFines(dynamic user) async {
    setState(() => _loadingFines = true);
    try {
      final fines = await _repository.fetchMemberFines(user);
      if (!mounted) return;
      setState(() {
        _memberFines = fines;
        _loadingFines = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFines = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackToExitWrapper(child: _buildRootBody(context));
  }

  Widget _buildRootBody(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.scaffoldBackgroundColor,
        drawer: const CooperativeSidebar(),
        drawerEdgeDragWidth: 50.w,
        drawerScrimColor: Colors.black.withValues(alpha: 0.4),
        body: _loading
            ? const LoaderOverlay()
            : SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadObligations,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : theme.primaryColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(theme),
                        vSpace(16),
                        _buildSummaryCards(theme),
                        vSpace(20),
                        _buildCategorySelector(theme),
                        vSpace(16),
                        _buildSearchBar(theme),
                        vSpace(20),
                        ..._buildObligationList(theme),
                      ],
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: _loading
            ? null
            : BottomNavBar(
                currentIndex: _currentNavIndex,
                onTap: (index) {
                  if (index == _currentNavIndex) return;
                  switch (index) {
                    case 0:
                      context.go('/home');
                      break;
                    case 2:
                      context.goNamed('community');
                      break;
                    case 3:
                      context.goNamed('loans');
                      break;
                    case 4:
                      context.goNamed('account-settings');
                      break;
                    default:
                      AppToast.error('Section coming soon');
                  }
                },
              ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final auth = context.watch<AuthBloc>().state;
    final onSurface = theme.colorScheme.onSurface;
    final coopLine = auth is AuthAuthenticated
        ? () {
            final line = auth.user.cooperativeDisplayName.trim();
            if (line.isNotEmpty && line != '—') return line;
            return 'Cooperative';
          }()
        : 'Cooperative';

    return Row(
      children: [
        _roundedIcon(
          theme: theme,
          icon: Icons.menu,
          onTap: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'Financial Obligations',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              vSpace(4),
              Text(
                coopLine,
                style: TextStyle(
                  fontSize: 17.sp,
                  color: onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        _roundedIcon(
          theme: theme,
          icon: Icons.refresh,
          onTap: _loadObligations,
        ),
      ],
    );
  }

  Widget _roundedIcon({
    required ThemeData theme,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: theme.colorScheme.onSurface, size: 20.sp),
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    final auth = context.watch<AuthBloc>().state;
    // Summary numbers should reflect the category the user is currently
    // looking at — otherwise switching tabs leaves the same totals
    // sitting at the top, which makes them feel static and wrong.
    final scoped = _obligations
        .where(
          (o) => o.category.toLowerCase() == _selectedCategory.toLowerCase(),
        )
        .toList();
    final currency = auth is AuthAuthenticated
        ? resolveCurrencyCode(auth.user)
        : (scoped.isNotEmpty
              ? scoped.first.currency
              : (_obligations.isNotEmpty
                    ? _obligations.first.currency
                    : 'NGN'));
    final totalDueMinor = scoped.fold<int>(
      0,
      (sum, row) => sum + row.balanceMinor,
    );
    final totalPaidMinor = scoped.fold<int>(
      0,
      (sum, row) => sum + row.paidAmountMinor,
    );
    // Share-based obligations (e.g. Equity) have no "next due" date.
    // Look up the selected category's isShareBased flag from the cubit
    // so cooperatives that rename 'Equity' still get the '—' treatment.
    final cats = context.read<ObligationCategoriesCubit>().categories;
    final selectedCat = cats.firstWhere(
      (c) => c.displayName == _selectedCategory,
      orElse: () => ObligationCategory(
        code: '', displayName: _selectedCategory,
        isWithdrawable: false, isLoanEligible: false,
        isMandatory: false, earnsInterest: false,
        isShareBased: false, displayOrder: 99,
      ),
    );
    final nextDueLabel = scoped.isEmpty
        ? 'N/A'
        : (selectedCat.isShareBased
              ? '—'
              : _formatDate(
                  scoped
                      .map((e) => e.nextDueDate)
                      .reduce((a, b) => a.isBefore(b) ? a : b),
                ));
    final cards = [
      _SummaryCardData(
        label: 'Total Due',
        value: Money(totalDueMinor, currency).format(),
        color: const Color(0xFFFFE6E9),
        icon: Icons.error_outline,
        valueColor: const Color(0xFFD7263D),
      ),
      _SummaryCardData(
        label: 'Total Paid',
        value: Money(totalPaidMinor, currency).format(),
        color: const Color(0xFFE7FFF2),
        icon: Icons.check_circle_outline,
        valueColor: const Color(0xFF1AAE70),
      ),
      _SummaryCardData(
        label: 'Next Due',
        value: nextDueLabel,
        color: const Color(0xFFEAF1FF),
        icon: Icons.calendar_today_outlined,
        valueColor: theme.primaryColor,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.w;
        final needsWrap = constraints.maxWidth < 360.w;

        if (needsWrap) {
          return Column(
            children: [
              _SummaryCard(card: cards[0]),
              vSpace(spacing),
              _SummaryCard(card: cards[1]),
              vSpace(spacing),
              _SummaryCard(card: cards[2]),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _SummaryCard(card: cards[0])),
            SizedBox(width: spacing),
            Expanded(child: _SummaryCard(card: cards[1])),
            SizedBox(width: spacing),
            Expanded(child: _SummaryCard(card: cards[2])),
          ],
        );
      },
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    final cats = context.watch<ObligationCategoriesCubit>().categories;
    final categoryNames = cats.map((c) => c.displayName).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categoryNames.map((category) {
          final isActive = _selectedCategory == category;
          return Padding(
            padding: EdgeInsets.only(right: 10.w),
            child: ChoiceChip(
              label: Text(category),
              selected: isActive,
              showCheckmark: false,
              onSelected: (_) {
                setState(() => _selectedCategory = category);
              },
              selectedColor: theme.primaryColor,
              labelStyle: TextStyle(
                color: isActive ? Colors.white : onSurface,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
                side: BorderSide(
                  color: isActive ? theme.primaryColor : theme.dividerColor,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: onSurface.withValues(alpha: 0.6)),
          hSpace(10),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: onSurface, fontSize: 17.sp),
              decoration: InputDecoration.collapsed(
                hintText: 'Search obligations...',
                hintStyle: TextStyle(
                  color: onSurface.withValues(alpha: 0.5),
                  fontSize: 17.sp,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color:
                  (theme.brightness == Brightness.dark
                          ? Colors.white
                          : theme.primaryColor)
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.filter_alt_outlined,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : theme.primaryColor,
              size: 20.sp,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildObligationList(ThemeData theme) {
    if (_error != null) {
      return [
        vSpace(12),
        Center(
          child: Column(
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17.sp, color: Colors.red.shade400),
              ),
              vSpace(8),
              TextButton(
                onPressed: _loadObligations,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ];
    }

    // Identify the Fine tab by code (1526) so renamed cooperatives still work.
    final catCubit = context.read<ObligationCategoriesCubit>();
    final fineCat = catCubit.categories.firstWhere(
      (c) => c.code == '1526',
      orElse: () => ObligationCategory.defaults.last,
    );
    if (_selectedCategory == fineCat.displayName) {
      return _buildFineTabList(theme, fineCat.displayName);
    }

    final query = _searchController.text.toLowerCase();
    final items = _obligations.where((obligation) {
      final matchesCategory =
          obligation.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          obligation.title.toLowerCase().contains(query) ||
          obligation.category.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    if (items.isEmpty) {
      return [
        vSpace(40),
        Center(
          child: Text(
            'No obligations found for $_selectedCategory.',
            style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
          ),
        ),
      ];
    }

    return [
      for (int i = 0; i < items.length; i++) ...[
        ObligationCard(
          obligation: items[i],
          onTap: () => context.pushNamed('obligation-detail', extra: items[i]),
        ),
        if (i != items.length - 1) vSpace(16),
      ],
      vSpace(20),
    ];
  }

  List<Widget> _buildFineTabList(ThemeData theme, String fineDisplayName) {
    final authState = context.read<AuthBloc>().state;
    final coopId = authState is AuthAuthenticated
        ? (authState.user.cooperativeId?.trim() ?? '')
        : '';
    // Match fine obligations by accountType code (1526) when available,
    // falling back to the resolved display name for backward compat.
    final loanFineObligations = _obligations
        .where((o) => o.accountType == '1526' || o.category == fineDisplayName)
        .toList();
    final query = _searchController.text.toLowerCase();
    final filteredFines = _memberFines.where((f) {
      return query.isEmpty ||
          f.description.toLowerCase().contains(query) ||
          f.type.toLowerCase().contains(query) ||
          f.status.toLowerCase().contains(query);
    }).toList();

    final hasLoanFines = loanFineObligations.isNotEmpty;
    final hasObligationFines = filteredFines.isNotEmpty;

    if (!hasLoanFines && !hasObligationFines && !_loadingFines) {
      return [
        vSpace(40),
        Center(
          child: Text(
            'No fines on record.',
            style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];

    if (hasObligationFines || _loadingFines) {
      // (Header removed — the tab is already "Fines"; the sub-title was redundant.)
      if (_loadingFines) {
        widgets.add(const Center(child: AnimatedLogoLoader()));
      } else {
        for (int i = 0; i < filteredFines.length; i++) {
          widgets.add(FineDetailCard(fine: filteredFines[i], cooperativeId: coopId));
          if (i != filteredFines.length - 1) widgets.add(vSpace(12));
        }
      }
    }

    if (hasLoanFines) {
      if (hasObligationFines || _loadingFines) widgets.add(vSpace(20));
      widgets.add(
        Text(
          'Loan Late Fees',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      );
      widgets.add(vSpace(12));
      for (int i = 0; i < loanFineObligations.length; i++) {
        widgets.add(
          ObligationCard(
            obligation: loanFineObligations[i],
            onTap: () => context.pushNamed(
              'obligation-detail',
              extra: loanFineObligations[i],
            ),
          ),
        );
        if (i != loanFineObligations.length - 1) widgets.add(vSpace(16));
      }
    }

    widgets.add(vSpace(20));
    return widgets;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final Color valueColor;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.card});

  final _SummaryCardData card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // In dark mode the original light pastel backgrounds (pink, mint,
    // pale blue) read as bright washed-out blocks against the near-black
    // scaffold. Mix the value colour with the surface so the tint stays
    // perceptible without being eye-strain bright.
    final cardBg = isDark
        ? card.valueColor.withValues(alpha: 0.16)
        : card.color;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(card.icon, color: card.valueColor, size: 18.sp),
          vSpace(12),
          Text(
            card.label,
            style: TextStyle(
              fontSize: 17.sp,
              color: isDark
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                  : Colors.grey.shade700,
            ),
          ),
          vSpace(4),
          Text(
            card.value,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: card.valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
