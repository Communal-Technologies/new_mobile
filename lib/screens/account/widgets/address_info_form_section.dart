import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class AddressInfoFormSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController streetAddressController;
  final TextEditingController cityController;
  final TextEditingController stateController;
  final TextEditingController? lgaController;
  final TextEditingController? postalCodeController;
  final VoidCallback onSave;
  final bool saving;

  const AddressInfoFormSection({
    super.key,
    required this.formKey,
    required this.streetAddressController,
    required this.cityController,
    required this.stateController,
    this.lgaController,
    this.postalCodeController,
    required this.onSave,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: const Color(0xFF7434FF),
                  size: 20.sp,
                ),
                hSpace(8),
                Text(
                  'Address Information',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            vSpace(20),
            _FormTextField(
              controller: streetAddressController,
              label: 'Street Address',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Street address is required';
                }
                return null;
              },
            ),
            vSpace(16),
            Row(
              children: [
                Expanded(
                  child: _FormTextField(
                    controller: cityController,
                    label: 'City',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'City is required';
                      }
                      return null;
                    },
                  ),
                ),
                hSpace(12),
                Expanded(
                  child: _FormTextField(
                    controller: stateController,
                    label: 'State',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'State is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            if (lgaController != null || postalCodeController != null) ...[
              vSpace(16),
              Row(
                children: [
                  if (lgaController != null)
                    Expanded(
                      child: _FormTextField(
                        controller: lgaController!,
                        label: 'LGA',
                      ),
                    ),
                  if (lgaController != null && postalCodeController != null)
                    hSpace(12),
                  if (postalCodeController != null)
                    Expanded(
                      child: _FormTextField(
                        controller: postalCodeController!,
                        label: 'Postal Code',
                      ),
                    ),
                ],
              ),
            ],
            vSpace(20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? SizedBox(
                        height: 16.sp,
                        width: 16.sp,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Icon(Icons.save, size: 18.sp),
                label: Text(saving ? 'Saving…' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7434FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const _FormTextField({
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 15.sp,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: const Color(0xFF7434FF), width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      ),
    );
  }
}

