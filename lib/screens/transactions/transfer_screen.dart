import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/repositories/transactions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/transactions/models/sample_transactions.dart';
import 'package:communal_mobile/screens/transactions/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:communal_mobile/core/widgets/back_to_exit_wrapper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _favoritesPrefs = getIt<TransferFavoritesPrefs>();
  late final TransactionsRepository _txRepo = TransactionsRepository(
    getIt<DioClient>(),
  );
  List<TransferFavorite> _favorites = const [];
  List<TransactionListItem> _recentItems = const [];
  bool _recentLoading = true;
  String? _recentError;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecent());
  }

  void _loadFavorites() {
    setState(() => _favorites = _favoritesPrefs.getAll());
  }

  Future<void> _loadRecent() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      if (mounted) {
        setState(() {
          _recentLoading = false;
          _recentItems = const [];
        });
      }
      return;
    }
    setState(() {
      _recentLoading = true;
      _recentError = null;
    });
    try {
      final list = await _txRepo.fetchPersonalHistoryMerged(auth.user);
      if (!mounted) return;
      setState(() {
        _recentItems = list.take(5).toList(growable: false);
        _recentLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recentLoading = false;
        _recentError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackToExitWrapper(child: _buildRootBody(context));
  }

  Widget _buildRootBody(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, next) {
        if (prev is AuthAuthenticated && next is AuthAuthenticated) {
          return prev.user.walletBalanceKobo != next.user.walletBalanceKobo;
        }
        return prev.runtimeType != next.runtimeType;
      },
      listener: (_, state) {
        if (state is AuthAuthenticated) _loadRecent();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 22),
            onPressed: () => context.pop(),
          ),
          title: const Text('Transfer Money'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Transfer Type',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                vSpace(12),
                _optionCard(
                  icon: Icons.group,
                  title: 'Internal Transfer',
                  subtitle: 'Send money to Communal members instantly',
                  tag: 'Internal',
                  onTap: () => context.pushNamed('transfer-internal'),
                ),
                vSpace(12),
                _optionCard(
                  icon: Icons.account_balance,
                  title: 'To Other Banks',
                  subtitle: 'Transfer funds to any bank account in Nigeria',
                  tag: 'External',
                  onTap: () => context.pushNamed('transfer-external'),
                ),
                if (_favorites.isNotEmpty) ...[
                  vSpace(18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Favourites',
                        style: TextStyle(
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: _showAllFavorites,
                        child: Text(
                          'See all',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 106.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _favorites.length > 10
                          ? 10
                          : _favorites.length,
                      separatorBuilder: (_, __) => hSpace(10),
                      itemBuilder: (_, i) => _favoriteCard(_favorites[i]),
                    ),
                  ),
                ],
                vSpace(20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transfers',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.pushNamed('transactions'),
                      child: Text(
                        'See all',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_recentLoading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Center(
                      child: Image.asset(
                        Images.loader,
                        width: 52.w,
                        height: 52.w,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else if (_recentError != null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _recentError!,
                            style: TextStyle(
                              fontSize: 17.sp,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadRecent,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (_recentItems.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Text(
                      'No recent transfers',
                      style: TextStyle(
                        fontSize: 17.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentItems.length,
                    separatorBuilder: (_, __) => vSpace(10),
                    itemBuilder: (_, index) {
                      final item = _recentItems[index];
                      return TransactionTile(
                        item: item,
                        onTap: () => context.pushNamed(
                          'transaction-details',
                          extra: item.details,
                        ),
                      );
                    },
                  ),
                vSpace(24),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            setState(() => _currentNavIndex = index);
            switch (index) {
              case 0:
                context.goNamed('home');
                break;
              case 1:
                context.pushNamed('obligations');
                break;
              case 2:
                context.pushNamed('community');
                break;
              case 3:
                context.goNamed('loans');
                break;
              case 4:
                context.goNamed('account-settings');
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _favoriteCard(TransferFavorite f) {
    final initials = _initials(f.accountName);
    return InkWell(
      onTap: () => _openFavorite(f),
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        width: 95.08.w,
        height: 101.h,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: const Color(0xFFEDE4FF),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF7434FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            vSpace(8),
            Text(
              f.accountName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            Text(
              f.accountNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _openFavorite(TransferFavorite f) {
    if (f.isInternal) {
      context.pushNamed(
        'transfer-internal-amount',
        extra: {'favorite': f.toJson()},
      );
    } else {
      context.pushNamed('transfer-external', extra: {'favorite': f.toJson()});
    }
  }

  Future<void> _showAllFavorites() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView.builder(
            itemCount: _favorites.length,
            itemBuilder: (_, i) {
              final f = _favorites[i];
              return ListTile(
                title: Text(f.accountName),
                subtitle: Text('${f.bank} • ${f.accountNumber}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await _favoritesPrefs.remove(f);
                    if (mounted) _loadFavorites();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openFavorite(f);
                },
              );
            },
          ),
        );
      },
    );
    if (mounted) _loadFavorites();
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String tag,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Tag pills used to be hardcoded lavender / sky pastels which
    // washed out on the dark scaffold. Mix the brand purple (Internal)
    // and a steel blue (External) with the surface in dark mode.
    const externalAccent = Color(0xFF1976D2);
    final tagBg = tag == 'Internal'
        ? (isDark
              ? theme.primaryColor.withValues(alpha: 0.16)
              : const Color(0xFFEDE4FF))
        : (isDark
              ? externalAccent.withValues(alpha: 0.16)
              : const Color(0xFFE1F5FE));
    final tagFg = tag == 'Internal'
        ? theme.primaryColor
        : (isDark ? externalAccent : const Color(0xFF1565C0));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22.r,
              backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
              child: Icon(icon, color: theme.primaryColor),
            ),
            hSpace(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: tagBg,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                tag,
                style: TextStyle(fontWeight: FontWeight.w600, color: tagFg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
