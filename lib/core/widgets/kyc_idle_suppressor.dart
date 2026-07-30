import 'dart:async';

import 'package:communal_mobile/cubits/security/security_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// While a KYC screen is mounted, keep the session "active" and clear any idle
/// prompt so long forms are not interrupted. Uses the same [SecurityCubit] as
/// [SecurityWrapper] (from [BlocProvider]), not a separate DI instance.
class KycIdleSuppressor extends StatefulWidget {
  const KycIdleSuppressor({super.key, required this.child});

  final Widget child;

  @override
  State<KycIdleSuppressor> createState() => _KycIdleSuppressorState();
}

class _KycIdleSuppressorState extends State<KycIdleSuppressor> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ping();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _ping());
  }

  void _ping() {
    if (!mounted) return;
    final cubit = context.read<SecurityCubit>();
    if (cubit.state == SecurityState.idlePrompt) {
      cubit.resetIdle();
    }
    cubit.recordActivity();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
