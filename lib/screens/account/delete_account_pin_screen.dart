import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/payment_authorization.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/account_actions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/delete_account_request.dart';

class DeleteAccountPinScreen extends StatefulWidget {
  const DeleteAccountPinScreen({super.key, required this.request});

  final DeleteAccountRequest request;

  @override
  State<DeleteAccountPinScreen> createState() =>
      _DeleteAccountPinScreenState();
}

class _DeleteAccountPinScreenState extends State<DeleteAccountPinScreen>
    with PaymentAuthorization<DeleteAccountPinScreen> {
  @override
  String get pinIntent => 'account-action';

  @override
  Future<BiometricSignedHeaders> signBiometricIntent() {
    return biometricSigner.signAccountActionIntent(
      promptTitle: 'Delete your account',
      promptSubtitle: 'Use biometrics to confirm deleting your account',
    );
  }

  /// Authorising and deleting run back to back on purpose. The authorisation
  /// mints a short-lived marker in shared Redis that the delete endpoint
  /// consumes, so there is no step in between where it sits around unspent.
  ///
  /// Every checkpoint is re-run by the server against the state of the account
  /// at this moment rather than the preview the flow started from: a 409 means
  /// something changed while the user was reading the warnings.
  @override
  Future<void> submitAuthorized({
    String? pin,
    Map<String, String>? biometricHeaders,
  }) async {
    final auth = context.read<AuthBloc>();
    await getIt<AccountActionsRepository>().deleteAccount(
      confirmation: widget.request.confirmation,
      reason: widget.request.reason,
    );
    if (!mounted) return;
    // Leave the flow before signing out: the credentials are already dead
    // server-side, and the success screen is the one place the app can still
    // stand without a session.
    context.goNamed('delete-account-success');
    auth.add(LogoutRequested());
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
              'Delete your Account',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Column(
                children: [
                  Text(
                    offerBiometric ? 'Confirm Deletion' : 'Enter Transaction PIN',
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
                        ? 'Use biometrics, or enter your 4-digit PIN. Your '
                            'account is deleted as soon as it is authorised.'
                        : 'Enter your 4-digit PIN. Your account is deleted as '
                            'soon as the PIN is accepted.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.sp,
                      height: 1.4,
                      color: muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  vSpace(24),
                  buildPaymentPinPad(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
