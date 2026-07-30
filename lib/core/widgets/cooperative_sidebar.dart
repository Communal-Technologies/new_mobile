import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/navigation/root_navigator_key.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/community_membership_model.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/data/repositories/community_repository.dart';
import 'package:communal_mobile/data/repositories/community_settings_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/community/widgets/join_community_invite_sheet.dart';

class CooperativeSidebar extends StatefulWidget {
  const CooperativeSidebar({super.key});

  @override
  State<CooperativeSidebar> createState() => _CooperativeSidebarState();
}

class _CooperativeSidebarState extends State<CooperativeSidebar> {
  final CommunitySettingsRepository _membershipsRepo =
      getIt<CommunitySettingsRepository>();

  List<CommunityMembership> _memberships = const [];
  bool _loadingMemberships = true;
  String? _membershipsError;

  @override
  void initState() {
    super.initState();
    // Seed from cache so re-opening the drawer shows the cooperatives instantly
    // instead of refetching (and flashing a spinner) every toggle. Only hit the
    // network when we have nothing cached yet.
    final cached = _membershipsRepo.cachedMemberships;
    if (cached != null) {
      _memberships = cached;
      _loadingMemberships = false;
      // Revalidate in the background: the cache is a session-lived singleton,
      // so a list fetched earlier (possibly before a rename or a coop-side data
      // fix) would otherwise be replayed on every drawer open with no way to
      // reconcile. Force past the cache silently — no spinner, since we already
      // have something to show — and swap in the fresh list if it differs.
      _revalidateMemberships();
    } else {
      _loadMemberships();
    }
  }

  Future<void> _revalidateMemberships() async {
    try {
      final fresh =
          await _membershipsRepo.fetchMemberships(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _memberships = fresh;
        _membershipsError = null;
      });
    } catch (_) {
      // Silent: we're already showing the cached list; a failed revalidation
      // shouldn't blank it or surface an error over usable data.
    }
  }

  Future<void> _loadMemberships({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _loadingMemberships = _memberships.isEmpty;
        _membershipsError = null;
      });
    }
    try {
      final list =
          await _membershipsRepo.fetchMemberships(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _memberships = list;
        _loadingMemberships = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _membershipsError = 'Could not load your cooperatives.';
        _loadingMemberships = false;
      });
    }
  }

  void _switchCooperative(CommunityMembership m) {
    final authBloc = context.read<AuthBloc>();
    authBloc.add(AuthCooperativeSwitched(
      cooperativeId: m.cooperativeId,
      ledgerNumber: m.ledgerNumber,
      cooperativeName: m.cooperativeName,
      cooperativeLogoUrl: m.logoUrl,
    ));
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx == null || !navCtx.mounted) return;
      // Reset the navigation stack to home. The screen we switched from may be
      // scoped to the previous cooperative (e.g. a loan detail keyed by its
      // ledger number / cooperative id); leaving it open would let the user act
      // on the old cooperative's data under the new cooperative's session and
      // conflict on ledger_number / coopID. `go` clears the stack so those
      // stale coop-scoped screens are torn down and rebuilt against the new
      // active cooperative.
      navCtx.go('/home');
      ScaffoldMessenger.of(navCtx).showSnackBar(
        SnackBar(content: Text('Switched to ${m.cooperativeName}.')),
      );
    });
  }
  void _openJoinCooperativeSheet(BuildContext drawerContext) {
    Navigator.of(drawerContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx == null || !navCtx.mounted) return;
      showModalBottomSheet<CommunityJoinResult>(
        context: navCtx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => const JoinCommunityInviteSheet(),
      ).then((result) {
        if (result == null) return;
        if (!navCtx.mounted) return;
        navCtx.read<AuthBloc>().add(AuthRefreshUserRequested());
        // Refresh the drawer's cooperative list so the newly-joined
        // cooperative appears immediately (force past the cache).
        _loadMemberships(forceRefresh: true);
        ScaffoldMessenger.of(navCtx).showSnackBar(
          SnackBar(
            content: Text(
              result.cooperativeName.isEmpty
                  ? 'You have joined the cooperative.'
                  : 'Welcome to ${result.cooperativeName}.',
            ),
          ),
        );
      });
    });
  }

  void _openSettings(BuildContext drawerContext) {
    Navigator.of(drawerContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navCtx = rootNavigatorKey.currentContext;
      if (navCtx == null || !navCtx.mounted) return;
      navCtx.pushNamed('account-settings');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    return Drawer(
      width: 360.w,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
            children: [
              // Main content with SafeArea only for top
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Cooperative Card with Header inside
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark
                                  ? [
                                      theme.primaryColor.withValues(alpha: 0.18),
                                      theme.primaryColor.withValues(alpha: 0.10),
                                    ]
                                  : const [
                                      Color(0xFFE8E3FF),
                                      Color(0xFFE0D9FF),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: BlocBuilder<AuthBloc, AuthState>(
                            buildWhen: (prev, next) {
                              final pu =
                                  prev is AuthAuthenticated ? prev.user : null;
                              final nu =
                                  next is AuthAuthenticated ? next.user : null;
                              return pu != nu;
                            },
                            builder: (context, authState) {
                              final user = authState is AuthAuthenticated
                                  ? authState.user
                                  : null;
                              final hasCoop =
                                  user?.hasCooperativeMembership ?? false;
                              final coopLabel =
                                  user?.cooperativeDisplayName ?? '—';
                              final ledger = user?.ledgerNumber ?? '';
                              final accountName =
                                  user?.name.isNotEmpty == true
                                      ? user!.name
                                      : (user?.login ?? 'Member');
                              final role = user?.roleLabel ?? 'Member';
                              final primaryTitle = hasCoop
                                  ? coopLabel
                                  : 'Not in a cooperative yet';
                              final secondaryLine =
                                  '$accountName · $role';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Current Cooperative',
                                        style: TextStyle(
                                          fontSize: 19.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? onSurface
                                              : Colors.grey.shade800,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Icon(
                                          Icons.close,
                                          color: isDark
                                              ? onSurface
                                              : Colors.grey.shade700,
                                          size: 22.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                  vSpace(8),
                                  Row(
                                    children: [
                                      Container(
                                        width: 44.w,
                                        height: 44.w,
                                        padding: EdgeInsets.all(5.w),
                                        decoration: BoxDecoration(
                                          color: theme.cardColor,
                                          borderRadius:
                                              BorderRadius.circular(8.r),
                                          border: Border.all(
                                            color: theme.dividerColor,
                                            width: 1,
                                          ),
                                        ),
                                        child: _cooperativeListThumb(
                                          user: user,
                                          theme: theme,
                                          hasCoop: hasCoop,
                                          coopLabel: coopLabel,
                                          ledger: ledger,
                                        ),
                                      ),
                                      hSpace(14),
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(right: 20.w),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                primaryTitle,
                                                style: TextStyle(
                                                  fontSize: 19.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? onSurface
                                                      : Colors.black,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              vSpace(2),
                                              Text(
                                                secondaryLine,
                                                style: TextStyle(
                                                  fontSize: 17.sp,
                                                  color: isDark
                                                      ? onSurface.withValues(
                                                          alpha: 0.7)
                                                      : Colors.grey.shade700,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.more_vert,
                                        color: isDark
                                            ? onSurface.withValues(alpha: 0.7)
                                            : Colors.grey.shade600,
                                        size: 22.sp,
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        vSpace(16),

                        // Other cooperatives
                        Text(
                          'Other cooperatives',
                          style: TextStyle(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                        ),

                        vSpace(10),

                        Expanded(
                          child: BlocBuilder<AuthBloc, AuthState>(
                            buildWhen: (prev, next) {
                              final pu = prev is AuthAuthenticated
                                  ? prev.user.cooperativeId
                                  : null;
                              final nu = next is AuthAuthenticated
                                  ? next.user.cooperativeId
                                  : null;
                              return pu != nu;
                            },
                            builder: (context, authState) {
                              final activeCoopId = authState is AuthAuthenticated
                                  ? authState.user.cooperativeId?.trim()
                                  : null;
                              return _buildOtherCooperatives(
                                theme: theme,
                                onSurface: onSurface,
                                isDark: isDark,
                                activeCoopId: activeCoopId,
                              );
                            },
                          ),
                        ),

                        vSpace(12),

                        // Bottom Actions
                        _buildBottomAction(
                          theme: theme,
                          icon: Icons.add_circle_outline,
                          label: 'Join with Invite Code',
                          onTap: () => _openJoinCooperativeSheet(context),
                        ),
                        vSpace(8),
                        // "Add Another Account" removed — the app does
                        // not currently permit multiple concurrent
                        // sessions, so a non-functional row would just
                        // confuse users.
                        _buildBottomAction(
                          theme: theme,
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          onTap: () => _openSettings(context),
                        ),

                        vSpace(8),
                      ],
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildOtherCooperatives({
    required ThemeData theme,
    required Color onSurface,
    required bool isDark,
    required String? activeCoopId,
  }) {
    if (_loadingMemberships) {
      return Center(
        child: SizedBox(
          width: 22.w,
          height: 22.w,
          child: CircularProgressIndicator(
            strokeWidth: 2, color: theme.primaryColor),
        ),
      );
    }

    if (_membershipsError != null) {
      return ListView(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Text(
              _membershipsError!,
              style: TextStyle(
                fontSize: 17.sp,
                height: 1.35,
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: _loadMemberships,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    // Defensive: the repository already dedupes by cooperative id, but the
    // membership list is a session-lived singleton, so re-dedupe at render
    // time too — a single aliased/duplicated entry must never surface as
    // repeated tiles in the drawer.
    final seenIds = <String>{};
    final others = <CommunityMembership>[];
    for (final m in _memberships) {
      final id = m.cooperativeId.trim();
      if (id.isEmpty || id == (activeCoopId ?? '')) continue;
      if (!seenIds.add(id)) continue;
      others.add(m);
    }

    // When two DISTINCT cooperatives share the same display name, disambiguate
    // by id so the user never sees two rows that look identical (the exact
    // symptom of issue #41). Only names that actually collide are suffixed.
    final nameCounts = <String, int>{};
    for (final m in others) {
      final key = m.cooperativeName.trim().toLowerCase();
      nameCounts[key] = (nameCounts[key] ?? 0) + 1;
    }
    final collidingNames = nameCounts.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toSet();

    if (others.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Text(
              'You can use Communal without belonging to a cooperative. '
              'When you join one (or more) with an invite code, they will show here.',
              style: TextStyle(
                fontSize: 17.sp,
                height: 1.35,
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: others.length,
      separatorBuilder: (_, __) => vSpace(8),
      itemBuilder: (context, index) {
        final m = others[index];
        final collides =
            collidingNames.contains(m.cooperativeName.trim().toLowerCase());
        return _cooperativeTile(
          theme: theme,
          onSurface: onSurface,
          isDark: isDark,
          membership: m,
          disambiguateWithId: collides,
        );
      },
    );
  }

  Widget _cooperativeTile({
    required ThemeData theme,
    required Color onSurface,
    required bool isDark,
    required CommunityMembership membership,
    bool disambiguateWithId = false,
  }) {
    final displayName = disambiguateWithId &&
            membership.cooperativeId.trim().isNotEmpty
        ? '${membership.cooperativeName} (${membership.cooperativeId.trim()})'
        : membership.cooperativeName;
    final logo = membership.logoUrl?.trim();
    final useNet = logo != null &&
        logo.isNotEmpty &&
        (logo.startsWith('http://') || logo.startsWith('https://'));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _switchCooperative(membership),
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: theme.dividerColor, width: 1),
                ),
                child: useNet
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6.r),
                        child: Image.network(
                          logo,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.groups_outlined,
                            size: 22.sp,
                            color: theme.primaryColor,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.groups_outlined,
                        size: 22.sp,
                        color: theme.primaryColor,
                      ),
              ),
              hSpace(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? onSurface : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    vSpace(2),
                    Text(
                      '${membership.roleLabel} · ${membership.ledgerNumber}',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.swap_horiz,
                size: 20.sp,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Matches home header: logo when URL is valid, else compact id + ledger text.
  Widget _cooperativeListThumb({
    required UserModel? user,
    required ThemeData theme,
    required bool hasCoop,
    required String coopLabel,
    required String ledger,
  }) {
    final logo = user?.cooperativeLogoUrl?.trim();
    final useNet = logo != null &&
        logo.isNotEmpty &&
        (logo.startsWith('http://') || logo.startsWith('https://'));

    if (!hasCoop && !useNet) {
      return Icon(
        Icons.groups_outlined,
        size: 26.sp,
        color: theme.primaryColor,
      );
    }

    if (useNet) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6.r),
        child: Image.network(
          logo,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _cooperativeThumbText(
            theme: theme,
            coopLabel: coopLabel,
            ledger: ledger,
          ),
        ),
      );
    }

    return _cooperativeThumbText(
      theme: theme,
      coopLabel: coopLabel,
      ledger: ledger,
    );
  }

  Widget _cooperativeThumbText({
    required ThemeData theme,
    required String coopLabel,
    required String ledger,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          coopLabel,
          style: TextStyle(
            fontSize: 7.sp,
            fontWeight: FontWeight.w700,
            color: theme.primaryColor,
            height: 1.0,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (ledger.isNotEmpty) ...[
          SizedBox(height: 1.h),
          Text(
            ledger,
            style: TextStyle(
              fontSize: 5.5.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildBottomAction({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final onSurface = theme.colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22.sp,
                color: onSurface.withValues(alpha: 0.7),
              ),
              hSpace(12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
