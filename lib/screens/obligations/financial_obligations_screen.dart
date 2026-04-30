import 'package:flutter/material.dart';
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
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/obligations/widgets/obligation_card.dart';

class FinancialObligationsScreen extends StatefulWidget {
  const FinancialObligationsScreen({super.key});

  @override
  State<FinancialObligationsScreen> createState() =>
      _FinancialObligationsScreenState();
}

class _FinancialObligationsScreenState
    extends State<FinancialObligationsScreen> {
  final MemberObligationsRepository _repository =
      MemberObligationsRepository(getIt());
  final _searchController = TextEditingController();
  final List<String> _categories = ['Equity', 'Patronage', 'Custom', 'Fine'];
  List<Obligation> _obligations = const [];

  String _selectedCategory = 'Equity';
  final int _currentNavIndex = 1;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadObligations());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final availableCategories = rows.map((e) => e.category).toSet();
      setState(() {
        _obligations = rows;
        if (rows.isNotEmpty && !availableCategories.contains(_selectedCategory)) {
          _selectedCategory = rows.first.category;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Section coming soon')),
                      );
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
                  fontSize: 15.sp,
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
        child: Icon(
          icon,
          color: theme.colorScheme.onSurface,
          size: 20.sp,
        ),
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    final auth = context.watch<AuthBloc>().state;
    // Summary numbers should reflect the category the user is currently
    // looking at — otherwise switching tabs leaves the same totals
    // sitting at the top, which makes them feel static and wrong.
    final scoped = _obligations
        .where((o) =>
            o.category.toLowerCase() == _selectedCategory.toLowerCase())
        .toList();
    final currency = auth is AuthAuthenticated
        ? resolveCurrencyCode(auth.user)
        : (scoped.isNotEmpty
            ? scoped.first.currency
            : (_obligations.isNotEmpty ? _obligations.first.currency : 'NGN'));
    final totalDueMinor =
        scoped.fold<int>(0, (sum, row) => sum + row.balanceMinor);
    final totalPaidMinor =
        scoped.fold<int>(0, (sum, row) => sum + row.paidAmountMinor);
    // Equity has no "next due" — it's share-based and never overdue. Show
    // a dash for that category instead of an upcoming date that doesn't
    // mean anything.
    final nextDueLabel = scoped.isEmpty
        ? 'N/A'
        : (_selectedCategory == 'Equity'
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
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
              style: TextStyle(color: onSurface, fontSize: 15.sp),
              decoration: InputDecoration.collapsed(
                hintText: 'Search obligations...',
                hintStyle: TextStyle(
                  color: onSurface.withValues(alpha: 0.5),
                  fontSize: 15.sp,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: (theme.brightness == Brightness.dark
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
                style: TextStyle(fontSize: 15.sp, color: Colors.red.shade400),
              ),
              vSpace(8),
              TextButton(onPressed: _loadObligations, child: const Text('Retry')),
            ],
          ),
        ),
      ];
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
            style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
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
              fontSize: 15.sp,
              color: isDark
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                  : Colors.grey.shade700,
            ),
          ),
          vSpace(4),
          Text(
            card.value,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: card.valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
