import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/cubits/security/security_cubit.dart';
import 'package:communal_mobile/data/models/member_profile_details.dart';
import 'package:communal_mobile/data/repositories/profile_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/widgets/edit_profile_header.dart';
import 'package:communal_mobile/screens/account/widgets/personal_info_form_section.dart';
import 'package:communal_mobile/screens/account/widgets/address_info_form_section.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    this.isAddressOnly = false,
  });

  final MemberProfileDetails profile;
  final bool isAddressOnly;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _personalInfoFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _dobController;
  late final TextEditingController _occupationController;

  late final TextEditingController _streetAddressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _lgaController;
  late final TextEditingController _postalCodeController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _firstNameController = TextEditingController(text: p.firstName ?? '');
    _middleNameController = TextEditingController(text: p.middleName ?? '');
    _lastNameController = TextEditingController(text: p.lastName ?? '');
    _emailController = TextEditingController(text: p.email ?? '');
    _phoneController = TextEditingController(text: p.phone ?? '');
    _dobController = TextEditingController(text: _formatDob(p.dateOfBirth));
    _occupationController = TextEditingController(text: p.occupation ?? '');
    // Concatenate addressLine1 + addressLine2 into the single street
    // text field; on save we split back into the two backend fields
    // (everything before the first comma → line1, rest → line2).
    final street = [p.addressLine1, p.addressLine2]
        .map((s) => (s ?? '').trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
    _streetAddressController = TextEditingController(text: street);
    _cityController = TextEditingController(text: p.city ?? '');
    _stateController = TextEditingController(text: p.state ?? '');
    _lgaController = TextEditingController(text: p.lga ?? '');
    _postalCodeController = TextEditingController(text: p.postalCode ?? '');
  }

  String _formatDob(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('d MMM y').format(parsed);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _occupationController.dispose();
    _streetAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _lgaController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  /// Builds a delta payload by comparing the trimmed controller values
  /// to the profile we received. This matches Anchor's PATCH semantics
  /// (server-side intersects this with what changed and forwards only
  /// those fields), and avoids re-saving a value the user merely
  /// looked at.
  Map<String, dynamic> _personalDelta() {
    final p = widget.profile;
    final delta = <String, dynamic>{};
    final fn = _firstNameController.text.trim();
    if (fn != (p.firstName ?? '').trim()) delta['first_name'] = fn;
    final mn = _middleNameController.text.trim();
    if (mn != (p.middleName ?? '').trim()) delta['middle_name'] = mn;
    final ln = _lastNameController.text.trim();
    if (ln != (p.lastName ?? '').trim()) delta['last_name'] = ln;
    final em = _emailController.text.trim();
    if (em != (p.email ?? '').trim()) delta['email'] = em;
    final ph = _phoneController.text.trim();
    if (ph != (p.phone ?? '').trim()) delta['phone'] = ph;
    final dobIso = _parseDobToIso(_dobController.text);
    if (dobIso != (p.dateOfBirth ?? '')) delta['date_of_birth'] = dobIso;
    final occ = _occupationController.text.trim();
    if (occ != (p.occupation ?? '').trim()) delta['occupation'] = occ;
    return delta;
  }

  String _parseDobToIso(String input) {
    final t = input.trim();
    if (t.isEmpty) return '';
    final parsed = _tryParseDate(t);
    if (parsed == null) return t;
    return DateFormat('yyyy-MM-dd').format(parsed);
  }

  DateTime? _tryParseDate(String input) {
    final formats = ['d MMM y', 'd MMMM y', 'yyyy-MM-dd', 'yyyy/MM/dd'];
    for (final f in formats) {
      try {
        return DateFormat(f).parseStrict(input);
      } catch (_) {/* try next */}
    }
    return DateTime.tryParse(input);
  }

  Map<String, dynamic> _addressDelta() {
    final p = widget.profile;
    final delta = <String, dynamic>{};
    final street = _streetAddressController.text.trim();
    final firstComma = street.indexOf(',');
    String addr1, addr2;
    if (firstComma == -1) {
      addr1 = street;
      addr2 = '';
    } else {
      addr1 = street.substring(0, firstComma).trim();
      addr2 = street.substring(firstComma + 1).trim();
    }
    if (addr1 != (p.addressLine1 ?? '').trim()) delta['address_1'] = addr1;
    if (addr2 != (p.addressLine2 ?? '').trim()) delta['address_2'] = addr2;
    final city = _cityController.text.trim();
    if (city != (p.city ?? '').trim()) delta['city'] = city;
    final state = _stateController.text.trim();
    if (state != (p.state ?? '').trim()) delta['state'] = state;
    final lga = _lgaController.text.trim();
    if (lga != (p.lga ?? '').trim()) delta['lga'] = lga;
    final pc = _postalCodeController.text.trim();
    if (pc != (p.postalCode ?? '').trim()) delta['postal_code'] = pc;
    return delta;
  }

  Future<void> _save(Map<String, dynamic> delta) async {
    if (delta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save.')),
      );
      context.pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final result =
          await getIt<ProfileRepository>().updateMyProfile(delta);
      if (!mounted) return;
      // Refresh the in-memory user so the home / sidebar reflect the
      // updated name/email/phone without needing a logout-relogin.
      context.read<AuthBloc>().add(AuthRefreshUserRequested());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.anchorWarning != null
              ? 'Saved locally. Anchor sync had a hiccup: ${result.anchorWarning}'
              : 'Profile updated.'),
          backgroundColor: result.anchorWarning != null
              ? const Color(0xFFEE7B00)
              : const Color(0xFF4CAF50),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  /// Pick + upload a new avatar from the edit screen. Same idle-lock
  /// guard as the read-view header so returning from the OS picker
  /// doesn't trigger PIN re-prompt.
  Future<void> _pickAndUploadAvatar() async {
    final security = context.read<SecurityCubit>();
    security.beginExternalFilePickerGuard();
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );
      if (picked == null || picked.files.isEmpty) return;
      final path = picked.files.single.path;
      if (path == null) return;
      try {
        await getIt<ProfileRepository>().uploadAvatar(File(path));
        if (!mounted) return;
        context.read<AuthBloc>().add(AuthRefreshUserRequested());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      security.cancelExternalFilePickerGuard();
    }
  }

  void _handleSavePersonalInfo() {
    if (_personalInfoFormKey.currentState!.validate()) {
      _save(_personalDelta());
    }
  }

  void _handleSaveAddress() {
    if (_addressFormKey.currentState!.validate()) {
      _save(_addressDelta());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            widget.isAddressOnly ? 'Edit Address' : 'Edit Profile',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              if (!widget.isAddressOnly) ...[
                vSpace(24),
                EditProfileHeader(
                  onEditPicture: _pickAndUploadAvatar,
                ),
                vSpace(24),
                PersonalInfoFormSection(
                  formKey: _personalInfoFormKey,
                  firstNameController: _firstNameController,
                  middleNameController: _middleNameController,
                  lastNameController: _lastNameController,
                  emailController: _emailController,
                  phoneController: _phoneController,
                  dobController: _dobController,
                  occupationController: _occupationController,
                  onSave: _handleSavePersonalInfo,
                  saving: _saving,
                ),
              ],
              if (widget.isAddressOnly) vSpace(24),
              AddressInfoFormSection(
                formKey: _addressFormKey,
                streetAddressController: _streetAddressController,
                cityController: _cityController,
                stateController: _stateController,
                lgaController: _lgaController,
                postalCodeController: _postalCodeController,
                onSave: _handleSaveAddress,
                saving: _saving,
              ),
              vSpace(32),
            ],
          ),
        ),
      ),
    );
  }
}
