import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/cubits/security/security_cubit.dart';
import 'package:communal_mobile/data/models/member_profile_details.dart';
import 'package:communal_mobile/data/repositories/profile_repository.dart';
import 'package:communal_mobile/injection.dart';

class ProfileHeader extends StatefulWidget {
  const ProfileHeader({super.key, required this.profile});

  final MemberProfileDetails profile;

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  bool _uploading = false;

  /// Pick + upload a new avatar. Wraps the picker in the security
  /// cubit's external-picker guard so returning from the OS picker
  /// doesn't trigger the idle lock. On success refreshes auth state
  /// so the home/sidebar avatar picks up the new URL too.
  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final security = context.read<SecurityCubit>();
    security.beginExternalFilePickerGuard();
    try {
      // JPG / PNG only — HEIC and WebP can come back from iOS / some
      // Android galleries and Flutter's image decoder rejects them on
      // the home/sidebar avatar render. Restricting at the picker keeps
      // the upload pipeline producing bytes every other client can
      // decode. Backend mime sniff guards this server-side too.
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: false,
      );
      if (picked == null || picked.files.isEmpty) return;
      final path = picked.files.single.path;
      if (path == null) return;

      setState(() => _uploading = true);
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
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    } finally {
      security.cancelExternalFilePickerGuard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;

        // Tier label off auth state — KYC tier comes from /me, not the
        // profile row, so we read it here rather than putting it in the
        // profile model. Falls through to "Not verified" when missing.
        final tierLabel = _tierLabel(user?.communalTier);
        final accountNumber =
            user?.walletAccountNumber?.trim().isNotEmpty == true
                ? user!.walletAccountNumber!
                : null;

        final avatarUrl = user?.avatar;
        final hasNetworkAvatar = avatarUrl != null &&
            (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));
        return Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 120.w,
                  height: 120.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7434FF), Color(0xFF1976D2)],
                    ),
                    shape: BoxShape.circle,
                    image: hasNetworkAvatar
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                            // Swallow decode errors (expired secure-upload
                            // signatures, 404s) instead of throwing to
                            // the image resource service. Initials show
                            // through whichever fallback path renders.
                            onError: (_, __) {},
                          )
                        : null,
                  ),
                  child: hasNetworkAvatar
                      ? null
                      : Center(
                          child: Text(
                            _initialsFor(profile.displayName),
                            style: TextStyle(
                              fontSize: 36.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
                // Camera overlay — tap to pick + upload a new avatar.
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _uploading ? null : _pickAndUpload,
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).dividerColor, width: 2),
                      ),
                      child: _uploading
                          ? Padding(
                              padding: EdgeInsets.all(8.w),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Color(0xFF7434FF),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.camera_alt,
                              color: const Color(0xFF7434FF),
                              size: 18.sp,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            vSpace(16),
            Text(
              profile.displayName,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            vSpace(12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _buildBadge(tierLabel, const Color(0xFF7434FF)),
                if (user?.kycStep1Submitted == true)
                  _buildBadge('KYC submitted', const Color(0xFF4CAF50)),
              ],
            ),
            vSpace(20),
            if (accountNumber != null) _AccountNumberCard(number: accountNumber),
          ],
        );
      },
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _tierLabel(String? tier) {
    final t = tier?.trim().toLowerCase();
    if (t == 'tier_1') return 'Tier 1';
    if (t == 'tier_2') return 'Tier 2';
    if (t == 'tier_3') return 'Tier 3';
    return 'Not verified';
  }

  String _initialsFor(String name) {
    final parts = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'M';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _AccountNumberCard extends StatelessWidget {
  const _AccountNumberCard({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF7434FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Number',
            style: TextStyle(
              fontSize: 17.sp,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          vSpace(12),
          Row(
            children: [
              Expanded(
                child: Text(
                  number,
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: number));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account number copied to clipboard'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.copy,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
