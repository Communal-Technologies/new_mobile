import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/data/local/kyc_progress_storage.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Opens the correct KYC screen for the current user using [KycProgressStorage].
void pushKycResumeRoute(BuildContext context) {
  final auth = context.read<AuthBloc>().state;
  if (auth is! AuthAuthenticated) {
    context.pushNamed('kyc-profile-info');
    return;
  }

  final userId = auth.userId;
  final storage = getIt<KycProgressStorage>();
  final step = storage.getResumeStep(userId);
  final anchor = storage.getAnchor(userId);

  if (anchor != null && anchor.isNotEmpty) {
    final extra = <String, dynamic>{'anchorCustomerId': anchor};
    if (step >= 3) {
      context.pushNamed('kyc-verifying', extra: extra);
      return;
    }
    if (step >= 2) {
      context.pushNamed('kyc-proof-of-identity', extra: extra);
      return;
    }
    if (step >= 1) {
      context.pushNamed('kyc-bank-info', extra: extra);
      return;
    }
  }

  context.pushNamed('kyc-profile-info');
}
