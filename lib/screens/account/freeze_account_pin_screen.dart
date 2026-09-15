import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/widgets/payment_authorization.dart';
import 'package:communal_mobile/core/widgets/pin_pad_body.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/account_actions_repository.dart';
import 'package:communal_mobile/injection.dart';

class FreezeAccountPinScreen extends StatefulWidget {
  const FreezeAccountPinScreen({super.key, this.reason});

  /// Reason text passed from freeze_account_screen. Defaults to a
  /// generic reason if the user didn't supply one — the backend
  /// requires ≥ 10 chars.
  final String? reason;

  @override
  State<FreezeAccountPinScreen> createState() => _FreezeAccountPinScreenState();
}

class _FreezeAccountPinScreenState extends State<FreezeAccountPinScreen>
    with PaymentAuthorization<FreezeAccountPinScreen> {
  @override
  String get pinIntent => 'account-action';

  @override
  Future<BiometricSignedHeaders> signBiometricIntent() {
    return biometricSigner.signAccountActionIntent(
      promptTitle: 'Freeze your account',
      promptSubtitle: 'Use biometrics to confirm freezing your account',
    );
  }

  /// The server takes the same marker whichever factor minted it.
  @override
  Future<void> submitAuthorized({
    String? pin,
    Map<String, String>? biometricHeaders,
  }) async {
    final reason = (widget.reason?.trim().isNotEmpty == true)
        ? widget.reason!.trim()
        : 'Self-frozen via mobile app';
    await getIt<AccountActionsRepository>().freezeAccount(reason);
    if (!mounted) return;
    // Auth state needs to learn about the freeze — auth_status_notifier
    // gates protected routes off the user's wallet status.
    context.read<AuthBloc>().add(AuthRefreshUserRequested());
    context.pushReplacementNamed('freeze-account-success');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(theme),
      child: withPaymentLoader(
        Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Freeze Account',
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
                  offerBiometric ? 'Confirm Freeze' : 'Enter Transaction PIN',
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
                      ? 'Use biometrics, or enter your 4-digit PIN, to freeze '
                          'your account.'
                      : 'Enter your 4-digit PIN to freeze your account.',
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
