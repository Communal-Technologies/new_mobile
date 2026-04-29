import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shown when `user.wallet.account_status` is frozen (`2`). Unfreeze CTA only for
/// self-freeze (`frozen_by` === member `user.id`); admin freezes hide the button.
/// Backend: `AccountController::requestUnfreeze`, `getFreezeStatus` (`is_self_frozen`).
class HomeAccountFrozenCard extends StatelessWidget {
  const HomeAccountFrozenCard({super.key, required this.user});

  final UserModel user;

  static const Color _cardBg = Color(0xFFBEDBFF);
  static const Color _iconCircleBg = Color(0xFFDBEAFE);
  static const Color _accent = Color(0xFF155DFC);

  @override
  Widget build(BuildContext context) {
    if (!user.isWalletFrozen) return const SizedBox.shrink();

    final showUnfreeze = user.isWalletSelfFrozen;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: const BoxDecoration(
                      color: _iconCircleBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.ac_unit,
                      size: 22.sp,
                      color: _accent,
                    ),
                  ),
                  hSpace(12),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8.w,
                      runSpacing: 6.h,
                      children: [
                        Text(
                          'Account Frozen',
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            color: _accent,
                          ),
                        ),
                        Container(
                          width: 75.65.w,
                          height: 18.5.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Restricted',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              vSpace(12),
              Text(
                'Your account is temporarily disabled. All transactions are blocked, some features have also been disabled for your safety',
                style: TextStyle(
                  fontSize: 15.sp,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: _accent,
                ),
              ),
              if (showUnfreeze) ...[
                vSpace(14),
                SizedBox(
                  width: double.infinity,
                  height: 46.h,
                  child: Material(
                    color: _accent,
                    borderRadius: BorderRadius.circular(12.r),
                    child: InkWell(
                      onTap: () => _onUnfreezeAccount(context),
                      borderRadius: BorderRadius.circular(12.r),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Unfreeze Account',
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 22.sp,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onUnfreezeAccount(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _UnfreezeReasonDialog(),
    );
    if (!context.mounted) return;
    if (reason == null || reason.trim().length < 10) return;

    try {
      await getIt<AuthRepository>().requestAccountUnfreeze(reason.trim());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your unfreeze request has been submitted. Our team will review it shortly.',
          ),
        ),
      );
      final token = await getIt<FlutterSecureStorage>().read(key: 'token');
      if (token != null && context.mounted) {
        getIt<AuthRepository>().updateToken(token);
        final fresh = await getIt<AuthRepository>().getUserInfo(token);
        if (fresh != null && context.mounted) {
          context.read<AuthBloc>().add(AuthUserUpdated(fresh));
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Request failed' : msg)),
      );
    }
  }
}

class _UnfreezeReasonDialog extends StatefulWidget {
  const _UnfreezeReasonDialog();

  @override
  State<_UnfreezeReasonDialog> createState() => _UnfreezeReasonDialogState();
}

class _UnfreezeReasonDialogState extends State<_UnfreezeReasonDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unfreeze account'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          maxLines: 5,
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.length < 10) {
              return 'Please enter at least 10 characters';
            }
            return null;
          },
          decoration: const InputDecoration(
            hintText: 'Tell us why we should unfreeze your account',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
