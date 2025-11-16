import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/loans/data/sample_loans.dart';
import 'package:communal_mobile/screens/loans/widgets/active_loan_card.dart';
import 'package:communal_mobile/screens/loans/widgets/loan_offer_card.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  int _currentNavIndex = 3;

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
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                vSpace(24),
                _buildEligibilityCard(),
                vSpace(24),
                _buildQuickActions(),
                vSpace(24),
                _buildActiveLoansSection(),
                vSpace(24),
                _buildAvailableOffersSection(),
                vSpace(32),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            if (index == _currentNavIndex) return;
            switch (index) {
              case 0:
                context.goNamed('home');
                break;
              case 1:
                context.goNamed('obligations');
                break;
              case 2:
                context.goNamed('community');
                break;
              default:
                setState(() => _currentNavIndex = index);
            }
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Open menu')),
            );
          },
        ),
        Expanded(
          child: Text(
            'Loans',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.verified_user, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildEligibilityCard() {
    final eligibility = SampleLoans.eligibility;
    
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE67E22),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Eligibility Score',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          vSpace(12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                eligibility.scoreLabel,
                style: TextStyle(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              hSpace(12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  eligibility.rating,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          vSpace(16),
          Stack(
            children: [
              Container(
                height: 8.h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              FractionallySizedBox(
                widthFactor: eligibility.score / 100,
                child: Container(
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
            ],
          ),
          vSpace(12),
          Row(
            children: [
              Icon(
                Icons.bookmark,
                size: 16.sp,
                color: Colors.white.withOpacity(0.8),
              ),
              hSpace(6),
              Text(
                eligibility.communityName,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.calculate_outlined,
                label: 'Loan Calculator',
                onTap: () {
                  context.pushNamed('loan-calculator');
                },
              ),
            ),
            hSpace(12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.attach_money,
                label: 'Apply Now',
                onTap: () {
                  context.pushNamed('loan-application');
                },
              ),
            ),
            hSpace(12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.history,
                label: 'Loan History',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Loan History coming soon')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                icon,
                size: 20.sp,
                color: const Color(0xFFFFD2B0),
              ),
            ),
            vSpace(8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F1D40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLoansSection() {
    final activeLoans = SampleLoans.activeLoans;

    if (activeLoans.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Loans',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(16),
        ...activeLoans.map((loan) {
          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: ActiveLoanCard(
              loan: loan,
              onViewDetails: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('View details for ${loan.title}')),
                );
              },
              onMakePayment: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Make payment for ${loan.title}')),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAvailableOffersSection() {
    final offers = SampleLoans.availableOffers;

    if (offers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available for You',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(16),
        ...offers.map((offer) {
          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: LoanOfferCard(
              offer: offer,
              onApply: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Apply for ${offer.title}')),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

