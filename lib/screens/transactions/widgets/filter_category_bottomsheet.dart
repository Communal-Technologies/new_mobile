import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/transactions/transaction_history_filters.dart';

class FilterCategoryBottomSheet extends StatefulWidget {
  const FilterCategoryBottomSheet({
    super.key,
    this.initialDirection = 'All',
    this.initialPaymentType = 'All Categories',
  });

  final String initialDirection;
  final String initialPaymentType;

  @override
  State<FilterCategoryBottomSheet> createState() =>
      _FilterCategoryBottomSheetState();
}

class _FilterCategoryBottomSheetState extends State<FilterCategoryBottomSheet> {
  late String _selectedCategory;
  late String _selectedPaymentType;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialDirection;
    _selectedPaymentType = widget.initialPaymentType;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Category',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          vSpace(20),
          Row(
            children: [
              _buildCategoryChip('All', theme),
              hSpace(10),
              _buildCategoryChip('Money In', theme),
              hSpace(10),
              _buildCategoryChip('Money Out', theme),
            ],
          ),
          vSpace(24),
          Text(
            'Payment Type',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          vSpace(12),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: [
              _buildPaymentTypeChip('All Categories', theme),
              _buildPaymentTypeChip('Transfers', theme),
              _buildPaymentTypeChip('Contributions', theme),
              _buildPaymentTypeChip('Loans', theme),
              _buildPaymentTypeChip('Interest Earned', theme),
              _buildPaymentTypeChip('Withdrawals', theme),
              _buildPaymentTypeChip('Bill Payments', theme),
              _buildPaymentTypeChip('Savings', theme),
            ],
          ),
          vSpace(24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop<CategoryFilterResult?>(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
              hSpace(12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(
                      context,
                      CategoryFilterResult(
                        direction: _selectedCategory,
                        paymentType: _selectedPaymentType,
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, ThemeData theme) {
    final isSelected = _selectedCategory == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTypeChip(String label, ThemeData theme) {
    final isSelected = _selectedPaymentType == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentType = label;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
