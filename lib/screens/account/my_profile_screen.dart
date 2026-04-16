import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/profile_header.dart';
import 'package:communal_mobile/screens/account/widgets/verification_details_card.dart';
import 'package:communal_mobile/screens/account/widgets/personal_information_card.dart';
import 'package:communal_mobile/screens/account/widgets/address_information_card.dart';
import 'package:communal_mobile/screens/account/widgets/manage_account_card.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

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
              vSpace(24),
              const ProfileHeader(),
              vSpace(24),
              const VerificationDetailsCard(),
              vSpace(16),
              const PersonalInformationCard(),
              vSpace(16),
              const AddressInformationCard(),
              vSpace(16),
              const ManageAccountCard(),
              vSpace(32),
            ],
          ),
        ),
      ),
    );
  }
}
