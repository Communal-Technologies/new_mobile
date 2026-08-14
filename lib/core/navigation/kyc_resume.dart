import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/data/local/kyc_progress_storage.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Opens the correct KYC screen for the current user — **first incomplete** step, not last visited.
void pushKycResumeRoute(BuildContext context) {
  final auth = context.read<AuthBloc>().state;
  if (auth is! AuthAuthenticated) {
    context.pushNamed('kyc-profile-info');
    return;
  }

  final userId = auth.userId;
  final storage = getIt<KycProgressStorage>();
  final dest = storage.resumeDestination(
    userId,
    communalTier: auth.user.communalTier,
    backendStep1Submitted: auth.user.kycStep1Submitted,
    backendStep2Submitted: auth.user.kycStep2Submitted,
    backendStep3Submitted: auth.user.kycStep3Submitted,
    kycRejected: auth.user.isKycRejected,
  );
  // Prefs are cleared when the flow completes, so fall back to the backend copy
  // — the later steps take the id from these extras and have no other source.
  final anchor = storage.getAnchor(userId) ?? auth.user.kycAnchorCustomerId;
  final extra = anchor != null && anchor.isNotEmpty
      ? <String, dynamic>{'anchorCustomerId': anchor}
      : <String, dynamic>{};

  switch (dest) {
    case KycResumeDestination.profile:
      context.pushNamed('kyc-profile-info');
      return;
    case KycResumeDestination.bank:
      context.pushNamed('kyc-bank-info', extra: extra);
      return;
    case KycResumeDestination.proof:
      context.pushNamed('kyc-proof-of-identity', extra: extra);
      return;
    case KycResumeDestination.verifying:
      context.pushNamed('kyc-verifying', extra: extra);
      return;
  }
}
