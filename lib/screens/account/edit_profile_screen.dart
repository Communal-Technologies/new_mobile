import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/edit_profile_header.dart';
import 'package:communal_mobile/screens/account/widgets/personal_info_form_section.dart';
import 'package:communal_mobile/screens/account/widgets/address_info_form_section.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isAddressOnly;

  const EditProfileScreen({
    super.key,
    this.isAddressOnly = false,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _personalInfoFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();
  
  // Personal Information Controllers
  final _firstNameController = TextEditingController(text: 'Pado');
  final _lastNameController = TextEditingController(text: 'Lebari');
  final _emailController = TextEditingController(text: 'pado.lebari@example.com');
  final _phoneController = TextEditingController(text: '+234 801 234 5678');
  final _dobController = TextEditingController(text: '15 May 1990');
  final _occupationController = TextEditingController(text: 'Software Engineer');
  
  // Address Information Controllers
  final _streetAddressController = TextEditingController(text: '123 Marina Street');
  final _cityController = TextEditingController(text: 'Lagos');
  final _stateController = TextEditingController(text: 'Lagos State');

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _occupationController.dispose();
    _streetAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  void _handleSavePersonalInfo() {
    if (_personalInfoFormKey.currentState!.validate()) {
      // TODO: Save changes to backend
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved successfully'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
      context.pop();
    }
  }

  void _handleSaveAddress() {
    if (_addressFormKey.currentState!.validate()) {
      // TODO: Save changes to backend
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved successfully'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
      context.pop();
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
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'My Profile',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
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
                  onEditPicture: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile picture edit')),
                    );
                  },
                ),
                vSpace(24),
                PersonalInfoFormSection(
                  formKey: _personalInfoFormKey,
                  firstNameController: _firstNameController,
                  lastNameController: _lastNameController,
                  emailController: _emailController,
                  phoneController: _phoneController,
                  dobController: _dobController,
                  occupationController: _occupationController,
                  onSave: _handleSavePersonalInfo,
                ),
              ],
              if (widget.isAddressOnly) vSpace(24),
              AddressInfoFormSection(
                formKey: _addressFormKey,
                streetAddressController: _streetAddressController,
                cityController: _cityController,
                stateController: _stateController,
                onSave: _handleSaveAddress,
              ),
              vSpace(32),
            ],
          ),
        ),
      ),
    );
  }
}
