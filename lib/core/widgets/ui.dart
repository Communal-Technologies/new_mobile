import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/apptext.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:iconsax/iconsax.dart';
import 'bottomsheet_handlebar.dart';

class UiService {
  Future showInfoDialog({
    required BuildContext context,
    required Widget content,
    bool barrierDismissible = true,
  }) async {
    return await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AlertDialog(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: SizedBox(width: 343.w, child: content),
      ),
    );
  }

  Future showLocationDisclosure({
    required BuildContext context,
    required void Function()? onAccept,
    required void Function()? onReject,
  }) async {
    final theme = Theme.of(context);

    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: SizedBox(
          width: 343.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BigAppText(
                'Location Disclosure',
                color: theme.colorScheme.onSurface,
              ),
              vSpace(10),
              SmallAppText(
                "This app uses your location to find nearby couriers. Your data is private and never shared without consent. Adjust settings anytime.",
                color: theme.hintColor,
              ),
              vSpace(20),
              Row(
                children: [
                  if (Platform.isAndroid)
                    Expanded(
                      child: AppOutlinedButton(
                        title: 'Reject',
                        onPressed: onReject,
                      ),
                    ),
                  if (Platform.isAndroid) hSpace(20),
                  Expanded(
                    child: AppElevatedButton(
                      title: Platform.isAndroid ? 'Accept' : 'Continue',
                      onPressed: onAccept,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future showInfoDialogString({
    required BuildContext context,
    required String data,
    bool barrierDismissible = true,
  }) async {
    final theme = Theme.of(context);

    return await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: SizedBox(
          width: 343.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.info_circle, color: theme.primaryColor, size: 50.r),
              vSpace(10),
              MedAppText(
                data,
                alignment: TextAlign.center,
                fontSize: 14.sp,
                color: theme.colorScheme.onSurface,
              ),
              vSpace(20),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: SmallAppText('OK', color: theme.primaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future showLoadingDialog(BuildContext context) async {
    final theme = Theme.of(context);

    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) =>
          Center(child: SpinKitRipple(color: theme.primaryColor, size: 70)),
    );
  }

  Future showLoadingDialogWithMessage(
    BuildContext context,
    String message,
  ) async {
    final theme = Theme.of(context);

    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpinKitRipple(color: theme.primaryColor, size: 70),
            vSpace(10),
            SmallAppText(message, color: theme.colorScheme.onSurface),
          ],
        ),
      ),
    );
  }

  Future showBottomSheet({
    required BuildContext context,
    String? title,
    String? description,
    bool isDismissible = true,
    required Widget content,
  }) async {
    final theme = Theme.of(context);

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BottomSheetHandlebar(),
            if (title != null)
              Align(
                alignment: Alignment.center,
                child: BigAppText(title, color: theme.colorScheme.onSurface),
              ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: SmallAppText(description, color: theme.hintColor),
              ),
            content,
          ],
        ),
      ),
    );
  }

  void showSuccessSnackBar(BuildContext context, String message) {
    final theme = Theme.of(context);

    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(color: theme.colorScheme.onPrimary),
      ),
      backgroundColor: theme.primaryColor,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void showErrorSnackBar(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
