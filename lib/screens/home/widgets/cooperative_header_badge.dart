import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Cooperative logo when [UserModel.cooperativeLogoUrl] is a valid HTTP(S) URL;
/// otherwise shows name + ledger like the previous header chip.
class CooperativeHeaderBadge extends StatelessWidget {
  const CooperativeHeaderBadge({
    super.key,
    required this.user,
    required this.theme,
  });

  final UserModel? user;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final logo = user?.cooperativeLogoUrl?.trim();
    final line1 = user?.cooperativeDisplayName ?? '—';
    final line2 = user?.ledgerNumber?.trim() ?? '';

    final useNetworkLogo = logo != null &&
        logo.isNotEmpty &&
        (logo.startsWith('http://') || logo.startsWith('https://'));

    if (useNetworkLogo) {
      return Container(
        width: 56.w,
        height: 48.h,
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: Image.network(
            logo,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _textFallback(context,line1, line2),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.primaryColor,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: _textFallback(context,line1, line2),
    );
  }

  Widget _textFallback(BuildContext context, String line1, String line2) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          line1,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: theme.primaryColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (line2.isNotEmpty) ...[
          vSpace(2),
          Text(
            line2,
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
