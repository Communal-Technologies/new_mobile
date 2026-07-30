import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/screens/obligations/widgets/fine_detail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Breakdown of how an obligation's fine accumulated — one row per fine cycle.
/// Reached by tapping the summed Fine card on the obligation detail screen.
class FineDetailsScreen extends StatelessWidget {
  const FineDetailsScreen({super.key, required this.obligation});

  final Obligation obligation;

  static const Color _accent = Color(0xFFD7263D);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Newest cycle first.
    final fines = [...obligation.fines]..sort((a, b) => b.date.compareTo(a.date));
    final currency = fines.isNotEmpty ? fines.first.currency : obligation.currency;
    final totalMinor = fines.fold<int>(0, (s, f) => s + f.amountMinor);
    final outstandingMinor =
        fines.fold<int>(0, (s, f) => s + f.outstandingMinor);
    final pendingCount = fines.where((f) => f.isPending).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Fine Details')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
        children: [
          Text(
            obligation.title,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
          ),
          vSpace(4),
          Text(
            'How this fine accumulated',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
          ),
          vSpace(16),
          // Summary
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDark
                  ? _accent.withValues(alpha: 0.16)
                  : const Color(0xFFFFEEF0),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total outstanding',
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade700),
                ),
                vSpace(4),
                Text(
                  Money(outstandingMinor, currency).format(),
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
                vSpace(8),
                Text(
                  '${fines.length} fine${fines.length == 1 ? '' : 's'} • '
                  '$pendingCount pending • '
                  '${Money(totalMinor, currency).format()} levied',
                  style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          vSpace(20),
          Text(
            'Breakdown',
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
          ),
          vSpace(8),
          if (fines.isEmpty)
            Text('No fines yet.',
                style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600))
          else
            for (final f in fines) ...[
              FineDetailCard(
                fine: f,
                cooperativeId: obligation.cooperativeId,
              ),
              vSpace(8),
            ],
        ],
      ),
    );
  }
}
