import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/utils/currency_formatter.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/account_actions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';

/// Carried from the checkpoints screen to the PIN step: which membership is
/// closing, the position the member was shown when they agreed, and their
/// reason. The preview travels with it so the PIN screen never has to re-read
/// it and risk submitting against figures the member never saw.
class LeaveCooperativeRequest {
  const LeaveCooperativeRequest({
    required this.location,
    required this.preview,
    this.reason,
  });

  final CommunityLocation location;
  final AccountClosurePreview preview;
  final String? reason;
}

/// The checkpoints before leaving one cooperative.
///
/// Everything shown here comes from `GET members/account-closure/preview` —
/// the same numbers and the same rules the administrator reviews. Blockers are
/// refusals the server will repeat, so they close the button; warnings are
/// consequences the member has to tick off one by one.
class LeaveCooperativeScreen extends StatefulWidget {
  const LeaveCooperativeScreen({super.key, required this.location});

  final CommunityLocation location;

  @override
  State<LeaveCooperativeScreen> createState() => _LeaveCooperativeScreenState();
}

class _LeaveCooperativeScreenState extends State<LeaveCooperativeScreen> {
  final TextEditingController _reasonController = TextEditingController();

  AccountClosurePreview? _preview;
  bool _loading = true;
  String? _loadError;
  final Set<int> _acknowledged = <int>{};

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final preview = await getIt<AccountActionsRepository>()
          .fetchAccountClosurePreview(widget.location.id);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _acknowledged.clear();
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

  bool get _allAcknowledged {
    final preview = _preview;
    if (preview == null) return false;
    return _acknowledged.length == preview.warnings.length;
  }

  bool get _canContinue {
    final preview = _preview;
    return preview != null && preview.canSubmit && _allAcknowledged;
  }

  String _money(int kobo) => CurrencyFormatter.formatFromMinor(kobo, 'NGN');

  void _continue() {
    final preview = _preview;
    if (preview == null) return;
    final reason = _reasonController.text.trim();
    context.pushNamed(
      'leave-cooperative-pin',
      extra: LeaveCooperativeRequest(
        location: widget.location,
        preview: preview,
        reason: reason.isEmpty ? null : reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Leave Community',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _buildLoadError(_loadError!);
    }
    final preview = _preview!;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          vSpace(20),
          _buildPositionCard(preview),
          if (preview.blockers.isNotEmpty) ...[
            vSpace(16),
            _buildBlockers(preview.blockers),
          ],
          if (preview.warnings.isNotEmpty) ...[
            vSpace(24),
            Text(
              'Before you go',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            vSpace(12),
            for (var i = 0; i < preview.warnings.length; i++) ...[
              _buildAcknowledgement(i, preview.warnings[i]),
              if (i != preview.warnings.length - 1) vSpace(12),
            ],
          ],
          vSpace(24),
          _buildReasonField(),
          vSpace(24),
          _buildContinueButton(),
          vSpace(32),
        ],
      ),
    );
  }

  Widget _buildLoadError(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            vSpace(16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            vSpace(24),
            OutlinedButton(
              onPressed: _loadPreview,
              child: Text('Try again', style: TextStyle(fontSize: 17.sp)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.logout,
              size: 36.sp,
              color: const Color(0xFFE67E22),
            ),
          ),
        ),
        vSpace(16),
        Text(
          'Leave ${widget.location.name}?',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(8),
        Text(
          'This closes your membership of this community only. Your Communal '
          'account and wallet stay exactly as they are.',
          style: TextStyle(
            fontSize: 17.sp,
            height: 1.5,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionCard(AccountClosurePreview preview) {
    final net = preview.netAmount;
    final (String netLabel, Color netColor) = switch (preview.netType) {
      'creditor' => ('The community will owe you', const Color(0xFF1F8B4C)),
      'debtor' => ('You will still owe the community', const Color(0xFFD32F2F)),
      _ => ('Nothing left either way', const Color(0xFF6B6B80)),
    };
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'What will be settled',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (preview.ledgerNumber.isNotEmpty)
                Text(
                  preview.ledgerNumber,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          vSpace(12),
          _buildPositionRow('Savings (EPC)', _money(preview.epcBalance)),
          _buildPositionRow('Loans outstanding', _money(preview.loansBalance)),
          _buildPositionRow('Interest', _money(preview.interestBalance)),
          _buildPositionRow('Fines', _money(preview.finesBalance)),
          Divider(height: 24.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  netLabel,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                _money(net),
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: netColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockers(List<String> blockers) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFFD32F2F).withValues(alpha: 0.16)
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You cannot leave yet',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD32F2F),
            ),
          ),
          vSpace(8),
          for (final blocker in blockers)
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.block,
                    size: 16.sp,
                    color: const Color(0xFFD32F2F),
                  ),
                  hSpace(8),
                  Expanded(
                    child: Text(
                      blocker,
                      style: TextStyle(
                        fontSize: 17.sp,
                        height: 1.4,
                        color: const Color(0xFFD32F2F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAcknowledgement(int index, String text) {
    final checked = _acknowledged.contains(index);
    return InkWell(
      onTap: () => setState(() {
        if (checked) {
          _acknowledged.remove(index);
        } else {
          _acknowledged.add(index);
        }
      }),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: checked
                ? const Color(0xFF742CE7)
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 22.sp,
              color: checked
                  ? const Color(0xFF742CE7)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            hSpace(12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 17.sp,
                  height: 1.45,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why are you leaving? (optional)',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(8),
        TextField(
          controller: _reasonController,
          maxLines: 3,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(fontSize: 17.sp),
          decoration: InputDecoration(
            hintText: 'The administrator reviewing your request will see this.',
            hintStyle: TextStyle(
              fontSize: 16.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    final preview = _preview;
    final helper = preview != null && !preview.canSubmit
        ? 'Sort the item above out first.'
        : (_allAcknowledged ? null : 'Tick every point above to continue.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _canContinue ? _continue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          child: Text(
            'Request to leave',
            style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
          ),
        ),
        if (helper != null) ...[
          vSpace(8),
          Text(
            helper,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }
}
