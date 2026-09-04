import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/utils/currency_formatter.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/account_actions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/delete_account_request.dart';
import 'package:communal_mobile/screens/account/widgets/data_loss_item.dart';
import 'package:communal_mobile/screens/account/widgets/freeze_suggestion_box.dart';
import 'package:communal_mobile/screens/account/widgets/delete_account_warning_section.dart';
import 'package:communal_mobile/screens/account/widgets/delete_account_action_buttons.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  // The checkpoints are the server's answer, not the app's. This screen used to
  // ask loans-svc for the current cooperative's loan balance and swallow its own
  // errors, which meant a member with a loan in another cooperative — or with a
  // request that simply failed — walked straight through.
  AccountDeletionPreview? _preview;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final preview = await getIt<AccountActionsRepository>()
          .fetchAccountDeletionPreview();
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Delete Account',
            style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      children: [
                        vSpace(32),
                        const DeleteAccountWarningSection(),
                        vSpace(32),
                        const _DataLossSection(),
                        vSpace(24),
                        if (_loadError != null) ...[
                          _buildLoadError(_loadError!),
                          vSpace(24),
                        ] else if (preview != null &&
                            !preview.canDelete) ...[
                          _buildBlockers(preview),
                          vSpace(24),
                        ] else if (preview != null) ...[
                          const FreezeSuggestionBox(),
                          vSpace(32),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (preview != null && preview.canDelete)
                DeleteAccountActionButtons(
                  onDeleteAccount: () => context.pushNamed(
                    'delete-account-confirmation',
                    extra: DeleteAccountRequest(preview: preview),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadError(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFD32F2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We could not check your account',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD32F2F),
            ),
          ),
          vSpace(8),
          Text(
            message,
            style: TextStyle(fontSize: 16.sp, height: 1.5),
          ),
          vSpace(12),
          OutlinedButton(
            onPressed: _loadPreview,
            child: Text('Try again', style: TextStyle(fontSize: 16.sp)),
          ),
        ],
      ),
    );
  }

  /// The server's refusals, verbatim. Each message names what to do instead, so
  /// the app adds nothing to them and offers no way past them.
  Widget _buildBlockers(AccountDeletionPreview preview) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFD32F2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 20.sp,
                color: const Color(0xFFD32F2F),
              ),
              hSpace(8),
              Expanded(
                child: Text(
                  'You cannot delete your account yet',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD32F2F),
                  ),
                ),
              ),
            ],
          ),
          for (final blocker in preview.blockers) ...[
            vSpace(12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: Icon(
                    Icons.circle,
                    size: 6.sp,
                    color: const Color(0xFFD32F2F),
                  ),
                ),
                hSpace(8),
                Expanded(
                  child: Text(
                    blocker.message,
                    style: TextStyle(fontSize: 16.sp, height: 1.5),
                  ),
                ),
              ],
            ),
          ],
          if (preview.walletBalance > 0) ...[
            vSpace(16),
            Text(
              'Wallet balance: '
              '${CurrencyFormatter.formatFromMinor(preview.walletBalance, 'NGN')}',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
          ],
          if (preview.totalOwing > 0) ...[
            vSpace(4),
            Text(
              'Owed: '
              '${CurrencyFormatter.formatFromMinor(preview.totalOwing, 'NGN')}',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _DataLossSection extends StatelessWidget {
  const _DataLossSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Here\'s what you\'ll lose',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(16),
        const DataLossItem(
          icon: Icons.people,
          title: 'Cooperative Memberships',
          description:
              'You have to leave every community you belong to before you can '
              'delete your account',
          iconColor: Color(0xFFBA68C8), // Purple
        ),
        vSpace(12),
        // Not "permanently deleted": Communal is a financial institution and the
        // law requires it to keep records of money that moved. What goes is the
        // access and the personal data — the ledger entries stay.
        const DataLossItem(
          icon: Icons.description,
          title: 'Access to your history',
          description:
              'You lose access to your transactions, statements and loan '
              'records. Communal must keep the financial records themselves for '
              'as long as the law requires',
          iconColor: Color(0xFF42A5F5), // Blue
        ),
        vSpace(12),
        const DataLossItem(
          icon: Icons.person_off_outlined,
          title: 'Personal data',
          description:
              'Your profile, contact details and documents are erased within 30 '
              'days of deletion',
          iconColor: Color(0xFF66BB6A), // Green
        ),
        vSpace(12),
        const DataLossItem(
          icon: Icons.shield_outlined,
          title: 'Account Balance',
          description:
              'Any balance must be transferred to another account before deletion',
          iconColor: Colors.red,
        ),
      ],
    );
  }
}
