import 'dart:ui';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/navigation/root_navigator_key.dart';
import 'package:communal_mobile/cubits/security/security_cubit.dart';
import 'package:communal_mobile/core/utils/idempotency.dart';
import 'package:communal_mobile/data/local/kyc_progress_storage.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/data/repositories/kyc_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/kyc_idle_suppressor.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

/// UI labels → Anchor `id_type` values ([UpgradeTier2Request] on backend).
const Map<String, String> _kycTier2IdTypeToAnchor = {
  'National ID': 'NATIONAL_ID',
  'Driver\'s License': 'DRIVERS_LICENSE',
  'Passport': 'PASSPORT',
  'Voter\'s Card': 'VOTERS_CARD',
  'NIN Slip': 'NIN_SLIP',
};

const List<String> _kycIdTypeDisplayLabels = [
  'National ID',
  'Driver\'s License',
  'Passport',
  'Voter\'s Card',
  'NIN Slip',
];

/// ID types where Anchor / Communal accept submission without an expiry (see [UpgradeTier2Request]).
bool _expiryOptionalForDisplayIdType(String? displayLabel) {
  switch (displayLabel) {
    case 'NIN Slip':
    case 'National ID':
    case 'Voter\'s Card':
      return true;
    default:
      return false;
  }
}

/// Anchor requested both front and back for this type in observed payloads.
bool _requiresBackForDisplayIdType(String? displayLabel) {
  switch (displayLabel) {
    case 'National ID':
    case 'Driver\'s License':
    case 'Voter\'s Card':
      return true;
    default:
      return false;
  }
}

class ProofOfIdentityScreen extends StatefulWidget {
  const ProofOfIdentityScreen({super.key});

  @override
  State<ProofOfIdentityScreen> createState() => _ProofOfIdentityScreenState();
}

class _ProofOfIdentityScreenState extends State<ProofOfIdentityScreen> {
  final _idNumberController = TextEditingController();

  /// Resolved from one of two trusted sources (audit M30 — route extras are
  /// no longer accepted):
  ///
  /// 1. [AuthAuthenticated.user.kycAnchorCustomerId] — server-vouched, comes
  ///    straight from `/get-loggedin-user` (`kyc.anchor_customer_id`). This
  ///    is the cross-device-resume path.
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

  String? _idTypeError;
  String? _idNumberError;
  String? _expiryDayError;
  String? _expiryMonthError;
  String? _expiryYearError;
  String? _documentError;

  String? _selectedIdType;
  String? _selectedDay;
  String? _selectedMonth;
  String? _selectedYear;
  PlatformFile? _pickedFrontFile;
  PlatformFile? _pickedBackFile;
  bool _isSubmitting = false;

  /// Audit M23: minted once per screen mount; reused across user retries so
  /// duplicate Anchor identity submissions are deduped server-side.
  late final String _idempotencyKey = newIdempotencyKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAnchorFromStorage();
    });
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
    _idNumberController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _idTypeError = null;
      _idNumberError = null;
      _expiryDayError = null;
      _expiryMonthError = null;
      _expiryYearError = null;
      _documentError = null;
    });
  }

  bool _validateForm() {
    _clearErrors();
    bool isValid = true;

    if (_selectedIdType == null) {
      setState(() {
        _idTypeError = 'Please select ID type';
      });
      isValid = false;
    }

    if (_idNumberController.text.isEmpty) {
      setState(() {
        _idNumberError = 'ID number is required';
      });
      isValid = false;
    }

    final expiryOptional = _expiryOptionalForDisplayIdType(_selectedIdType);
    final expiryParts = [_selectedDay, _selectedMonth, _selectedYear];
    final expiryAnySet = expiryParts.any((e) => e != null);
    final expiryAllSet = expiryParts.every((e) => e != null);

    if (!expiryOptional) {
      if (_selectedDay == null) {
        setState(() {
          _expiryDayError = 'Day is required';
        });
        isValid = false;
      }

      if (_selectedMonth == null) {
        setState(() {
          _expiryMonthError = 'Month is required';
        });
        isValid = false;
      }

      if (_selectedYear == null) {
        setState(() {
          _expiryYearError = 'Year is required';
        });
        isValid = false;
      }
    } else if (expiryAnySet && !expiryAllSet) {
      setState(() {
        if (_selectedDay == null) {
          _expiryDayError = 'Select day or clear all date fields';
        }
        if (_selectedMonth == null) {
          _expiryMonthError = 'Select month or clear all date fields';
        }
        if (_selectedYear == null) {
          _expiryYearError = 'Select year or clear all date fields';
        }
      });
      isValid = false;
    }

    if (_pickedFrontFile == null) {
      setState(() {
        _documentError = 'Please upload your ID front';
      });
      isValid = false;
    }
    if (_requiresBackForDisplayIdType(_selectedIdType) &&
        _pickedBackFile == null) {
      setState(() {
        _documentError = 'Please upload both front and back for this ID type';
      });
      isValid = false;
    }

    return isValid;
  }

  Future<void> _pickIdType(ThemeData theme) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 4.h, top: 4.h),
                child: Text(
                  'Select ID type',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final label in _kycIdTypeDisplayLabels)
                ListTile(
                  title: Text(label, style: TextStyle(fontSize: 19.sp)),
                  trailing: _selectedIdType == label
                      ? Icon(Icons.check_circle, color: theme.primaryColor)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(label),
                ),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    setState(() {
      _selectedIdType = choice;
      _idTypeError = null;
      _documentError = null;
      _pickedFrontFile = null;
      _pickedBackFile = null;
      if (_expiryOptionalForDisplayIdType(choice)) {
        _selectedDay = null;
        _selectedMonth = null;
        _selectedYear = null;
        _expiryDayError = null;
        _expiryMonthError = null;
        _expiryYearError = null;
      }
    });
  }

  Widget _buildIdTypeSelector(ThemeData theme) {
    final hasError = _idTypeError != null && _idTypeError!.isNotEmpty;
    final display =
        (_selectedIdType != null && _selectedIdType!.trim().isNotEmpty)
        ? _selectedIdType!
        : 'Select ID Type';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: () => _pickIdType(theme),
            child: Container(
              height: 52.h,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: hasError ? Colors.red : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      display,
                      style: TextStyle(
                        fontSize: 19.sp,
                        color: _selectedIdType == null
                            ? Colors.grey.shade400
                            : Colors.black87,
                      ),
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
        if (hasError) ...[
          SizedBox(height: 4.h),
          Text(
            _idTypeError!,
            style: TextStyle(color: Colors.red, fontSize: 19.sp),
          ),
        ],
      ],
    );
  }

  void _skip() {
    context.go('/home');
  }

  /// Back from step 3: only step 2 (bank), never step 1 — use [GoRouter.go] so the stack is replaced.
  void _goBackFromProof() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      context.pop();
      return;
    }
    if (!auth.user.kycStep2Submitted) {
      final id = _effectiveAnchor();
      final extra = (id != null && id.isNotEmpty)
          ? <String, dynamic>{'anchorCustomerId': id}
          : <String, dynamic>{};
      context.go('/kyc/bank-info', extra: extra);
      return;
    }
    context.pop();
  }

  Future<void> _completeSetup() async {
    if (!_validateForm()) return;
    final id = _effectiveAnchor();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing customer id. Complete earlier KYC steps first.',
          ),
        ),
      );
      return;
    }
    final idType = _selectedIdType != null
        ? _kycTier2IdTypeToAnchor[_selectedIdType!]
        : null;
    if (idType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid ID type selection.')),
      );
      return;
    }
    final frontFile = _pickedFrontFile;
    if (frontFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose the front image file from your device.'),
        ),
      );
      return;
    }
    final frontBytes = frontFile.bytes;
    final frontPath = frontFile.path;
    if ((frontBytes == null || frontBytes.isEmpty) &&
        (frontPath == null || frontPath.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not read the selected front image. Try another image or restart the app.',
          ),
        ),
      );
      return;
    }
    PlatformFile? backFile;
    if (_requiresBackForDisplayIdType(_selectedIdType)) {
      backFile = _pickedBackFile;
      if (backFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose the back image file.')),
        );
        return;
      }
      final backUsable =
          (backFile.bytes != null && backFile.bytes!.isNotEmpty) ||
          (backFile.path != null && backFile.path!.trim().isNotEmpty);
      if (!backUsable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the selected back image.'),
          ),
        );
        return;
      }
    }

    final expiryOptional = _expiryOptionalForDisplayIdType(_selectedIdType);
    final expiryParts = [_selectedDay, _selectedMonth, _selectedYear];
    final expiryAllSet = expiryParts.every((e) => e != null);
    final String? expiryYmd = (!expiryOptional || expiryAllSet) && expiryAllSet
        ? '$_selectedYear-$_selectedMonth-$_selectedDay'
        : null;

    setState(() => _isSubmitting = true);
    try {
      await getIt<KycRepository>().upgradeToTier2(
        anchorCustomerId: id,
        idNumber: _idNumberController.text.trim(),
        idType: idType,
        expiryDateYmd: expiryYmd,
        idempotencyKey: _idempotencyKey,
        fileFrontPath: frontPath?.trim(),
        fileFrontBytes: (frontBytes != null && frontBytes.isNotEmpty)
            ? frontBytes
            : null,
        fileFrontName: frontFile.name.isNotEmpty
            ? frontFile.name
            : 'id_front.jpg',
        fileBackPath: backFile?.path?.trim(),
        fileBackBytes: (backFile?.bytes != null && backFile!.bytes!.isNotEmpty)
            ? backFile.bytes
            : null,
        fileBackName: (backFile?.name.isNotEmpty ?? false)
            ? backFile!.name
            : null,
      );

      if (!mounted) return;
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) {
        await getIt<KycProgressStorage>().markProofStepDone(auth.userId);
      }

      final token = await getIt<FlutterSecureStorage>().read(key: 'token');
      if (token != null && mounted) {
        getIt<AuthRepository>().updateToken(token);
        final user = await getIt<AuthRepository>().getUserInfo(token);
        if (user != null && mounted) {
          context.read<AuthBloc>().add(AuthUserUpdated(user));
        }
      }

      if (!mounted) return;
      // ignore: unawaited_futures
      context.push(
        '/kyc/verifying',
        extra: <String, dynamic>{'anchorCustomerId': id},
      );
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

  Future<void> _uploadDocument({required bool isBack}) async {
    try {
      // Gallery / document picker sends [paused] → blur → [resumed] would normally PIN-lock.
      // Guard tells [SecurityCubit.onAppResumed] to treat the next return as part of this flow.
      context.read<SecurityCubit>().beginExternalFilePickerGuard();
      // Never use `withData: true` here: it decodes the whole image on the UI thread
      // and commonly freezes the app (ANR) on Android for gallery photos.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'JPG', 'JPEG', 'PNG'],
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final usable =
          (f.bytes != null && f.bytes!.isNotEmpty) ||
          (f.path != null && f.path!.trim().isNotEmpty);
      if (!usable) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'That file could not be used. Choose a JPG or PNG from your gallery or files.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        if (isBack) {
          _pickedBackFile = f;
        } else {
          _pickedFrontFile = f;
        }
        _documentError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isEmpty ? 'Could not open the file picker.' : msg),
        ),
      );
    } finally {
      // Clear even if this route was disposed while the picker was open (e.g. pop).
      final rootCtx = rootNavigatorKey.currentContext;
      if (rootCtx != null && rootCtx.mounted) {
        try {
          rootCtx.read<SecurityCubit>().cancelExternalFilePickerGuard();
        } catch (_) {}
      }
    }
  }

  Widget _buildUploadCard({
    required ThemeData theme,
    required String title,
    required PlatformFile? file,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: _documentError != null ? Colors.red : Colors.grey.shade300,
            strokeWidth: 1.5,
            dashWidth: 5,
            dashSpace: 3,
            borderRadius: 12.r,
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 48.sp,
                  color: file != null
                      ? theme.primaryColor
                      : Colors.grey.shade400,
                ),
                vSpace(12),
                Text(
                  file?.name ?? title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 19.sp,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    children: [
                      const TextSpan(text: 'Supported format: '),
                      TextSpan(
                        text: 'JPEG, PNG',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.read<AuthBloc>().state;
    // Show back to step 2 only while step 2 is not submitted on the server (includes skip-to-proof).
    final hideBack = auth is AuthAuthenticated && auth.user.kycStep2Submitted;

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
                  onPressed: _goBackFromProof,
                ),
          title: Text(
            'Proof of Identity',
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
                        'Verify your identity',
                        style: TextStyle(
                          fontSize: 19.sp,
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
                          'Proof of Identity',
                          style: TextStyle(
                            fontSize: 19.sp,
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Step 3 of 3',
                          style: TextStyle(
                            fontSize: 19.sp,
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    vSpace(8),
                    // Progress bar
                    LinearProgressIndicator(
                      value: 1.0,
                      backgroundColor: theme.brightness == Brightness.dark
                          ? theme.dividerColor
                          : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.brightness == Brightness.dark
                            ? Colors.white
                            : theme.primaryColor,
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
                      // Identity Document
                      Text(
                        'Identity Document',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      vSpace(16),
                      _buildIdTypeSelector(theme),
                      vSpace(16),
                      CustomTextField(
                        controller: _idNumberController,
                        hintText: 'Enter ID Number',
                        textInputAction: TextInputAction.done,
                        errorText: _idNumberError,
                        onChanged: (_) => _clearErrors(),
                        onFieldSubmitted: (_) {
                          if (!mounted) return;
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                      ),

                      if (!_expiryOptionalForDisplayIdType(
                        _selectedIdType,
                      )) ...[
                        vSpace(32),
                        Text(
                          'Document Expiry Date',
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
                                label: '06',
                                value: _selectedMonth,
                                items: List.generate(
                                  12,
                                  (i) => '${i + 1}'.padLeft(2, '0'),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMonth = value;
                                    _expiryMonthError = null;
                                  });
                                },
                                errorText: _expiryMonthError,
                              ),
                            ),
                            hSpace(12),
                            Expanded(
                              child: _buildDropdown(
                                label: '02',
                                value: _selectedDay,
                                items: List.generate(
                                  31,
                                  (i) => '${i + 1}'.padLeft(2, '0'),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDay = value;
                                    _expiryDayError = null;
                                  });
                                },
                                errorText: _expiryDayError,
                              ),
                            ),
                            hSpace(12),
                            Expanded(
                              child: _buildDropdown(
                                label: '1998',
                                value: _selectedYear,
                                items: List.generate(
                                  50,
                                  (i) => '${DateTime.now().year + i}',
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedYear = value;
                                    _expiryYearError = null;
                                  });
                                },
                                errorText: _expiryYearError,
                              ),
                            ),
                          ],
                        ),
                      ],
                      vSpace(32),

                      _buildUploadCard(
                        theme: theme,
                        title: 'Upload ID Front',
                        file: _pickedFrontFile,
                        onTap: () => _uploadDocument(isBack: false),
                      ),
                      if (_requiresBackForDisplayIdType(_selectedIdType)) ...[
                        vSpace(12),
                        _buildUploadCard(
                          theme: theme,
                          title: 'Upload ID Back',
                          file: _pickedBackFile,
                          onTap: () => _uploadDocument(isBack: true),
                        ),
                      ],
                      if (_documentError != null) ...[
                        SizedBox(height: 4.h),
                        Text(
                          _documentError!,
                          style: TextStyle(color: Colors.red, fontSize: 19.sp),
                        ),
                      ],

                      vSpace(24),

                      // Important Notice
                      CustomPaint(
                        painter: DashedBorderPainter(
                          color: const Color(0xFF00BCD4),
                          strokeWidth: 1.5,
                          dashWidth: 5,
                          dashSpace: 3,
                          borderRadius: 12.r,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE0F7FA,
                            ), // Light blue/teal background
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Important Notice',
                                style: TextStyle(
                                  fontSize: 19.sp,
                                  fontWeight: FontWeight.w600,
                                  // Pinned: notice card has a fixed light-teal
                                  // bg, so the title must read dark in both
                                  // themes (theme.onSurface flips to white in
                                  // dark mode and disappeared on the light bg).
                                  color: const Color(0xFF014149),
                                ),
                              ),
                              vSpace(12),
                              _buildNoticeBullet(
                                'Document must be clear and readable',
                              ),
                              _buildNoticeBullet(
                                'All corners of the document should be visible',
                              ),
                              _buildNoticeBullet(
                                'Documents should not be older than 3 months',
                              ),
                              _buildNoticeBullet(
                                'Files are encrypted and securely stored',
                              ),
                            ],
                          ),
                        ),
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
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).dividerColor,
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
                        onPressed: _skip,
                      ),
                    ),
                    hSpace(16),
                    Expanded(
                      flex: 2,
                      child: AppElevatedButton(
                        title: 'Submit',
                        isLoading: _isSubmitting,
                        loadingLabel: 'Submitting…',
                        onPressed: _completeSetup,
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

  Widget _buildNoticeBullet(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(fontSize: 19.sp, color: Colors.grey.shade700),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 19.sp,
                // Pinned dark text — notice card bg is a fixed light teal,
                // so theme.onSurface (which flips white in dark mode) would
                // vanish on the bg. Same reason as the title above.
                color: const Color(0xFF1B4F58),
                height: 1.4,
              ),
            ),
          ),
        ],
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
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              menuMaxHeight: 280.h,
              dropdownColor: Colors.white,
              style: TextStyle(fontSize: 19.sp, color: Colors.black87),
              hint: Text(
                label,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 19.sp),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                size: 22.sp,
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              borderRadius: BorderRadius.circular(12.r),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(fontSize: 19.sp, color: Colors.black87),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: 4.h),
          Text(
            errorText,
            style: TextStyle(color: Colors.red, fontSize: 19.sp),
          ),
        ],
      ],
    );
  }
}

// Custom painter for dashed border
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

    final dashPath = _createDashedPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final Path dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final double length = draw ? dashWidth : dashSpace;
        if (distance + length > metric.length) {
          if (draw) {
            dest.addPath(
              metric.extractPath(distance, metric.length),
              Offset.zero,
            );
          }
          break;
        }
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) => false;
}
