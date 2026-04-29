import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/idempotency.dart';
import 'package:communal_mobile/data/local/kyc_progress_storage.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/data/repositories/kyc_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/kyc_idle_suppressor.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

const Map<String, String> _kycMonthToNum = {
  'January': '01',
  'February': '02',
  'March': '03',
  'April': '04',
  'May': '05',
  'June': '06',
  'July': '07',
  'August': '08',
  'September': '09',
  'October': '10',
  'November': '11',
  'December': '12',
};

final Map<String, String> _kycDayPadded = {
  for (int i = 1; i <= 31; i++) '$i': i < 10 ? '0$i' : '$i',
};

class BankInformationScreen extends StatefulWidget {
  const BankInformationScreen({super.key});

  @override
  State<BankInformationScreen> createState() => _BankInformationScreenState();
}

class _BankInformationScreenState extends State<BankInformationScreen> {
  final _bvnController = TextEditingController();

  /// Resolved from one of two trusted sources (audit M30 — route extras are
  /// no longer accepted):
  ///
  /// 1. [AuthAuthenticated.user.kycAnchorCustomerId] — server-vouched, comes
  ///    straight from `/get-loggedin-user` (`kyc.anchor_customer_id`). This
  ///    is the cross-device-resume path: a fresh sign-in on a new device
  ///    has no local storage but the backend still knows the anchor.
  /// 2. [KycProgressStorage.getAnchor] — per-user-keyed local cache written
  ///    by [KycProgressStorage.saveAfterProfileRegistered] right after the
  ///    `/compliance/register/{id}` response. Same-device resume.
  String? _resolvedAnchor;

  String? _effectiveAnchor() {
    if (_resolvedAnchor != null && _resolvedAnchor!.isNotEmpty) {
      return _resolvedAnchor;
    }
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      final fromUser = auth.user.kycAnchorCustomerId?.trim();
      if (fromUser != null && fromUser.isNotEmpty) return fromUser;
      return getIt<KycProgressStorage>().getAnchor(auth.userId);
    }
    return null;
  }

  String? _bvnError;
  String? _dayError;
  String? _monthError;
  String? _yearError;
  String? _genderError;

  String? _selectedDay;
  String? _selectedMonth;
  String? _selectedYear;
  String? _selectedGender;

  bool _isSubmitting = false;

  /// Audit M23: minted once per screen mount; reused across user retries so
  /// a transient 5xx + retry doesn't trigger duplicate Anchor BVN submissions.
  late final String _idempotencyKey = newIdempotencyKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncAnchorFromStorage(),
    );
  }

  void _syncAnchorFromStorage() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final storage = getIt<KycProgressStorage>();
    final fromUser = auth.user.kycAnchorCustomerId?.trim();
    final fromDisk = storage.getAnchor(auth.userId);
    final resolved = (fromUser != null && fromUser.isNotEmpty)
        ? fromUser
        : fromDisk;
    if (!mounted) return;
    setState(() => _resolvedAnchor = resolved);
    // Mirror the server-vouched value into local storage so the next launch
    // (or any flow that consults storage first) stays consistent without
    // needing another /get-loggedin-user round-trip.
    if (fromUser != null && fromUser.isNotEmpty) {
      storage.ensureAnchorSynced(auth.userId, fromUser);
    }
  }

  @override
  void dispose() {
    _bvnController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _bvnError = null;
      _dayError = null;
      _monthError = null;
      _yearError = null;
      _genderError = null;
    });
  }

  bool _validateForm() {
    _clearErrors();
    bool isValid = true;

    if (_bvnController.text.isEmpty) {
      setState(() {
        _bvnError = 'BVN is required';
      });
      isValid = false;
    } else if (_bvnController.text.length != 11) {
      setState(() {
        _bvnError = 'BVN must be 11 digits';
      });
      isValid = false;
    }

    if (_selectedDay == null) {
      setState(() {
        _dayError = 'Day is required';
      });
      isValid = false;
    }

    if (_selectedMonth == null) {
      setState(() {
        _monthError = 'Month is required';
      });
      isValid = false;
    }

    if (_selectedYear == null) {
      setState(() {
        _yearError = 'Year is required';
      });
      isValid = false;
    }

    if (_selectedGender == null) {
      setState(() {
        _genderError = 'Gender is required';
      });
      isValid = false;
    }

    return isValid;
  }

  Map<String, dynamic> _kycExtra() {
    final id = _effectiveAnchor();
    if (id == null || id.isEmpty) return {};
    return <String, dynamic>{'anchorCustomerId': id};
  }

  Future<void> _markBankStepAndGo() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      await getIt<KycProgressStorage>().markBankStepDone(auth.userId);
    }
    if (!mounted) return;
    // ignore: unawaited_futures
    context.push('/kyc/proof-of-identity', extra: _kycExtra());
  }

  String _formatDobForApi() {
    final m = _kycMonthToNum[_selectedMonth!]!;
    final d = _kycDayPadded[_selectedDay!]!;
    return '$_selectedYear-$m-$d';
  }

  String _genderForApi() => _selectedGender == 'Female' ? 'female' : 'male';

  /// Deposit ledger can arrive shortly after Anchor via webhook; mirror legacy polling without blocking HTTP.
  Future<void> _pollLedgerIfEmpty(String token) async {
    for (var i = 0; i < 12; i++) {
      if (!mounted) return;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        getIt<AuthRepository>().updateToken(token);
        final user = await getIt<AuthRepository>().getUserInfo(token);
        if (!mounted || user == null) continue;
        final ledger = user.ledgerNumber?.trim();
        if (ledger != null && ledger.isNotEmpty) {
          context.read<AuthBloc>().add(AuthUserUpdated(user));
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> _skip() async {
    if (_isSubmitting) return;
    final id = _effectiveAnchor();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing customer id. Complete profile verification first.',
          ),
        ),
      );
      return;
    }
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      await getIt<KycProgressStorage>().markBankStepDone(auth.userId);
    }
    if (!mounted) return;
    // ignore: unawaited_futures
    context.push('/kyc/proof-of-identity', extra: _kycExtra());
  }

  Future<void> _continue() async {
    if (_isSubmitting) return;
    if (!_validateForm()) return;
    final id = _effectiveAnchor();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing customer id. Complete profile verification first.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await getIt<KycRepository>().upgradeToTier1(
        anchorCustomerId: id,
        bvn: _bvnController.text.trim(),
        dateOfBirth: _formatDobForApi(),
        gender: _genderForApi(),
        idempotencyKey: _idempotencyKey,
      );

      try {
        final token = await getIt<FlutterSecureStorage>().read(key: 'token');
        if (token != null && mounted) {
          getIt<AuthRepository>().updateToken(token);
          final user = await getIt<AuthRepository>().getUserInfo(token);
          if (mounted && user != null) {
            context.read<AuthBloc>().add(AuthUserUpdated(user));
            final ledger = user.ledgerNumber?.trim();
            if (ledger == null || ledger.isEmpty) {
              await _pollLedgerIfEmpty(token);
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;
      await _markBankStepAndGo();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Request failed' : msg)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.read<AuthBloc>().state;
    final hideBack =
        auth is AuthAuthenticated &&
        (auth.user.kycStep1Submitted ||
            getIt<KycProgressStorage>().getResumeStep(auth.userId) >= 1);

    return KycIdleSuppressor(
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: hideBack
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
          title: Text(
            'Bank Information',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Header with progress
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    vSpace(4),
                    Center(
                      child: Text(
                        'Secure your account',
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    vSpace(12),
                    // Title and step counter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bank Information',
                          style: TextStyle(
                            fontSize: 17.sp,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Step 2 of 3',
                          style: TextStyle(
                            fontSize: 17.sp,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    vSpace(8),
                    // Progress bar
                    LinearProgressIndicator(
                      value: 2 / 3,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.primaryColor,
                      ),
                      minHeight: 4.h,
                    ),
                  ],
                ),
              ),

              vSpace(24),

              // Form content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Connect your BVN
                      Text(
                        'Connect your BVN',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      vSpace(16),
                      CustomTextField(
                        controller: _bvnController,
                        hintText: 'Enter your 11 digit BVN',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        maxLength: 11,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        errorText: _bvnError,
                        onChanged: (_) => _clearErrors(),
                        onFieldSubmitted: (_) {
                          if (!mounted) return;
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                      ),

                      vSpace(32),

                      // Date of Birth
                      Text(
                        'Date of Birth',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      vSpace(16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: 'Day',
                              value: _selectedDay,
                              items: List.generate(31, (i) => '${i + 1}'),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDay = value;
                                  _dayError = null;
                                });
                              },
                              errorText: _dayError,
                            ),
                          ),
                          hSpace(12),
                          Expanded(
                            child: _buildDropdown(
                              label: 'Month',
                              value: _selectedMonth,
                              items: [
                                'January',
                                'February',
                                'March',
                                'April',
                                'May',
                                'June',
                                'July',
                                'August',
                                'September',
                                'October',
                                'November',
                                'December',
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedMonth = value;
                                  _monthError = null;
                                });
                              },
                              errorText: _monthError,
                            ),
                          ),
                          hSpace(12),
                          Expanded(
                            child: _buildDropdown(
                              label: 'Year',
                              value: _selectedYear,
                              items: List.generate(
                                100,
                                (i) => '${DateTime.now().year - 18 - i}',
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value;
                                  _yearError = null;
                                });
                              },
                              errorText: _yearError,
                            ),
                          ),
                        ],
                      ),

                      vSpace(32),

                      // Gender
                      Text(
                        'Gender',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      vSpace(16),
                      _buildDropdown(
                        label: 'Gender',
                        value: _selectedGender,
                        items: const ['Male', 'Female'],
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                            _genderError = null;
                          });
                        },
                        errorText: _genderError,
                      ),

                      vSpace(24),
                    ],
                  ),
                ),
              ),

              // Bottom buttons
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(
                        title: 'Skip',
                        isDark: false,
                        onPressed: _isSubmitting ? null : _skip,
                      ),
                    ),
                    hSpace(16),
                    Expanded(
                      flex: 2,
                      child: AppElevatedButton(
                        title: 'Continue',
                        isLoading: _isSubmitting,
                        loadingLabel: 'Submitting…',
                        onPressed: _continue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    String? errorText,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;

    Future<void> openPicker() async {
      if (items.isEmpty) return;
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (sheetCtx, scrollController) => SafeArea(
            child: CustomScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 4.h, bottom: 6.h),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item, style: TextStyle(fontSize: 17.sp)),
                      trailing: value == item
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).primaryColor,
                            )
                          : null,
                      onTap: () => Navigator.of(ctx).pop(item),
                    );
                  },
                ),
                SliverToBoxAdapter(child: vSpace(8)),
              ],
            ),
          ),
        ),
      );
      if (!mounted || selected == null) return;
      onChanged(selected);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 52.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: hasError ? Colors.red : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12.r),
              onTap: openPicker,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (value != null && value.isNotEmpty) ? value : label,
                        style: TextStyle(
                          color: (value != null && value.isNotEmpty)
                              ? Colors.black87
                              : Colors.grey.shade400,
                          fontSize: 19.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 22.sp,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: 4.h),
          Text(
            errorText,
            style: TextStyle(color: Colors.red, fontSize: 17.sp),
          ),
        ],
      ],
    );
  }
}
