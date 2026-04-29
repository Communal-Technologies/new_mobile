import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/transactions/transaction_history_filters.dart';

class DownloadStatementBottomSheet extends StatefulWidget {
  const DownloadStatementBottomSheet({
    super.key,
    this.initialEmail,
  });

  final String? initialEmail;

  @override
  State<DownloadStatementBottomSheet> createState() =>
      _DownloadStatementBottomSheetState();
}

class _DownloadStatementBottomSheetState
    extends State<DownloadStatementBottomSheet> {
  String _selectedPeriod = 'Last Week';
  String _selectedDelivery = 'Download';
  String _selectedFormat = 'PDF';
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _showEmailField =>
      _selectedDelivery == 'Send to Email' || _selectedDelivery == 'Both';

  void _submit() {
    final (start, end) = statementRangeForPeriodChip(_selectedPeriod);
    final email = _emailController.text.trim();
    Navigator.pop(
      context,
      StatementExportRequest(
        startInclusive: start,
        endInclusive: end,
        delivery: _selectedDelivery,
        formatLabel: _selectedFormat,
        email: email.isEmpty ? null : email,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statement',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        vSpace(6),
                        Text(
                          'Generate your statement as PDF or CSV. Email delivery is handled securely by the backend service.',
                          style: TextStyle(
                            fontSize: 17.sp,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      size: 26.sp,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              vSpace(24),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  hSpace(8),
                  Text(
                    'Period',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              vSpace(12),
              Row(
                children: [
                  Expanded(child: _buildPeriodChip('Last Week', theme)),
                  hSpace(10),
                  Expanded(child: _buildPeriodChip('Last Month', theme)),
                  hSpace(10),
                  Expanded(child: _buildPeriodChip('Last 3 Months', theme)),
                ],
              ),
              vSpace(20),
              Row(
                children: [
                  Icon(
                    Icons.download,
                    size: 20.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  hSpace(8),
                  Text(
                    'Delivery',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              vSpace(12),
              Row(
                children: [
                  Expanded(child: _buildDeliveryChip('Download', theme)),
                  hSpace(10),
                  Expanded(child: _buildDeliveryChip('Send to Email', theme)),
                  hSpace(10),
                  Expanded(child: _buildDeliveryChip('Both', theme)),
                ],
              ),
              if (_showEmailField) ...[
                vSpace(20),
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 20.sp,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    hSpace(8),
                    Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                vSpace(12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(fontSize: 17.sp),
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: TextStyle(fontSize: 17.sp),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 14.h,
                    ),
                  ),
                ),
                vSpace(8),
                Text(
                  'For security, statements are generated and sent by the backend only.',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              vSpace(20),
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 20.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  hSpace(8),
                  Text(
                    'Format',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              vSpace(12),
              Row(
                children: [
                  Expanded(
                    child: _buildFormatChip('PDF', Icons.picture_as_pdf, theme),
                  ),
                  hSpace(10),
                  Expanded(
                    child: _buildFormatChip('CSV', Icons.table_chart, theme),
                  ),
                ],
              ),
              vSpace(24),
              GestureDetector(
                onTap: _submit,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 15.h),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.share,
                        color: Colors.white,
                        size: 22.sp,
                      ),
                      hSpace(8),
                      Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, ThemeData theme) {
    final isSelected = _selectedPeriod == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = label;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryChip(String label, ThemeData theme) {
    final isSelected = _selectedDelivery == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDelivery = label;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildFormatChip(String label, IconData icon, ThemeData theme) {
    final isSelected = _selectedFormat == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFormat = label;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18.sp,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            hSpace(6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
