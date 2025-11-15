import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/obligations/data/sample_obligations.dart';
import 'package:communal_mobile/screens/obligations/widgets/obligation_card.dart';

class FinancialObligationsScreen extends StatefulWidget {
  const FinancialObligationsScreen({super.key});

  @override
  State<FinancialObligationsScreen> createState() =>
      _FinancialObligationsScreenState();
}

class _FinancialObligationsScreenState
    extends State<FinancialObligationsScreen> {
  final _searchController = TextEditingController();
  final List<String> _categories = ['Equity', 'Patronage', 'Custom', 'Fine'];

  String _selectedCategory = 'Equity';
  int _currentNavIndex = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
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
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            if (index == _currentNavIndex) return;
            if (index == 0) {
              context.go('/home');
            } else {
              setState(() => _currentNavIndex = index);
            }
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        _roundedIcon(
          icon: Icons.menu,
          onTap: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Open menu')));
          },
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'Financial Obligations',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              vSpace(4),
              Text(
                'Total Lenders Forum',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        _roundedIcon(icon: Icons.refresh, onTap: () {}),
      ],
    );
  }

  Widget _roundedIcon({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 20.sp),
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    final cards = [
      _SummaryCardData(
        label: 'Total Due',
        value: '₦900,000',
        color: const Color(0xFFFFE6E9),
        icon: Icons.error_outline,
        valueColor: const Color(0xFFD7263D),
      ),
      _SummaryCardData(
        label: 'Total Paid',
        value: '₦1,000,000',
        color: const Color(0xFFE7FFF2),
        icon: Icons.check_circle_outline,
        valueColor: const Color(0xFF1AAE70),
      ),
      _SummaryCardData(
        label: 'Next Due',
        value: 'Nov 10, 2024',
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
              onSelected: (_) {
                setState(() => _selectedCategory = category);
              },
              selectedColor: theme.primaryColor,
              labelStyle: TextStyle(
                color: isActive ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
                side: BorderSide(
                  color: isActive ? theme.primaryColor : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          hSpace(10),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration.collapsed(
                hintText: 'Search obligations...',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.filter_alt_outlined,
              color: theme.primaryColor,
              size: 20.sp,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildObligationList(ThemeData theme) {
    final query = _searchController.text.toLowerCase();
    final items = SampleObligations.all.where((obligation) {
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
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
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
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: card.color,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(card.icon, color: card.valueColor, size: 18.sp),
          vSpace(12),
          Text(
            card.label,
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
          ),
          vSpace(4),
          Text(
            card.value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: card.valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
