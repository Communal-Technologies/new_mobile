import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/support_models.dart';
import 'package:communal_mobile/data/repositories/support_repository.dart';
import 'package:communal_mobile/injection.dart';

/// Reports a cooperative to Communal's support team.
///
/// The report is a support ticket in the cooperative category naming the
/// cooperative, so it lands in the queue staff already work — where a cooperative
/// set up to extort people is exactly what they are checking for — and the member
/// can follow it under their support requests. The cooperative is never told.
class ReportCommunitySheet extends StatefulWidget {
  const ReportCommunitySheet({
    super.key,
    required this.cooperativeId,
    required this.cooperativeName,
  });

  final String cooperativeId;
  final String cooperativeName;

  static Future<void> show(
    BuildContext context, {
    required String cooperativeId,
    required String cooperativeName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReportCommunitySheet(
        cooperativeId: cooperativeId,
        cooperativeName: cooperativeName,
      ),
    );
  }

  @override
  State<ReportCommunitySheet> createState() => _ReportCommunitySheetState();
}

const List<String> _reasons = [
  'Asking for money under false pretences',
  'Threats, extortion or harassment',
  'Not a real cooperative',
  "Misusing members' contributions",
  'Something else',
];

class _ReportCommunitySheetState extends State<ReportCommunitySheet> {
  final _details = TextEditingController();
  String? _reason;
  bool _sending = false;

  bool get _needsDetails => _reason == _reasons.last;

  bool get _canSend =>
      !_sending &&
      _reason != null &&
      (!_needsDetails || _details.text.trim().length >= 10);

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_canSend) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sending = true);
    final details = _details.text.trim();
    try {
      await getIt<SupportRepository>().createTicket(
        category: SupportCategory.cooperative,
        subject: 'Cooperative report: ${widget.cooperativeName}',
        sourceRef: 'cooperative:${widget.cooperativeId}',
        message: [
          'I am reporting the cooperative "${widget.cooperativeName}" '
              '(${widget.cooperativeId}).',
          'Reason: $_reason',
          if (details.isNotEmpty) '\n$details',
        ].join('\n'),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.success(
        'Report sent. Our team will review this cooperative and reply in your support requests.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Report ${widget.cooperativeName}',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
              ),
              vSpace(6),
              Text(
                'Reports go to Communal, not to the cooperative. Tell us what is wrong.',
                style: TextStyle(
                  fontSize: 15.sp,
                  color: onSurface.withValues(alpha: 0.65),
                  height: 1.35,
                ),
              ),
              vSpace(12),
              for (final reason in _reasons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    _reason == reason
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _reason == reason
                        ? Colors.orange
                        : onSurface.withValues(alpha: 0.5),
                  ),
                  title: Text(reason, style: TextStyle(fontSize: 16.sp)),
                  onTap: _sending ? null : () => setState(() => _reason = reason),
                ),
              vSpace(8),
              TextField(
                controller: _details,
                enabled: !_sending,
                maxLines: 4,
                maxLength: 1000,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _needsDetails
                      ? 'Describe what happened (required)'
                      : 'Add details (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              vSpace(8),
              SizedBox(
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _canSend ? _send : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                  ),
                  child: _sending
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Send report',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
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
}
