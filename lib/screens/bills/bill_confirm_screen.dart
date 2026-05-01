import 'dart:io';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/security/biometric_signer_service.dart';
import 'package:communal_mobile/core/utils/biometric_service.dart';
import 'package:communal_mobile/core/utils/dio_transport_user_message.dart';
import 'package:communal_mobile/core/utils/idempotency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/tap_debouncer.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/local/biometric_prefs.dart';
import 'package:communal_mobile/data/models/bills/bill_transaction.dart';
import 'package:communal_mobile/data/repositories/bills_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart' as shared_prefs;

/// Single authorization screen used by all four bill kinds (airtime,
/// data, electricity, television).
///
/// Auth ordering: **PIN is always the default**. Biometric is shown as
/// an optional secondary button when (a) the user has enabled biometric
/// for transactions in their preferences, AND (b) the device has an
/// enrolled biometric. Either path produces the headers the backend's
/// `biometric-sig:bill-purchase` middleware accepts.
///
/// Args (via go_router `extra`):
///   kind:           'airtime' | 'data' | 'electricity' | 'television'
///   provider:       provider slug
///   provider_name:  display name
///   phone_number:   MSISDN — also receipt-SMS phone for electricity / TV
///   amount_minor:   integer kobo
///   product_slug:   product slug (required for data, electricity, TV)
///   product_name:   display label for the product
///   meter_account_number: electricity only
///   smart_card_number:    television only
///   customer_name:        validated account name (electricity / TV)
class BillConfirmScreen extends StatefulWidget {
  const BillConfirmScreen({super.key, required this.args});

  final Map<String, dynamic> args;

  @override
  State<BillConfirmScreen> createState() => _BillConfirmScreenState();
}

/// Tracks the side-effect lifecycle once the user has authorized.
enum _Phase { idle, submitting, pending, completed, failed }

class _BillConfirmScreenState extends State<BillConfirmScreen> {
  late final BillsRepository _repo = BillsRepository(getIt<DioClient>());
  final BiometricSignerService _biometricSigner =
      getIt<BiometricSignerService>();
  final TapDebouncer _confirmDebouncer = TapDebouncer();

  /// Audit M23: minted once per screen mount; reused across user-initiated
  /// retries so a transient failure + retry dedupes server-side instead of
  /// double-charging the user's Anchor account.
  late final String _idempotencyKey = newIdempotencyKey();

  final TextEditingController _pinController = TextEditingController();

  /// True only when the user has enabled biometric for transactions AND
  /// the device has a biometric enrolled. PIN is the default in every
  /// other case.
  bool _biometricAvailable = false;
  String _biometricLabel = 'Biometrics';
  bool _authChecked = false;

  _Phase _phase = _Phase.idle;
  String? _errorMessage;
  BillTransaction? _txn;

  String get _kind => widget.args['kind'] as String;
  String get _provider => widget.args['provider'] as String;
  String get _providerName => widget.args['provider_name'] as String? ?? '';
  String get _phone => widget.args['phone_number'] as String;
  int get _amountMinor => widget.args['amount_minor'] as int;
  String? get _productSlug => widget.args['product_slug'] as String?;
  String? get _productName => widget.args['product_name'] as String?;
  String? get _meterAccountNumber =>
      widget.args['meter_account_number'] as String?;
  String? get _smartCardNumber => widget.args['smart_card_number'] as String?;
  String? get _customerName => widget.args['customer_name'] as String?;

  /// Friendly label for screen copy. `airtime` and `data` use the
  /// short forms; the longer pair name themselves explicitly.
  String get _kindLabel => switch (_kind) {
    'data' => 'Data',
    'electricity' => 'Electricity',
    'television' => 'Cable TV',
    _ => 'Airtime',
  };

  /// What we credit on the receiving end — phone number for airtime/data,
  /// meter for electricity, smartcard for cable TV.
  String get _recipientLabel => switch (_kind) {
    'electricity' => _meterAccountNumber ?? '—',
    'television' => _smartCardNumber ?? '—',
    _ => _phone,
  };

  String get _recipientFieldLabel => switch (_kind) {
    'electricity' => 'Meter number',
    'television' => 'Smartcard number',
    _ => 'Phone number',
  };

  @override
  void initState() {
    super.initState();
    _checkAuthReadiness();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthReadiness() async {
    try {
      final shared = await shared_prefs.SharedPreferences.getInstance();
      final prefs = BiometricPrefs(shared);
      // Biometric is offered only when the user has enabled it for
      // transactions AND the device has it enrolled. Anything else
      // means PIN-only — which is the default path anyway.
      final enabledForTransactions = prefs.transactionsEnabled;
      final enrolled = enabledForTransactions
          ? await _biometricSigner.isEnrolled()
          : false;
      String label = 'Biometrics';
      if (enrolled) {
        try {
          final types = await BiometricService.getAvailableBiometrics();
          if (types.contains(BiometricType.face)) {
            label = Platform.isIOS ? 'Face ID' : 'Face Unlock';
          } else if (types.contains(BiometricType.fingerprint)) {
            label = Platform.isIOS ? 'Touch ID' : 'Fingerprint';
          } else if (types.contains(BiometricType.weak) ||
              types.contains(BiometricType.strong)) {
            label = Platform.isIOS ? 'Face ID' : 'Fingerprint';
          }
        } catch (_) {
          // Fall back to the generic label.
        }
      }
      if (!mounted) return;
      setState(() {
        _biometricAvailable = enrolled;
        _biometricLabel = label;
        _authChecked = true;
      });
    } catch (e) {
      if (!mounted) return;
      // PIN path is always available, so a probe failure shouldn't
      // block the user — just degrade to PIN-only.
      setState(() {
        _biometricAvailable = false;
        _authChecked = true;
      });
    }
  }

  Future<Map<String, String>?> _resolvePinHeaders() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4 || int.tryParse(pin) == null) {
      AppToast.error('Enter your 4-digit transaction PIN to continue.');
      return null;
    }
    return {'X-Security-Pin': pin};
  }

  Future<Map<String, String>?> _resolveBiometricHeaders() async {
    try {
      final result = await _biometricSigner.signBillPurchaseIntent(
        promptTitle: 'Authorize bill payment',
        promptSubtitle:
            'Use $_biometricLabel to confirm this ${_kindLabel.toLowerCase()} purchase',
      );
      return result.toHeaders();
    } catch (e) {
      if (!mounted) return null;
      AppToast.error(humanizeError(e));
      return null;
    }
  }

  Future<void> _onConfirmWithPin() => _runPurchase(_resolvePinHeaders);

  Future<void> _onConfirmWithBiometric() =>
      _runPurchase(_resolveBiometricHeaders);

  Future<void> _runPurchase(
    Future<Map<String, String>?> Function() headersResolver,
  ) async {
    if (_phase == _Phase.submitting) return;
    final authHeaders = await headersResolver();
    if (authHeaders == null) return; // user cancelled or input invalid
    setState(() {
      _phase = _Phase.submitting;
      _errorMessage = null;
    });
    try {
      final txn = await switch (_kind) {
        'data' => _repo.purchaseData(
          provider: _provider,
          phoneNumber: _phone,
          productSlug: _productSlug ?? '',
          amountMinor: _amountMinor,
          idempotencyKey: _idempotencyKey,
          authHeaders: authHeaders,
        ),
        'electricity' => _repo.purchaseElectricity(
          provider: _provider,
          meterAccountNumber: _meterAccountNumber ?? '',
          phoneNumber: _phone,
          productSlug: _productSlug ?? '',
          amountMinor: _amountMinor,
          idempotencyKey: _idempotencyKey,
          authHeaders: authHeaders,
        ),
        'television' => _repo.purchaseTelevision(
          provider: _provider,
          smartCardNumber: _smartCardNumber ?? '',
          phoneNumber: _phone,
          productSlug: _productSlug ?? '',
          amountMinor: _amountMinor,
          idempotencyKey: _idempotencyKey,
          authHeaders: authHeaders,
        ),
        _ => _repo.purchaseAirtime(
          provider: _provider,
          phoneNumber: _phone,
          amountMinor: _amountMinor,
          idempotencyKey: _idempotencyKey,
          authHeaders: authHeaders,
        ),
      };
      if (!mounted) return;
      setState(() {
        _txn = txn;
        _phase = switch (txn.status) {
          BillStatus.completed => _Phase.completed,
          BillStatus.failed || BillStatus.reversed => _Phase.failed,
          _ => _Phase.pending,
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _errorMessage = humanizeError(e);
      });
    }
  }

  Future<void> _refreshStatus() async {
    final ref = _txn?.reference;
    if (ref == null || ref.isEmpty) return;
    try {
      final fresh = await _repo.fetchTransaction(ref);
      if (!mounted) return;
      setState(() {
        _txn = fresh;
        _phase = switch (fresh.status) {
          BillStatus.completed => _Phase.completed,
          BillStatus.failed || BillStatus.reversed => _Phase.failed,
          _ => _Phase.pending,
        };
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.error(humanizeError(e));
    }
  }

  bool get _isResultPhase =>
      _phase == _Phase.pending ||
      _phase == _Phase.completed ||
      _phase == _Phase.failed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (a, b) => a is AuthAuthenticated || b is AuthAuthenticated,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Confirm $_kindLabel'),
            elevation: 0,
            leading: IconButton(
              icon: Icon(_isResultPhase ? Icons.close : Icons.arrow_back),
              onPressed: () =>
                  _isResultPhase ? context.goNamed('home') : context.pop(),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(),
                  vSpace(20),
                  if (_isResultPhase)
                    _buildResultBlock()
                  else
                    _buildAuthBlock(),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
              child: _buildBottomButton(),
            ),
          ),
        );
      },
    );
  }

  // ---- Summary --------------------------------------------------------

  /// Brand accent per category — matches the landing tiles so the user
  /// has a continuous sense of "I'm in the airtime flow / TV flow".
  Color get _kindAccent => switch (_kind) {
    'data' => const Color(0xFF2BA6FF),
    'electricity' => const Color(0xFFFFB627),
    'television' => const Color(0xFF22C55E),
    _ => const Color(0xFFFF7B3D), // airtime
  };

  Widget _buildSummaryCard() {
    final theme = Theme.of(context);
    final amount = Money(_amountMinor, 'NGN').format();
    final accent = _kindAccent;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero amount block with a soft accent gradient.
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 18.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.12),
                  accent.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(_kindIcon, color: accent, size: 18.sp),
                    ),
                    hSpace(10),
                    Text(
                      '$_kindLabel purchase',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ),
                vSpace(8),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 18.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow(
                  _kind == 'electricity' || _kind == 'television'
                      ? 'Provider'
                      : 'Network',
                  _providerName,
                ),
                if (_productName != null) _summaryRow('Plan', _productName!),
                if (_customerName != null && _customerName!.isNotEmpty)
                  _summaryRow('Account name', _customerName!),
                _summaryRow(_recipientFieldLabel, _recipientLabel),
                if (_kind == 'electricity' || _kind == 'television')
                  _summaryRow('Receipt SMS to', _phone),
                if (_txn?.reference.isNotEmpty == true)
                  _summaryRow('Reference', _txn!.reference, monospace: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData get _kindIcon => switch (_kind) {
    'data' => Icons.public_outlined,
    'electricity' => Icons.flash_on_outlined,
    'television' => Icons.live_tv_outlined,
    _ => Icons.call_outlined, // airtime
  };

  Widget _summaryRow(String label, String value, {bool monospace = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Auth block (pre-confirmation) ---------------------------------

  Widget _buildAuthBlock() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your transaction PIN',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        vSpace(8),
        Text(
          'Type your 4-digit PIN to authorize this purchase.${_biometricAvailable ? ' Biometric authorization is optional below.' : ''}',
          style: TextStyle(
            fontSize: 17.sp,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        vSpace(20),
        _buildPinField(),
        if (_biometricAvailable) ...[
          vSpace(18),
          Center(
            child: Text(
              'or',
              style: TextStyle(
                fontSize: 15.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          vSpace(12),
          OutlinedButton.icon(
            onPressed: _phase == _Phase.submitting
                ? null
                : () => _confirmDebouncer.run(_onConfirmWithBiometric),
            icon: Icon(
              _biometricLabel.toLowerCase().contains('face')
                  ? Icons.face_outlined
                  : Icons.fingerprint,
              color: theme.primaryColor,
            ),
            label: Text(
              'Use $_biometricLabel instead',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 52.h),
              side: BorderSide(color: theme.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.r),
              ),
              foregroundColor: theme.primaryColor,
              surfaceTintColor: Colors.transparent,
            ),
          ),
        ],
        vSpace(20),
        Text(
          'Your transaction is encrypted and secure. Never share your PIN with anyone.',
          style: TextStyle(
            fontSize: 15.sp,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPinField() {
    return Center(
      child: SizedBox(
        width: 220.w,
        child: TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          textAlign: TextAlign.center,
          // Long-press paste / autofill from a password manager are
          // anti-patterns for transaction PIN. Lock the field down to
          // typed digits only.
          enableInteractiveSelection: false,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: 24.sp,
            letterSpacing: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••',
            hintStyle: TextStyle(
              fontSize: 24.sp,
              letterSpacing: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 16.h),
          ),
        ),
      ),
    );
  }

  // ---- Result block (post-confirmation) ------------------------------

  Widget _buildResultBlock() {
    final color = switch (_phase) {
      _Phase.completed => Colors.green.shade600,
      _Phase.failed => Colors.red.shade600,
      _ => const Color(0xFF7434FF),
    };
    final icon = switch (_phase) {
      _Phase.completed => Icons.check_rounded,
      _Phase.failed => Icons.close_rounded,
      _ => Icons.sync_rounded,
    };
    final title = switch (_phase) {
      _Phase.pending => '$_kindLabel purchase in progress',
      _Phase.completed => '$_kindLabel purchase successful',
      _Phase.failed => '$_kindLabel purchase failed',
      _ => '',
    };
    final body = switch (_phase) {
      _Phase.pending =>
        'The provider has accepted the request and will deliver shortly. We will notify you when it lands.',
      _Phase.completed =>
        'The provider has confirmed delivery to $_recipientLabel.',
      _Phase.failed =>
        _errorMessage ??
            'The provider rejected the request. You have not been charged.',
      _ => '',
    };

    return Center(
      child: Column(
        children: [
          vSpace(16),
          Container(
            width: 76.w,
            height: 76.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 38.sp),
          ),
          vSpace(16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Bottom button --------------------------------------------------

  Widget _buildBottomButton() {
    final purple = const Color(0xFF7434FF);

    if (_phase == _Phase.submitting) {
      return ElevatedButton(
        onPressed: null,
        style: _primaryStyle(purple),
        child: SizedBox(
          height: 22.h,
          width: 22.h,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (_phase == _Phase.pending) {
      return ElevatedButton.icon(
        onPressed: _refreshStatus,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh status'),
        style: _primaryStyle(purple),
      );
    }
    if (_phase == _Phase.completed) {
      return ElevatedButton(
        onPressed: () => context.goNamed('home'),
        style: _primaryStyle(purple),
        child: const Text('Done'),
      );
    }
    if (_phase == _Phase.failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () {
              // Drop back to the auth UI with the same idempotency key.
              setState(() => _phase = _Phase.idle);
            },
            style: _primaryStyle(purple),
            child: const Text('Try again'),
          ),
          vSpace(8),
          TextButton(
            onPressed: () => context.goNamed('home'),
            child: const Text('Back to home'),
          ),
        ],
      );
    }

    // _Phase.idle — primary CTA is always PIN. The biometric button
    // lives inside the auth block.
    return ElevatedButton.icon(
      onPressed: _authChecked
          ? () => _confirmDebouncer.run(_onConfirmWithPin)
          : null,
      icon: const Icon(Icons.lock_outline),
      label: Text(
        'Authorize with PIN',
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
      ),
      style: _primaryStyle(purple),
    );
  }

  ButtonStyle _primaryStyle(Color color) => ElevatedButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    minimumSize: Size(double.infinity, 52.h),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
  );
}
