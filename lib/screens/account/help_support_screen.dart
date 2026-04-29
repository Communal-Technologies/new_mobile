import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/help_category_grid.dart';
import 'package:communal_mobile/screens/account/widgets/faq_section.dart';
import 'package:communal_mobile/screens/account/widgets/contact_method_card.dart';
import 'package:communal_mobile/screens/account/widgets/social_media_section.dart';
import 'package:communal_mobile/screens/account/widgets/resource_item.dart';
import 'package:communal_mobile/screens/account/widgets/support_hours_card.dart';
import 'package:communal_mobile/screens/account/widgets/bottom_action_bar.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            'Help & Support',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    vSpace(16),
                    _buildSearchBar(),
                    vSpace(24),
                    _buildSectionTitle('What do you need help with?'),
                    vSpace(12),
                    const HelpCategoryGrid(),
                    vSpace(24),
                    _buildFaqSection(),
                    vSpace(24),
                    _buildSectionTitle('Other Contact Methods'),
                    vSpace(12),
                    const ContactMethodCard(
                      icon: Icons.email,
                      title: 'Email Support',
                      contact: 'support@bullioncrib.com',
                    ),
                    vSpace(8),
                    const ContactMethodCard(
                      icon: Icons.phone,
                      title: 'Call Us',
                      contact: '+234 (0) 800 123 4567',
                    ),
                    vSpace(24),
                    _buildSectionTitle('Follow us on Socials'),
                    vSpace(12),
                    const SocialMediaSection(),
                    vSpace(24),
                    _buildSectionTitle('Resources'),
                    vSpace(12),
                    const ResourceItem(
                      icon: Icons.description,
                      title: 'User Guide',
                      description: 'Complete app walkthrough',
                    ),
                    vSpace(8),
                    const ResourceItem(
                      icon: Icons.video_library,
                      title: 'Video Tutorials',
                      description: 'Step-by-step videos',
                    ),
                    vSpace(8),
                    const ResourceItem(
                      icon: Icons.description,
                      title: 'Terms and Policies',
                      description: 'Legal documents',
                    ),
                    vSpace(24),
                    const SupportHoursCard(),
                    vSpace(100), // Space for bottom action bar
                  ],
                ),
              ),
            ),
            const BottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
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
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for help...',
            hintStyle: TextStyle(
              fontSize: 15.sp,
              color: Colors.grey.shade500,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.shade400,
              size: 20.sp,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildFaqSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.pushNamed('faq');
                },
                child: Text(
                  'See more',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: const Color(0xFF7434FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        vSpace(12),
        const FaqSection(),
      ],
    );
  }
}

