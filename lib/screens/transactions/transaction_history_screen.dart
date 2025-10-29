import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/screens/transactions/widgets/filter_category_bottomsheet.dart';
import 'package:communal_mobile/screens/transactions/widgets/filter_status_bottomsheet.dart';
import 'package:communal_mobile/screens/transactions/widgets/download_statement_bottomsheet.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  int _currentTabIndex = 0; // 0 = Communal, 1 = Ledger
  int _currentNavIndex = 0;
  final Map<String, bool> _expandedMonths = {
    'October': true,
    'September': true,
  };

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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.sp),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Transaction History',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const DownloadStatementBottomSheet(),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, size: 18.sp, color: Colors.grey.shade700),
                      hSpace(6),
                      Text(
                        'Statement',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Tabs
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(child: _buildTab('Communal (Personal)', 0, theme)),
                  Expanded(child: _buildTab('Ledger (Cooperative)', 1, theme)),
                ],
              ),
            ),

            // Filters
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
              child: Row(
                children: [
                  Flexible(
                    child: _buildFilterButton(
                      icon: Icons.filter_list,
                      label: 'All Categories',
                    ),
                  ),
                  hSpace(12),
                  Flexible(
                    child: _buildFilterButton(
                      icon: null,
                      label: 'Successful',
                    ),
                  ),
                ],
              ),
            ),

            vSpace(8),

            // Transaction List
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                children: [
                  _buildMonthSection('October', '552.65k', '165.00k', _octoberTransactions()),
                  vSpace(16),
                  _buildMonthSection('September', '125.00k', '75.00k', _septemberTransactions()),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            setState(() {
              _currentNavIndex = index;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index, ThemeData theme) {
    final isActive = _currentTabIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? theme.primaryColor : Colors.grey.shade600,
            ),
          ),
          vSpace(8),
          Container(
            height: 3.h,
            decoration: BoxDecoration(
              color: isActive ? theme.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({IconData? icon, required String label}) {
    return GestureDetector(
      onTap: () {
        if (label == 'All Categories') {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const FilterCategoryBottomSheet(),
          );
        } else if (label == 'Successful') {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const FilterStatusBottomSheet(),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16.sp, color: Colors.grey.shade700),
              hSpace(6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            hSpace(4),
            Icon(Icons.keyboard_arrow_down, size: 16.sp, color: Colors.grey.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSection(String month, String incoming, String outgoing, List<Widget> transactions) {
    final isExpanded = _expandedMonths[month] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month header
        GestureDetector(
          onTap: () {
            setState(() {
              _expandedMonths[month] = !isExpanded;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    Text(
                      month,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    hSpace(6),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      color: Colors.grey.shade600,
                      size: 20.sp,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'In: ₦$incoming',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                hSpace(12),
                Text(
                  'Out: ₦$outgoing',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Transactions list
        if (isExpanded) ...[
          vSpace(8),
          ...transactions,
        ],
      ],
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String date,
    required String amount,
    required Color amountColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22.sp,
            ),
          ),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                vSpace(4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _octoberTransactions() {
    return [
      _buildTransactionItem(
        icon: Icons.people,
        iconColor: Colors.white,
        iconBgColor: Color(0xFF742CE7),
        title: 'Cooperative Contribution',
        date: 'Oct 18, 2025 6:40 AM',
        amount: '+₦50,000.00',
        amountColor: Colors.green,
      ),
      _buildTransactionItem(
        icon: Icons.trending_up,
        iconColor: Colors.white,
        iconBgColor: Color(0xFF00BCD4),
        title: 'Interest Earned',
        date: 'Oct 17, 2025 12:00 PM',
        amount: '+₦1,274.00',
        amountColor: Colors.green,
      ),
      _buildTransactionItem(
        icon: Icons.account_balance_wallet,
        iconColor: Colors.white,
        iconBgColor: Color(0xFF742CE7),
        title: 'Savings Deposit',
        date: 'Oct 16, 2025 9:15 AM',
        amount: '₦100,000.00',
        amountColor: Colors.black,
      ),
      _buildTransactionItem(
        icon: Icons.send,
        iconColor: Colors.white,
        iconBgColor: Colors.red,
        title: 'Send - Mary Johnson',
        date: 'Oct 15, 2025 3:30 PM',
        amount: '₦50,000.00',
        amountColor: Colors.black,
      ),
      _buildTransactionItem(
        icon: Icons.flash_on,
        iconColor: Colors.white,
        iconBgColor: Colors.orange,
        title: 'Bill Payment - Electricity',
        date: 'Oct 14, 2025 10:20 AM',
        amount: '₦15,000.00',
        amountColor: Colors.black,
      ),
      _buildTransactionItem(
        icon: Icons.trending_up,
        iconColor: Colors.white,
        iconBgColor: Color(0xFF00BCD4),
        title: 'Interest Earned',
        date: 'Oct 13, 2025 12:00 PM',
        amount: '+₦1,372.00',
        amountColor: Colors.green,
      ),
      _buildTransactionItem(
        icon: Icons.people,
        iconColor: Colors.white,
        iconBgColor: Color(0xFF4CAF50),
        title: 'Loan Disbursement',
        date: 'Oct 12, 2025 8:45 AM',
        amount: '+₦500,000.00',
        amountColor: Colors.green,
      ),
    ];
  }

  List<Widget> _septemberTransactions() {
    return [
      _buildTransactionItem(
        icon: Icons.people,
        iconColor: Colors.white,
        iconBgColor: Color(0xFF742CE7),
        title: 'Cooperative Contribution',
        date: 'Sep 18, 2025 6:40 AM',
        amount: '+₦50,000.00',
        amountColor: Colors.green,
      ),
      _buildTransactionItem(
        icon: Icons.people,
        iconColor: Colors.white,
        iconBgColor: Colors.red,
        title: 'Loan Repayment',
        date: 'Sep 15, 2025 2:15 PM',
        amount: '₦25,000.00',
        amountColor: Colors.black,
      ),
      _buildTransactionItem(
        icon: Icons.call_received,
        iconColor: Colors.white,
        iconBgColor: Color(0xFF4CAF50),
        title: 'Receive - John Doe',
        date: 'Sep 10, 2025 11:30 AM',
        amount: '+₦75,000.00',
        amountColor: Colors.green,
      ),
    ];
  }
}

