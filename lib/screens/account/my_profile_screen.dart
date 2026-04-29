import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/member_profile_details.dart';
import 'package:communal_mobile/data/repositories/profile_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/widgets/profile_header.dart';
import 'package:communal_mobile/screens/account/widgets/verification_details_card.dart';
import 'package:communal_mobile/screens/account/widgets/personal_information_card.dart';
import 'package:communal_mobile/screens/account/widgets/address_information_card.dart';
import 'package:communal_mobile/screens/account/widgets/manage_account_card.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late Future<MemberProfileDetails> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MemberProfileDetails> _load() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated || auth.user.id.isEmpty) {
      throw Exception('Not authenticated.');
    }
    return getIt<ProfileRepository>().fetchMyProfile(auth.user.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
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
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<MemberProfileDetails>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 80.h),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.w),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFB42318), size: 36),
                            vSpace(12),
                            Text(
                              snapshot.error
                                  .toString()
                                  .replaceFirst('Exception: ', ''),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15.sp,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            vSpace(12),
                            OutlinedButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              final profile = snapshot.data!;
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    vSpace(24),
                    ProfileHeader(profile: profile),
                    vSpace(24),
                    const VerificationDetailsCard(),
                    vSpace(16),
                    PersonalInformationCard(
                      profile: profile,
                      onEdited: _refresh,
                    ),
                    vSpace(16),
                    AddressInformationCard(
                      profile: profile,
                      onEdited: _refresh,
                    ),
                    vSpace(16),
                    const ManageAccountCard(),
                    vSpace(32),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
