import 'dart:async';

import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/support_models.dart';
import 'package:communal_mobile/data/repositories/support_repository.dart';
import 'package:communal_mobile/injection.dart';
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

  SupportConfig _config = SupportConfig.fallback;
  int _openRequests = 0;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfig());
    unawaited(_loadRequests());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// The contact details, support hours and whether anyone is at the desk, all
  /// admin-set. This screen used to hardcode an email address belonging to a
  /// different product and a placeholder phone number, so a member who copied
  /// either of them reached nobody.
  Future<void> _loadConfig() async {
    final config = await getIt<SupportRepository>().config();
    if (!mounted) return;
    setState(() => _config = config);
  }

  Future<void> _loadRequests() async {
    try {
      final result = await getIt<SupportRepository>().tickets(limit: 50);
      if (!mounted) return;
      setState(() {
        _openRequests = result.tickets.where((t) => !t.isFinished).length;
        _unread = result.unreadTotal;
      });
    } catch (_) {
      // A missing count is not worth a banner on the help screen.
    }
  }

  void _search(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    context.pushNamed('faq', queryParameters: {'q': query});
  }

  Future<void> _openRequestsList() async {
    await context.pushNamed('support-tickets');
    if (mounted) await _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(theme),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor,
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
              color: theme.colorScheme.onSurface,
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
                    vSpace(16),
                    _buildMyRequestsTile(theme),
                    vSpace(24),
                    _buildSectionTitle('What do you need help with?'),
                    vSpace(12),
                    const HelpCategoryGrid(),
                    vSpace(24),
                    _buildFaqSection(),
                    vSpace(24),
                    ..._buildContactMethods(),
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
                    SupportHoursCard(config: _config),
                    vSpace(24),
                  ],
                ),
              ),
            ),
            BottomActionBar(operatorsOnline: _config.operatorsOnline),
          ],
        ),
      ),
    );
  }

  /// The way back into an ongoing conversation. Without it the only route to a
  /// reply is a push notification, and a member who dismissed the push has no
  /// way of finding what we said.
  Widget _buildMyRequestsTile(ThemeData theme) {
    final subtitle = _openRequests == 0
        ? 'See anything you have asked us'
        : '$_openRequests still open';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: InkWell(
        onTap: () => unawaited(_openRequestsList()),
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: theme.dividerColor,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF7434FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.forum_outlined,
                  color: const Color(0xFF7434FF),
                  size: 20.sp,
                ),
              ),
              hSpace(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Requests',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    vSpace(2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (_unread > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7434FF),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    '$_unread new',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              hSpace(4),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Only the channels the admin has actually configured. An empty setting means
  /// the section is omitted rather than showing a blank card — the assistant and
  /// the queue are the supported paths, and inventing a contact detail here is
  /// how the old hardcoded address survived this long.
  List<Widget> _buildContactMethods() {
    final cards = <Widget>[
      if (_config.email.isNotEmpty)
        ContactMethodCard(
          icon: Icons.email,
          title: 'Email Support',
          contact: _config.email,
        ),
      if (_config.phone.isNotEmpty)
        ContactMethodCard(
          icon: Icons.phone,
          title: 'Call Us',
          contact: _config.phone,
        ),
    ];
    if (cards.isEmpty) return const [];

    return [
      _buildSectionTitle('Other Contact Methods'),
      vSpace(12),
      for (int i = 0; i < cards.length; i++) ...[
        if (i > 0) vSpace(8),
        cards[i],
      ],
      vSpace(24),
    ];
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).dividerColor,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: 'Search for help...',
            hintStyle: TextStyle(
              fontSize: 17.sp,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
          fontSize: 19.sp,
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
                  fontSize: 19.sp,
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
                    fontSize: 17.sp,
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
