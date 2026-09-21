import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/bills/bill_product.dart';

/// The validity a plan is sold on, read out of the name and code the biller
/// catalogue returns ("DataPlan 100MB Daily (24 Hours)", "gotv_lite_month_1"),
/// so the tabs are the biller's own categories rather than a list we keep here.
String billPlanCategory(BillProduct product) {
  final text = '${product.name} ${product.slug}'.toLowerCase();

  if (text.contains('night')) return 'Night';
  if (text.contains('weekend')) return 'Weekend';
  if (text.contains('year') || text.contains('annual') || text.contains('365')) {
    return 'Yearly';
  }
  if (text.contains('quarter') || text.contains('90 day')) return 'Quarterly';
  if (text.contains('month')) return 'Monthly';
  if (text.contains('week')) return 'Weekly';
  if (text.contains('daily') || text.contains('24 hour') || text.contains('hour')) {
    return 'Daily';
  }

  final days = RegExp(r'(\d+)\s*-?\s*day').firstMatch(text);
  if (days != null) {
    final n = int.tryParse(days.group(1) ?? '') ?? 0;
    if (n == 1) return 'Daily';
    if (n == 7) return 'Weekly';
    if (n >= 28 && n <= 31) return 'Monthly';
    if (n >= 360) return 'Yearly';
    if (n > 1) return '$n days';
  }
  return 'Other';
}

/// Categories in the order a member reads them — shortest validity first — with
/// any category the catalogue invents appended rather than dropped.
List<String> billPlanCategories(List<BillProduct> products) {
  const order = [
    'Daily',
    'Weekly',
    'Monthly',
    'Quarterly',
    'Yearly',
    'Night',
    'Weekend',
    'Other',
  ];
  final found = products.map(billPlanCategory).toSet().toList();
  found.sort((a, b) {
    int rank(String c) {
      final i = order.indexOf(c);
      if (i >= 0) return i;
      final days = RegExp(r'^(\d+) days$').firstMatch(c);
      // "2 days" and "3 days" sit between Daily and Weekly.
      return days == null ? order.length : 1;
    }

    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return a.compareTo(b);
  });
  return found;
}

/// Plans grouped into tabs: a horizontally scrolling row of the catalogue's
/// categories over a grid of the plans in the selected one. Replaces the single
/// dropdown, which listed every plan of every length in one column.
class BillPlanPicker extends StatefulWidget {
  const BillPlanPicker({
    super.key,
    required this.products,
    required this.selected,
    required this.onSelected,
    required this.accent,
    this.currency = 'NGN',
  });

  final List<BillProduct> products;
  final BillProduct? selected;
  final ValueChanged<BillProduct> onSelected;
  final Color accent;
  final String currency;

  @override
  State<BillPlanPicker> createState() => _BillPlanPickerState();
}

class _BillPlanPickerState extends State<BillPlanPicker> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = billPlanCategories(widget.products);
    if (categories.isEmpty) return const SizedBox.shrink();

    final selectedCategory = categories.contains(_category)
        ? _category!
        : (widget.selected != null &&
                  categories.contains(billPlanCategory(widget.selected!))
              ? billPlanCategory(widget.selected!)
              : categories.first);
    final plans = widget.products
        .where((p) => billPlanCategory(p) == selectedCategory)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in categories)
                  Padding(
                    padding: EdgeInsets.only(right: 10.w),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: category == selectedCategory,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _category = category),
                      selectedColor: widget.accent,
                      labelStyle: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: category == selectedCategory
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                      backgroundColor: theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                        side: BorderSide(
                          color: category == selectedCategory
                              ? widget.accent
                              : theme.dividerColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (categories.length > 1) vSpace(12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10.w,
            mainAxisSpacing: 10.h,
            childAspectRatio: 1.7,
          ),
          itemCount: plans.length,
          itemBuilder: (_, i) => _PlanCard(
            product: plans[i],
            selected: widget.selected?.id == plans[i].id,
            accent: widget.accent,
            currency: widget.currency,
            onTap: () => widget.onSelected(plans[i]),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.selected,
    required this.accent,
    required this.currency,
    required this.onTap,
  });

  final BillProduct product;
  final bool selected;
  final Color accent;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : theme.cardColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: selected ? accent : theme.dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              product.name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              Money(product.priceMinor, currency).format(),
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: selected ? accent : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
