import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/cooperative_sidebar.dart';
import 'package:communal_mobile/screens/transactions/models/sample_transactions.dart';
import 'package:communal_mobile/screens/transactions/widgets/transaction_tile.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.grey.shade50,
        drawer: const CooperativeSidebar(),
        drawerEdgeDragWidth: 50.w,
        drawerScrimColor: Colors.black.withValues(
          alpha: 0.4,
        ), // Darker overlay for better visibility
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(theme),

                vSpace(16),

                // KYC Alert
                _buildKycAlert(theme),

                vSpace(20),

                // Quick Actions
                _buildQuickActions(theme),

                vSpace(24),

                // Recent Transactions
                _buildRecentTransactions(theme),

                vSpace(20),

                // New Feature Banner
                _buildNewFeatureBanner(theme),

                vSpace(100),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 1) {
              context.pushNamed('obligations');
              return;
            }
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(right: 16.w, top: 12.h, bottom: 12.h, left: 0),
      color: Colors.white,
      child: Row(
        children: [
          // Purple button with switch arrow - TOUCHES LEFT EDGE - Opens Drawer
          InkWell(
            onTap: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            child: Container(
              width: 40.w,
              height: 40.w,
              margin: EdgeInsets.only(right: 8.w),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20.r),
                  bottomRight: Radius.circular(20.r),
                ),
              ),
              child: Center(
                child: Icon(Icons.swap_horiz, color: Colors.white, size: 22.sp),
              ),
            ),
          ),
          // Logo card with white background - NARROWER
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Exxon',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                      TextSpan(
                        text: 'Mobil',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Bullion Crib',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          hSpace(12),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Pado Lebari',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    hSpace(8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        'Member',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                vSpace(4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade600,
                    ),
                    children: [
                      const TextSpan(text: 'Lets save that '),
                      TextSpan(
                        text: '1 million',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const TextSpan(text: ' this month'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Notification - LARGER
          IconButton(
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.notifications_outlined,
              color: Colors.grey.shade700,
              size: 28.sp,
            ),
          ),
          hSpace(12),
          // Profile picture - LARGER
          CircleAvatar(
            radius: 22.w,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: const AssetImage('assets/images/demo_user.png'),
          ),
        ],
      ),
    );
  }

  Widget _buildKycAlert(ThemeData theme) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 26.sp,
                ),
              ),
              hSpace(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KYC NOT COMPLETED',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    vSpace(8),
                    Text(
                      'We\'ve detected that some of your details may be inaccurate or incomplete, kindly update to continue.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          vSpace(16),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: () {
                context.push('/kyc/profile-info');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100.r),
                ),
              ),
              child: Text(
                'Update Now >',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          vSpace(14),
          // First row - 4 buttons
          Row(
            children: [
              _buildQuickActionButton(
                icon: Icons.account_balance,
                label: 'Transfer',
                theme: theme,
              ),
              hSpace(10),
              _buildQuickActionButton(
                icon: Icons.phone_android,
                label: 'Buy Data',
                theme: theme,
              ),
              hSpace(10),
              _buildQuickActionButton(
                icon: Icons.phone,
                label: 'Airtime',
                theme: theme,
              ),
              hSpace(10),
              _buildQuickActionButton(
                icon: Icons.favorite_border,
                label: 'Loan',
                theme: theme,
              ),
            ],
          ),
          vSpace(10),
          // Second row - 3 buttons
          Row(
            children: [
              _buildQuickActionButton(
                icon: Icons.account_balance,
                label: 'Invest',
                theme: theme,
              ),
              hSpace(10),
              _buildQuickActionButton(
                icon: Icons.account_balance,
                label: 'Buy Now, Pay Later',
                theme: theme,
              ),
              hSpace(10),
              _buildQuickActionButton(
                icon: Icons.credit_card,
                label: 'Pay Bills',
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.primaryColor, size: 32.sp),
              vSpace(6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(ThemeData theme) {
    final recentTransactions = SampleTransactions.recentTransactions
        .take(4)
        .toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent transactions',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              TextButton(
                onPressed: () => context.pushNamed('transactions'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 20.sp,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          vSpace(12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTransactions.length,
            separatorBuilder: (_, __) => vSpace(10),
            itemBuilder: (_, index) {
              final item = recentTransactions[index];
              return TransactionTile(
                item: item,
                onTap: () => context.pushNamed(
                  'transaction-details',
                  extra: item.details,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNewFeatureBanner(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  theme.primaryColor.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'New Feature',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                vSpace(16),
                Text(
                  'Boost Your\nSavings',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                vSpace(8),
                Text(
                  'Earn up to 15% interest on\nfixed deposits',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.white.withValues(alpha: 0.95),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          vSpace(12),
          // Carousel dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDot(isActive: false, theme: theme),
              hSpace(6),
              _buildDot(isActive: true, theme: theme),
              hSpace(6),
              _buildDot(isActive: false, theme: theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot({required bool isActive, required ThemeData theme}) {
    return Container(
      width: isActive ? 20.w : 6.w,
      height: 6.h,
      decoration: BoxDecoration(
        color: isActive ? theme.primaryColor : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(3.r),
      ),
    );
  }
}
