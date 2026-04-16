import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/utils/money_formatter.dart';
import 'package:communal_mobile/screens/transactions/models/sample_transactions.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/screens/transactions/widgets/transaction_tile.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/screens/transactions/widgets/filter_category_bottomsheet.dart';
import 'package:communal_mobile/screens/transactions/widgets/filter_status_bottomsheet.dart';
import 'package:communal_mobile/screens/transactions/widgets/download_statement_bottomsheet.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  int _currentTabIndex = 0; // 0 = Communal, 1 = Ledger
  int _currentNavIndex = 0;
  late final List<MapEntry<String, List<TransactionListItem>>>
  _monthlyTransactions;
  late final Map<String, bool> _expandedMonths;

  @override
  void initState() {
    super.initState();
    _monthlyTransactions = SampleTransactions.transactionsByMonth.entries
        .toList();
    _expandedMonths = {
      for (int i = 0; i < _monthlyTransactions.length; i++)
        _monthlyTransactions[i].key: i == 0,
    };
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download,
                        size: 18.sp,
                        color: Colors.grey.shade700,
                      ),
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
                    child: _buildFilterButton(icon: null, label: 'Successful'),
                  ),
                ],
              ),
            ),

            vSpace(8),

            // Transaction List
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemBuilder: (_, index) => _buildMonthSection(
                  _monthlyTransactions[index].key,
                  _monthlyTransactions[index].value,
                ),
                separatorBuilder: (_, __) => vSpace(16),
                itemCount: _monthlyTransactions.length,
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
            Icon(
              Icons.keyboard_arrow_down,
              size: 16.sp,
              color: Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSection(
    String month,
    List<TransactionListItem> transactions,
  ) {
    final isExpanded = _expandedMonths[month] ?? false;
    final incoming = transactions
        .where((t) => t.isCredit)
        .fold<double>(0, (sum, item) => sum + item.details.amount);
    final outgoing = transactions
        .where((t) => !t.isCredit)
        .fold<double>(0, (sum, item) => sum + item.details.amount);

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
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: Colors.grey.shade600,
                      size: 20.sp,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'In: ₦${formatMoney(incoming)}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                hSpace(12),
                Text(
                  'Out: ₦${formatMoney(outgoing)}',
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
          for (int i = 0; i < transactions.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == transactions.length - 1 ? 0 : 8.h,
              ),
              child: TransactionTile(
                item: transactions[i],
                onTap: () => _openTransactionDetails(transactions[i].details),
              ),
            ),
        ],
      ],
    );
  }

  void _openTransactionDetails(TransactionDetailsData data) {
    context.pushNamed('transaction-details', extra: data);
  }
}
