import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/transactions/models/sample_transactions.dart';
import 'package:communal_mobile/screens/transactions/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _favoritesPrefs = getIt<TransferFavoritesPrefs>();
  List<TransferFavorite> _favorites = const [];
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    setState(() => _favorites = _favoritesPrefs.getAll());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentTransactions = SampleTransactions.recentTransactions
        .take(4)
        .toList();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
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
                        fontSize: 16.sp,
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
                    itemCount: _favorites.length > 10 ? 10 : _favorites.length,
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
                      fontSize: 16.sp,
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
              vSpace(90),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFFE9E9E9)),
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
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
            Text(
              f.accountNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.sp, color: Colors.black54),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.w),
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
        child: Row(
          children: [
            CircleAvatar(
              radius: 22.r,
              backgroundColor: const Color(0xFFF1EAFF),
              child: Icon(icon, color: const Color(0xFF7434FF)),
            ),
            hSpace(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: tag == 'Internal'
                    ? const Color(0xFFEDE4FF)
                    : const Color(0xFFE1F5FE),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                tag,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
