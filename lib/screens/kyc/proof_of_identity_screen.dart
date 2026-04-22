import 'dart:ui';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/data/local/kyc_progress_storage.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/kyc_idle_suppressor.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class ProofOfIdentityScreen extends StatefulWidget {
  const ProofOfIdentityScreen({super.key, this.anchorCustomerId});

  /// From route [extra] or recovered from [KycProgressStorage] on resume.
  final String? anchorCustomerId;

  @override
  State<ProofOfIdentityScreen> createState() => _ProofOfIdentityScreenState();
}

class _ProofOfIdentityScreenState extends State<ProofOfIdentityScreen> {
  final _idNumberController = TextEditingController();

  String? _resolvedAnchor;

  String? _effectiveAnchor() {
    final fromRoute = widget.anchorCustomerId?.trim();
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      return _resolvedAnchor ??
          getIt<KycProgressStorage>().getAnchor(auth.userId);
    }
    return _resolvedAnchor;
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
  String? _uploadedDocument;

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
    final fromRoute = widget.anchorCustomerId?.trim();
    final fromDisk = getIt<KycProgressStorage>().getAnchor(auth.userId);
    final id = (fromRoute != null && fromRoute.isNotEmpty) ? fromRoute : fromDisk;
    if (!mounted) return;
    setState(() => _resolvedAnchor = id);
    if (fromRoute != null && fromRoute.isNotEmpty) {
      getIt<KycProgressStorage>().ensureAnchorSynced(auth.userId, fromRoute);
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

    if (_uploadedDocument == null) {
      setState(() {
        _documentError = 'Please upload your ID document';
      });
      isValid = false;
    }

    return isValid;
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
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      await getIt<KycProgressStorage>().markProofStepDone(auth.userId);
    }
    if (!mounted) return;
    context.push(
      '/kyc/verifying',
      extra: <String, dynamic>{'anchorCustomerId': id},
    );
  }

  void _uploadDocument() {
    // TODO: Implement file picker
    setState(() {
      _uploadedDocument = 'document.pdf';
      _documentError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.read<AuthBloc>().state;
    // Show back to step 2 only while step 2 is not submitted on the server (includes skip-to-proof).
    final hideBack =
        auth is AuthAuthenticated && auth.user.kycStep2Submitted;

    return KycIdleSuppressor(
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: hideBack
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: _goBackFromProof,
              ),
        title: Text(
          'Proof of Identity',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
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
                        fontSize: 17.sp,
                        color: Colors.grey.shade600,
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
                          fontSize: 17.sp,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Step 3 of 3',
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
                    value: 1.0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.primaryColor),
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
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    vSpace(16),
                    _buildDropdown(
                      label: 'Select ID Type',
                      value: _selectedIdType,
                      items: [
                        'National ID',
                        'Driver\'s License',
                        'Passport',
                        'Voter\'s Card'
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedIdType = value;
                          _idTypeError = null;
                        });
                      },
                      errorText: _idTypeError,
                    ),
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

                    vSpace(32),

                    // Document Expiry Date
                    Text(
                      'Document Expiry Date',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    vSpace(16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: '06',
                            value: _selectedMonth,
                            items: List.generate(12, (i) => '${i + 1}'.padLeft(2, '0')),
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
                            items: List.generate(31, (i) => '${i + 1}'.padLeft(2, '0')),
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

                    vSpace(32),

                    // Upload ID
                    InkWell(
                      onTap: _uploadDocument,
                      child: CustomPaint(
                        painter: DashedBorderPainter(
                          color: _documentError != null
                              ? Colors.red
                              : Colors.grey.shade300,
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
                              color: _uploadedDocument != null
                                  ? theme.primaryColor
                                  : Colors.grey.shade400,
                            ),
                            vSpace(12),
                            Text(
                              _uploadedDocument ?? 'Upload ID',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            vSpace(8),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  color: Colors.grey.shade600,
                                ),
                                children: [
                                  const TextSpan(text: 'Supported format: '),
                                  TextSpan(
                                    text: 'PDF, JPEG, PNG',
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
                    if (_documentError != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        _documentError!,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 15.sp,
                        ),
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
                          color: const Color(0xFFE0F7FA), // Light blue/teal background
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Important Notice',
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            vSpace(12),
                            _buildNoticeBullet(
                                'Document must be clear and readable'),
                            _buildNoticeBullet(
                                'All corners of the document should be visible'),
                            _buildNoticeBullet(
                                'Documents should not be older than 3 months'),
                            _buildNoticeBullet(
                                'Files are encrypted and securely stored'),
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
                      onPressed: _skip,
                    ),
                  ),
                  hSpace(16),
                  Expanded(
                    flex: 2,
                    child: AppElevatedButton(
                      title: 'Complete Setup',
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
            style: TextStyle(
              fontSize: 17.sp,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 17.sp,
                color: Colors.grey.shade700,
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
              style: TextStyle(
                fontSize: 18.sp,
                color: Colors.black87,
              ),
              hint: Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 18.sp,
                ),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey.shade600,
                size: 22.sp,
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              borderRadius: BorderRadius.circular(12.r),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: Colors.black87,
                    ),
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
            style: TextStyle(
              color: Colors.red,
              fontSize: 15.sp,
            ),
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
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

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
