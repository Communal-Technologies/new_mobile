import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/phone_input_field.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/lga_model.dart';
import 'package:communal_mobile/data/models/region_model.dart';
import 'package:communal_mobile/data/models/state_model.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/data/repositories/kyc_repository.dart';
import 'package:communal_mobile/data/repositories/locations_repository.dart';
import 'package:communal_mobile/data/repositories/regions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  String? _lgaError;
  String? _countryError;
  String? _submitError;

  List<RegionModel> _regions = RegionModel.offlineFallback;
  List<StateModel> _states = [];
  List<LgaModel> _lgas = [];

  bool _regionsLoading = true;
  bool _statesLoading = true;
  bool _lgasLoading = false;
  bool _submitting = false;

  String? _selectedCountryName;
  int? _selectedStateId;
  String? _selectedLgaName;
  PhoneNumber? _phoneNumber;
  bool _phoneValid = false;
  PhoneNumber? _phoneInitial;
  bool _prefillDone = false;

  String _digitsOnlyPostal(String raw) =>
      raw.replaceAll(RegExp(r'\D'), '');

  String _internationalPhone(PhoneNumber p) {
    final dial = (p.dialCode ?? '').replaceAll(RegExp(r'\D'), '');
    var n = (p.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');
    if (n.startsWith('0')) {
      n = n.substring(1);
    }
    if (dial.isEmpty) {
      return n;
    }
    return '+$dial$n';
  }

  PhoneNumber? _phoneFromStored(String? stored, List<RegionModel> regions) {
    if (stored == null || stored.trim().isEmpty) return null;
    final digits = stored.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (regions.isEmpty) return null;

    final sorted = List<RegionModel>.from(regions)
      ..sort(
        (a, b) => b.phoneDialCode.length.compareTo(a.phoneDialCode.length),
      );

    for (final r in sorted) {
      final dc = r.phoneDialCode.replaceAll(RegExp(r'\D'), '');
      if (dc.isEmpty) continue;
      if (digits.startsWith(dc) && digits.length > dc.length) {
        return PhoneNumber(
          isoCode: r.countryIso,
          dialCode: r.dialCodeWithPlus,
          phoneNumber: digits.substring(dc.length),
        );
      }
    }

    final fallback = regions.first;
    var national = digits;
    if (national.startsWith('0')) {
      national = national.substring(1);
    }
    return PhoneNumber(
      isoCode: fallback.countryIso,
      dialCode: fallback.dialCodeWithPlus,
      phoneNumber: national,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final regionsRepo = getIt<RegionsRepository>();
    final locRepo = getIt<LocationsRepository>();

    try {
      final regions = await regionsRepo.fetchRegions();
      if (!mounted) return;

      final useRegions =
          regions.isNotEmpty ? regions : RegionModel.offlineFallback;
      final sortedRegions = List<RegionModel>.from(useRegions)
        ..sort((a, b) => a.name.compareTo(b.name));

      final authState = context.read<AuthBloc>().state;
      UserModel? user;
      if (authState is AuthAuthenticated) {
        user = authState.user;
      }

      _applyUserPrefill(user, sortedRegions);

      var defaultReg = sortedRegions.first;
      final prefIso = user?.countryIso;
      if (prefIso != null) {
        final match = sortedRegions.where(
          (r) => r.countryIso.toUpperCase() == prefIso.toUpperCase(),
        );
        if (match.isNotEmpty) {
          defaultReg = match.first;
        }
      }

      setState(() {
        _regions = sortedRegions;
        _regionsLoading = false;
        _selectedCountryName = defaultReg.name;
      });

      await _loadStatesForCountry(defaultReg.countryIso, locRepo);
    } catch (_) {
      if (!mounted) return;
      final fb = RegionModel.offlineFallback;
      setState(() {
        _regions = fb;
        _statesLoading = false;
        _regionsLoading = false;
        _selectedCountryName ??= fb.first.name;
      });
    }
  }

  Future<void> _loadStatesForCountry(
    String countryIso,
    LocationsRepository locRepo,
  ) async {
    if (!mounted) return;
    setState(() {
      _statesLoading = true;
      _selectedStateId = null;
      _selectedLgaName = null;
      _lgas = [];
      _states = [];
      _stateError = null;
      _lgaError = null;
    });
    try {
      final states = await locRepo.fetchStates(countryIso: countryIso);
      states.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _states = states;
        _statesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _states = [];
        _statesLoading = false;
      });
    }
  }

  Future<void> _onCountryChanged(String? countryName) async {
    if (countryName == null) return;
    RegionModel? reg;
    for (final r in _regions) {
      if (r.name == countryName) {
        reg = r;
        break;
      }
    }
    if (reg == null) return;

    setState(() {
      _selectedCountryName = countryName;
      _countryError = null;
      _submitError = null;
    });

    await _loadStatesForCountry(reg.countryIso, getIt<LocationsRepository>());
  }

  void _applyUserPrefill(UserModel? user, List<RegionModel> regions) {
    if (user == null || _prefillDone) return;
    _prefillDone = true;

    if (user.firstName != null) {
      _firstNameController.text = user.firstName!;
    }
    if (user.middleName != null) {
      _middleNameController.text = user.middleName!;
    }
    if (user.lastName != null) {
      _lastNameController.text = user.lastName!;
    }
    if (user.email != null) {
      _emailController.text = user.email!;
    }

    final initial = _phoneFromStored(user.phone, regions);
    if (initial != null) {
      _phoneInitial = initial;
      _phoneNumber = initial;
    }
  }

  Future<void> _onStateSelected(int? stateId) async {
    setState(() {
      _selectedStateId = stateId;
      _selectedLgaName = null;
      _lgas = [];
      _stateError = null;
      _lgaError = null;
      _submitError = null;
    });

    if (stateId == null) return;

    setState(() => _lgasLoading = true);
    try {
      final list =
          await getIt<LocationsRepository>().fetchLgas('$stateId');
      if (!mounted) return;
      setState(() {
        _lgas = list;
        _lgasLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lgasLoading = false;
        _lgas = [];
      });
    }
  }

  void _onLgaSelected(String? name) {
    setState(() {
      _selectedLgaName = name;
      _lgaError = null;
      _submitError = null;
    });
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
      _lgaError = null;
      _countryError = null;
      _submitError = null;
    });
  }

  bool _validateForm() {
    _clearErrors();
    var isValid = true;

    if (_firstNameController.text.trim().isEmpty) {
      setState(() => _firstNameError = 'First name is required');
      isValid = false;
    }

    if (_lastNameController.text.trim().isEmpty) {
      setState(() => _lastNameError = 'Last name is required');
      isValid = false;
    }

    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = 'Email is required');
      isValid = false;
    } else if (!_isValidEmail(_emailController.text.trim())) {
      setState(() => _emailError = 'Enter a valid email address');
      isValid = false;
    }

    if (_phoneNumber == null || !_phoneValid) {
      setState(() => _phoneError = 'Enter a valid phone number');
      isValid = false;
    }

    if (_address1Controller.text.trim().isEmpty) {
      setState(() => _address1Error = 'Address line 1 is required');
      isValid = false;
    }

    if (_cityController.text.trim().isEmpty) {
      setState(() => _cityError = 'City is required');
      isValid = false;
    }

    final postal = _digitsOnlyPostal(_postalCodeController.text);
    if (postal.isEmpty) {
      setState(() => _postalCodeError = 'Postal code is required');
      isValid = false;
    } else if (postal.length < 4 || postal.length > 6) {
      setState(() => _postalCodeError = 'Postal code must be 4–6 digits');
      isValid = false;
    }

    if (_selectedStateId == null) {
      setState(() => _stateError = 'Please select a state');
      isValid = false;
    }

    if (_selectedLgaName == null || _selectedLgaName!.isEmpty) {
      setState(() => _lgaError = 'Please select an LGA');
      isValid = false;
    }

    if (_selectedCountryName == null ||
        !_regions.any((r) => r.name == _selectedCountryName)) {
      setState(() => _countryError = 'Please select a country');
      isValid = false;
    }

    return isValid;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);
  }

  StateModel? get _selectedStateModel {
    if (_selectedStateId == null) return null;
    for (final s in _states) {
      if (s.id == _selectedStateId) return s;
    }
    return null;
  }

  Future<void> _continue() async {
    if (!_validateForm()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      setState(() {
        _submitError = 'You need to be signed in to continue verification.';
      });
      return;
    }

    final stateRow = _selectedStateModel;
    if (stateRow == null) return;

    RegionModel? countryRegion;
    for (final r in _regions) {
      if (r.name == _selectedCountryName) {
        countryRegion = r;
        break;
      }
    }
    if (countryRegion == null) return;

    final middle = _middleNameController.text.trim();
    final addr2 = _address2Controller.text.trim();

    final body = <String, dynamic>{
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'phone': _internationalPhone(_phoneNumber!),
      'email': _emailController.text.trim(),
      'address_1': _address1Controller.text.trim(),
      'country': countryRegion.countryIso,
      'state': stateRow.name,
      'lga': _selectedLgaName!,
      'city': _cityController.text.trim(),
      'postal_code': _digitsOnlyPostal(_postalCodeController.text),
      'type': 'IndividualCustomer',
    };
    if (middle.isNotEmpty) {
      body['middle_name'] = middle;
    }
    if (addr2.isNotEmpty) {
      body['address_2'] = addr2;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final customerId = await getIt<KycRepository>().registerProfile(
        userId: authState.userId,
        body: body,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      context.push(
        '/kyc/bank-info',
        extra: <String, dynamic>{'anchorCustomerId': customerId},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
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
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            initialValue: _phoneInitial,
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
                            hintText: 'Postal code',
                            keyboardType: TextInputType.number,
                            errorText: _postalCodeError,
                            onChanged: (_) => _clearErrors(),
                          ),
                        ),
                      ],
                    ),
                    vSpace(16),
                    _buildDropdown(
                      label: 'Country',
                      value: _selectedCountryName,
                      items: _regions.map((r) => r.name).toList(),
                      onChanged: (value) {
                        _onCountryChanged(value);
                      },
                      errorText: _countryError,
                      isLoading: _regionsLoading,
                      loadingHint: 'Loading countries…',
                    ),
                    vSpace(16),
                    _buildDropdown(
                      label: 'State',
                      value: _selectedStateId != null
                          ? _selectedStateModel?.name
                          : null,
                      items: _states.map((s) => s.name).toList(),
                      onChanged: (name) {
                        if (name == null) {
                          _onStateSelected(null);
                          return;
                        }
                        final row = _states.firstWhere(
                          (s) => s.name == name,
                          orElse: () => const StateModel(id: 0, name: ''),
                        );
                        if (row.id == 0) return;
                        _onStateSelected(row.id);
                      },
                      errorText: _stateError,
                      isLoading: _statesLoading,
                      loadingHint: 'Loading states…',
                    ),
                    vSpace(16),
                    _buildDropdown(
                      label: 'LGA',
                      value: _selectedLgaName,
                      items: _lgas.map((l) => l.name).toList(),
                      onChanged: _selectedStateId == null
                          ? (_) {}
                          : _onLgaSelected,
                      errorText: _lgaError,
                      enabled: _selectedStateId != null && _lgas.isNotEmpty,
                      isLoading: _lgasLoading,
                      loadingHint: 'Loading areas…',
                    ),
                    if (_submitError != null) ...[
                      vSpace(16),
                      Text(
                        _submitError!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                    vSpace(24),
                  ],
                ),
              ),
            ),
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
              child: _submitting
                  ? const Center(child: CircularProgressIndicator())
                  : AppElevatedButton(
                      title: 'Continue',
                      onPressed: _continue,
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
    required void Function(String?) onChanged,
    String? errorText,
    bool enabled = true,
    bool isLoading = false,
    String loadingHint = 'Loading…',
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
            color: enabled && !isLoading ? Colors.white : Colors.grey.shade100,
          ),
          child: isLoading
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          loadingHint,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
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
                    onChanged: enabled ? onChanged : null,
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
