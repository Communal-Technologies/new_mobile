import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/phone_input_field.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/region_model.dart';
import 'package:communal_mobile/data/repositories/regions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class ProfileInformationScreen extends StatefulWidget {
  const ProfileInformationScreen({super.key});

  @override
  State<ProfileInformationScreen> createState() =>
      _ProfileInformationScreenState();
}

class _ProfileInformationScreenState extends State<ProfileInformationScreen> {
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _phoneError;
  String? _address1Error;
  String? _cityError;
  String? _postalCodeError;
  String? _stateError;
  String? _countryError;

  String? _selectedState;
  String? _selectedCountry;
  List<RegionModel> _regions = RegionModel.offlineFallback;
  bool _regionsLoading = true;
  PhoneNumber? _phoneNumber;
  bool _phoneValid = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final list = await getIt<RegionsRepository>().fetchRegions();
      if (!mounted) return;
      setState(() {
        _regions = list.isNotEmpty ? list : RegionModel.offlineFallback;
        _regionsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _regions = RegionModel.offlineFallback;
        _regionsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _firstNameError = null;
      _lastNameError = null;
      _emailError = null;
      _phoneError = null;
      _address1Error = null;
      _cityError = null;
      _postalCodeError = null;
      _stateError = null;
      _countryError = null;
    });
  }

  bool _validateForm() {
    _clearErrors();
    bool isValid = true;

    if (_firstNameController.text.isEmpty) {
      setState(() {
        _firstNameError = 'First name is required';
      });
      isValid = false;
    }

    if (_lastNameController.text.isEmpty) {
      setState(() {
        _lastNameError = 'Last name is required';
      });
      isValid = false;
    }

    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = 'Email is required';
      });
      isValid = false;
    } else if (!_isValidEmail(_emailController.text)) {
      setState(() {
        _emailError = 'Enter a valid email address';
      });
      isValid = false;
    }

    if (_phoneNumber == null || !_phoneValid) {
      setState(() {
        _phoneError = 'Enter a valid phone number';
      });
      isValid = false;
    }

    if (_address1Controller.text.isEmpty) {
      setState(() {
        _address1Error = 'Address is required';
      });
      isValid = false;
    }

    if (_cityController.text.isEmpty) {
      setState(() {
        _cityError = 'City is required';
      });
      isValid = false;
    }

    if (_postalCodeController.text.isEmpty) {
      setState(() {
        _postalCodeError = 'Postal code is required';
      });
      isValid = false;
    }

    if (_selectedState == null) {
      setState(() {
        _stateError = 'Please select a state';
      });
      isValid = false;
    }

    if (_selectedCountry == null ||
        !_regions.any((r) => r.name == _selectedCountry)) {
      setState(() {
        _countryError = 'Please select a country';
      });
      isValid = false;
    }

    return isValid;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _skip() {
    context.push('/kyc/bank-info');
  }

  void _continue() {
    if (_validateForm()) {
      context.push('/kyc/bank-info');
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
          'Profile Information',
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
                      'Tell us about yourself',
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
                        'Profile Information',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Step 1 of 3',
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
                    value: 1 / 3,
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
                    // Personal Information
                    Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    vSpace(16),
                    CustomTextField(
                      controller: _firstNameController,
                      hintText: 'First name',
                      errorText: _firstNameError,
                      onChanged: (_) => _clearErrors(),
                    ),
                    vSpace(16),
                    CustomTextField(
                      controller: _middleNameController,
                      hintText: 'Middle name (optional)',
                      onChanged: (_) => _clearErrors(),
                    ),
                    vSpace(16),
                    CustomTextField(
                      controller: _lastNameController,
                      hintText: 'Last name',
                      errorText: _lastNameError,
                      onChanged: (_) => _clearErrors(),
                    ),
                    vSpace(16),
                    CustomTextField(
                      controller: _emailController,
                      hintText: 'Email address',
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                      onChanged: (_) => _clearErrors(),
                    ),
                    vSpace(16),
                    Text(
                      'Phone number',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    vSpace(8),
                    _regionsLoading
                        ? SizedBox(
                            height: 52.h,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : PhoneInputField(
                            controller: _phoneController,
                            regions: _regions,
                            errorText: _phoneError,
                            onChanged: () => _clearErrors(),
                            onPhoneNumberChanged: (phone, valid) {
                              setState(() {
                                _phoneNumber = phone;
                                _phoneValid = valid;
                              });
                            },
                          ),

                    vSpace(32),

                    // Address Information
                    Text(
                      'Address Information',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    vSpace(16),
                    CustomTextField(
                      controller: _address1Controller,
                      hintText: 'Address Line 1',
                      errorText: _address1Error,
                      onChanged: (_) => _clearErrors(),
                    ),
                    vSpace(16),
                    CustomTextField(
                      controller: _address2Controller,
                      hintText: 'Address Line 2 (optional)',
                    ),
                    vSpace(16),
                    // City and Postal Code (inline)
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _cityController,
                            hintText: 'City',
                            errorText: _cityError,
                            onChanged: (_) => _clearErrors(),
                          ),
                        ),
                        hSpace(12),
                        Expanded(
                          child: CustomTextField(
                            controller: _postalCodeController,
                            hintText: 'Postal Code',
                            keyboardType: TextInputType.number,
                            errorText: _postalCodeError,
                            onChanged: (_) => _clearErrors(),
                          ),
                        ),
                      ],
                    ),
                    vSpace(16),
                    // State and Country dropdowns (inline)
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'State',
                            value: _selectedState,
                            items: ['Lagos', 'Abuja', 'Rivers', 'Kano'],
                            onChanged: (value) {
                              setState(() {
                                _selectedState = value;
                                _stateError = null;
                              });
                            },
                            errorText: _stateError,
                          ),
                        ),
                        hSpace(12),
                        Expanded(
                          child: _buildDropdown(
                            label: 'Country',
                            value: _selectedCountry,
                            items: _regions.map((r) => r.name).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCountry = value;
                                _countryError = null;
                              });
                            },
                            errorText: _countryError,
                          ),
                        ),
                      ],
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

