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

/// Shown when `user.wallet.account_status` is frozen (`2`). The CTA posts to
/// `members/account/request-unfreeze`, which lifts a self-freeze
/// (`frozen_by` === member `user.id`) immediately and files an admin freeze for
/// review; only the label differs between the two.
class HomeAccountFrozenCard extends StatelessWidget {
  const HomeAccountFrozenCard({super.key, required this.user});

  final UserModel user;

  static const Color _cardBg = Color(0xFFBEDBFF);
  static const Color _iconCircleBg = Color(0xFFDBEAFE);
  static const Color _accent = Color(0xFF155DFC);

  @override
  Widget build(BuildContext context) {
    if (!user.isWalletFrozen) return const SizedBox.shrink();

    // request-unfreeze serves both cases: a member's own freeze is lifted
    // immediately, an admin freeze becomes a pending review. Hiding the button
    // on an admin freeze left the member with no route to that review at all.
    final selfFrozen = user.isWalletSelfFrozen;
    final actionLabel = selfFrozen ? 'Unfreeze Account' : 'Request Unfreeze';

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
                    child: Icon(Icons.ac_unit, size: 22.sp, color: _accent),
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
                            fontSize: 19.sp,
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
                              fontSize: 16.sp,
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
                  fontSize: 17.sp,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: _accent,
                ),
              ),
              vSpace(14),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: Material(
                  color: _accent,
                  borderRadius: BorderRadius.circular(12.r),
                  child: InkWell(
                    onTap: () =>
                        _onUnfreezeAccount(context, selfFrozen: selfFrozen),
                    borderRadius: BorderRadius.circular(12.r),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: TextStyle(
                              fontSize: 19.sp,
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
          ),
        ),
      ),
    );
  }

  Future<void> _onUnfreezeAccount(
    BuildContext context, {
    required bool selfFrozen,
  }) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _UnfreezeReasonDialog(selfFrozen: selfFrozen),
    );
    if (!context.mounted) return;
    if (reason == null || reason.trim().length < 10) return;

    try {
      final message = await getIt<AuthRepository>().requestAccountUnfreeze(
        reason.trim(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty
                ? 'Your unfreeze request has been submitted.'
                : message,
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
  const _UnfreezeReasonDialog({required this.selfFrozen});

  final bool selfFrozen;

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
      title: Text(widget.selfFrozen ? 'Unfreeze account' : 'Request unfreeze'),
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
          decoration: InputDecoration(
            hintText: widget.selfFrozen
                ? 'Tell us why you want to unfreeze your account'
                : 'Your account was frozen by an administrator. Tell us why it should be unfrozen — this goes to them for review',
            border: const OutlineInputBorder(),
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
