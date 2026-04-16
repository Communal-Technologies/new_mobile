import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class BankInformationScreen extends StatefulWidget {
  const BankInformationScreen({super.key});

  @override
  State<BankInformationScreen> createState() => _BankInformationScreenState();
}

class _BankInformationScreenState extends State<BankInformationScreen> {
  final _bvnController = TextEditingController();

  String? _bvnError;
  String? _dayError;
  String? _monthError;
  String? _yearError;
  String? _genderError;

  String? _selectedDay;
  String? _selectedMonth;
  String? _selectedYear;
  String? _selectedGender;

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

  void _skip() {
    context.push('/kyc/proof-of-identity');
  }

  void _continue() {
    if (_validateForm()) {
      context.push('/kyc/proof-of-identity');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Bank Information',
          style: TextStyle(
            fontSize: 20.sp,
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
                      'Secure your account',
                      style: TextStyle(
                        fontSize: 13.sp,
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
                        'Bank Information',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Step 2 of 3',
                        style: TextStyle(
                          fontSize: 12.sp,
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
                    // Connect your BVN
                    Text(
                      'Connect your BVN',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    vSpace(16),
                    CustomTextField(
                      controller: _bvnController,
                      hintText: 'Enter your 11 digit BVN',
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      errorText: _bvnError,
                      onChanged: (_) => _clearErrors(),
                    ),

                    vSpace(32),

                    // Date of Birth
                    Text(
                      'Date of Birth',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
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
                              'December'
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
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    vSpace(16),
                    _buildDropdown(
                      label: 'Gender',
                      value: _selectedGender,
                      items: ['Male', 'Female', 'Other'],
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
                      onPressed: _skip,
                    ),
                  ),
                  hSpace(16),
                  Expanded(
                    flex: 2,
                    child: AppElevatedButton(
                      title: 'Continue',
                      onPressed: _continue,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 48.h,
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
              menuMaxHeight: 250.h,
              dropdownColor: Colors.white,
              hint: Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14.sp,
                ),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey.shade600,
                size: 20.sp,
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              borderRadius: BorderRadius.circular(12.r),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14.sp,
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
              fontSize: 12.sp,
            ),
          ),
        ],
      ],
    );
  }
}

