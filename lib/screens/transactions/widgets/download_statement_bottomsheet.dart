import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class DownloadStatementBottomSheet extends StatefulWidget {
  const DownloadStatementBottomSheet({super.key});

  @override
  State<DownloadStatementBottomSheet> createState() => _DownloadStatementBottomSheetState();
}

class _DownloadStatementBottomSheetState extends State<DownloadStatementBottomSheet> {
  String _selectedPeriod = 'Last Week';
  String _selectedDelivery = 'Download';
  String _selectedFormat = 'Excel';
  final TextEditingController _emailController = TextEditingController(text: 'lebaripado@gmail.com');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _showEmailField => _selectedDelivery == 'Send to Email' || _selectedDelivery == 'Both';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download Statement',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    vSpace(6),
                    Text(
                      'Generate and send your transaction statement.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, size: 24.sp, color: Colors.grey.shade700),
                ),
              ],
            ),
            vSpace(24),

            // Select Period
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18.sp, color: Colors.grey.shade700),
                hSpace(8),
                Text(
                  'Select Period',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
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

            // Date Range
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Date',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      vSpace(8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          'dd-mm-yyyy',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                hSpace(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      vSpace(8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          'dd-mm-yyyy',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            vSpace(20),

            // Delivery Method
            Row(
              children: [
                Icon(Icons.download, size: 18.sp, color: Colors.grey.shade700),
                hSpace(8),
                Text(
                  'Delivery Method',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
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

            // Email Address (conditional)
            if (_showEmailField) ...[
              vSpace(20),
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 18.sp, color: Colors.grey.shade700),
                  hSpace(8),
                  Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              vSpace(12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: TextField(
                  controller: _emailController,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              vSpace(8),
              Text(
                'Statement will be sent to this email address.',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            vSpace(20),

            // File Format
            Row(
              children: [
                Icon(Icons.description_outlined, size: 18.sp, color: Colors.grey.shade700),
                hSpace(8),
                Text(
                  'File Format',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            vSpace(12),
            Row(
              children: [
                Expanded(child: _buildFormatChip('PDF', Icons.picture_as_pdf, theme)),
                hSpace(10),
                Expanded(child: _buildFormatChip('Excel', Icons.table_chart, theme)),
              ],
            ),
            vSpace(24),

            // Action button
            GestureDetector(
              onTap: () {
                // TODO: Download/send statement
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showEmailField ? Icons.email_outlined : Icons.download,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                    hSpace(8),
                    Text(
                      _showEmailField ? 'Download and Send' : 'Download Statement',
                      style: TextStyle(
                        fontSize: 16.sp,
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
          style: TextStyle(
            fontSize: 13.sp,
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
          style: TextStyle(
            fontSize: 13.sp,
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
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

