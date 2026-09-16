import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/payment_authorization.dart';
import 'package:communal_mobile/core/widgets/pin_pad_body.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/account_actions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/community/leave_cooperative_screen.dart';

/// The last gate before the request is filed: the PIN or biometrics proves it
/// is the member holding the phone, then the request itself is submitted from
/// here so a verified authorisation is never left sitting unspent.
class LeaveCooperativePinScreen extends StatefulWidget {
  const LeaveCooperativePinScreen({super.key, required this.request});

  final LeaveCooperativeRequest request;

  @override
  State<LeaveCooperativePinScreen> createState() =>
      _LeaveCooperativePinScreenState();
}

class _LeaveCooperativePinScreenState extends State<LeaveCooperativePinScreen>
    with PaymentAuthorization<LeaveCooperativePinScreen> {
  @override
  String get pinIntent => 'account-action';

  @override
  Future<BiometricSignedHeaders> signBiometricIntent() {
    return biometricSigner.signAccountActionIntent(
      promptTitle: 'Leave ${widget.request.location.name}',
      promptSubtitle: 'Use biometrics to send your request',
    );
  }

  /// The server takes the same marker whichever factor minted it.
  @override
  Future<void> submitAuthorized({
    String? pin,
    Map<String, String>? biometricHeaders,
  }) async {
    await getIt<AccountActionsRepository>().submitAccountClosure(
      cooperativeId: widget.request.location.id,
      reason: widget.request.reason,
    );
    if (!mounted) return;
    context.pushReplacementNamed(
      'leave-cooperative-submitted',
      extra: widget.request.location,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(theme),
      child: withPaymentLoader(
        Scaffold(
          backgroundColor: theme.cardColor,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Leave Cooperative',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: PinPadBody(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              header: [
                Text(
                  offerBiometric ? 'Confirm Request' : 'Enter Transaction PIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                vSpace(4),
                Text(
                  offerBiometric
                      ? 'Use biometrics, or enter your 4-digit PIN, to send '
                          'your request to leave ${widget.request.location.name}.'
                      : 'Enter your 4-digit PIN to send your request to leave '
                          '${widget.request.location.name}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    height: 1.4,
                    color: muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                vSpace(24),
              ],
              pad: buildPaymentPinPad(),
            ),
          ),
        ),
      ),
    );
  }
}
