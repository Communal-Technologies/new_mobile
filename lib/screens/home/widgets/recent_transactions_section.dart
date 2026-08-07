import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/services/transaction_activity_service.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/local/home_wallet_prefs.dart';
import 'package:communal_mobile/data/repositories/transactions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/transactions/models/sample_transactions.dart';
import 'package:communal_mobile/screens/transactions/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class RecentTransactionsSection extends StatefulWidget {
  const RecentTransactionsSection({super.key});

  @override
  State<RecentTransactionsSection> createState() =>
      _RecentTransactionsSectionState();
}

class _RecentTransactionsSectionState extends State<RecentTransactionsSection> {
  late final TransactionsRepository _repo =
      TransactionsRepository(getIt<DioClient>());
  late final HomeWalletPrefs _walletPrefs = getIt<HomeWalletPrefs>();
  late final TransactionActivityService _activity =
      getIt<TransactionActivityService>();
  List<TransactionListItem> _items = const [];
  bool _loading = true;
  String? _error;

  /// A movement ping and the balance change it causes both ask for a reload.
  /// One fetch is enough, so a second request while one is in flight is dropped.
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    _walletPrefs.addListener(_onPrefsChanged);
    _activity.revision.addListener(_onActivity);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  /// A push told us the member's money moved. Reload rather than waiting for
  /// the wallet balance to change — an inbound deposit can be recorded before
  /// the balance propagates, and the two are not always in step.
  void _onActivity() {
    if (mounted) _load(showLoader: false);
  }

  @override
  void dispose() {
    _walletPrefs.removeListener(_onPrefsChanged);
    _activity.revision.removeListener(_onActivity);
    super.dispose();
  }

  /// [showLoader] false refreshes in place, leaving the current rows on screen.
  /// A background refresh triggered by a push must not blank a list the member
  /// is already reading, and must not replace it with an error if the network
  /// blips — the rows shown are still the last known good ones.
  Future<void> _load({bool showLoader = true}) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      if (mounted) {
        setState(() {
          _loading = false;
          _items = const [];
        });
      }
      return;
    }
    if (_inFlight) return;
    _inFlight = true;
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _repo.fetchPersonalHistoryMerged(auth.user);
      if (!mounted) return;
      setState(() {
        _items = list.take(5).toList(growable: false);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!showLoader) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, next) {
        if (prev is AuthAuthenticated && next is AuthAuthenticated) {
          return prev.user.walletBalanceKobo != next.user.walletBalanceKobo;
        }
        return prev.runtimeType != next.runtimeType;
      },
      listener: (_, state) {
        if (state is AuthAuthenticated) _load();
      },
      child: Builder(
        builder: (context) {
          final auth = context.read<AuthBloc>().state;
          final uid = auth is AuthAuthenticated ? auth.user.id.trim() : '';
          if (uid.isNotEmpty && !_walletPrefs.isBalanceVisible(uid)) {
            return const SizedBox.shrink();
          }
          final theme = Theme.of(context);
          final onSurface = theme.colorScheme.onSurface;
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
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
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
                      fontSize: 22.sp,
                      color: onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            vSpace(12),
            if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Center(
                  child: Image.asset(
                    Images.loader,
                    width: 52.w,
                    height: 52.w,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else if (_error != null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_items.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Text(
                  'No recent transactions',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, __) => vSpace(10),
                itemBuilder: (_, index) {
                  final item = _items[index];
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
        },
      ),
    );
  }
}
