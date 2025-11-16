import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/loans/data/sample_guarantors.dart';
import 'package:communal_mobile/screens/loans/widgets/guarantor_selector.dart';

class LoanApplicationStep2Screen extends StatefulWidget {
  const LoanApplicationStep2Screen({super.key});

  @override
  State<LoanApplicationStep2Screen> createState() => _LoanApplicationStep2ScreenState();
}

class _LoanApplicationStep2ScreenState extends State<LoanApplicationStep2Screen> {
  Guarantor? _firstGuarantor;
  Guarantor? _secondGuarantor;

  List<String> get _excludedGuarantorIds {
    final excluded = <String>[];
    if (_firstGuarantor != null) excluded.add(_firstGuarantor!.id);
    if (_secondGuarantor != null) excluded.add(_secondGuarantor!.id);
    return excluded;
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Loan Application',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: Text(
                  'Step 2 of 3',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7434FF),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressIndicator(),
              vSpace(24),
              _buildInfoCard(),
              vSpace(24),
              GuarantorSelector(
                label: 'First Guarantor',
                selectedGuarantor: _firstGuarantor,
                availableGuarantors: SampleGuarantors.all,
                excludedGuarantorIds: _excludedGuarantorIds,
                onChanged: (guarantor) {
                  setState(() {
                    _firstGuarantor = guarantor;
                  });
                },
              ),
              vSpace(24),
              GuarantorSelector(
                label: 'Second Guarantor',
                selectedGuarantor: _secondGuarantor,
                availableGuarantors: SampleGuarantors.all,
                excludedGuarantorIds: _excludedGuarantorIds,
                onChanged: (guarantor) {
                  setState(() {
                    _secondGuarantor = guarantor;
                  });
                },
              ),
              vSpace(24),
              _buildNotificationCard(),
              vSpace(40),
              _buildNavigationButtons(),
              vSpace(32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Choose Guarantors',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7434FF),
            ),
          ),
        ),
        vSpace(8),
        Stack(
          children: [
            Container(
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            FractionallySizedBox(
              widthFactor: 2 / 3,
              child: Container(
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF7434FF),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: const BoxDecoration(
              color: Color(0xFF1976D2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Two Guarantors',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
                vSpace(4),
                Text(
                  'Choose two members from your cooperative who will guarantee this loan.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: const Color(0xFF4CAF50),
            size: 20.sp,
          ),
          hSpace(12),
          Expanded(
            child: Text(
              'Both guarantors will be notified to approve your loan request',
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(vertical: 16.h),
            ),
            child: Text(
              'Back',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F1D40),
              ),
            ),
          ),
        ),
        hSpace(12),
        Expanded(
          child: ElevatedButton(
            onPressed: _firstGuarantor != null && _secondGuarantor != null
                ? () {
                    // TODO: Navigate to step 3
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Step 3 coming soon')),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7434FF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(vertical: 16.h),
            ),
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

