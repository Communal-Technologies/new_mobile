import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money_formatter.dart';
import 'package:communal_mobile/data/mappers/transaction_history_mapper.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/data/repositories/transactions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/transactions/models/sample_transactions.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/screens/transactions/widgets/transaction_tile.dart';
import 'package:communal_mobile/screens/transactions/widgets/filter_category_bottomsheet.dart';
import 'package:communal_mobile/screens/transactions/widgets/filter_status_bottomsheet.dart';
import 'package:communal_mobile/screens/transactions/widgets/download_statement_bottomsheet.dart';
import 'package:communal_mobile/screens/transactions/transaction_history_filters.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late final TransactionsRepository _repo =
      TransactionsRepository(getIt<DioClient>());
  int _currentTabIndex = 0;
  int _currentNavIndex = 0;

  bool _loading = true;
  String? _error;
  List<TransactionListItem> _personalFlat = [];
  List<TransactionListItem> _ledgerFlat = [];
  String _filterDirection = 'All';
  String _filterPaymentType = 'All Categories';
  String _filterStatus = 'All Status';

  List<MapEntry<String, List<TransactionListItem>>> _personalMonthly = [];
  List<MapEntry<String, List<TransactionListItem>>> _ledgerMonthly = [];
  final Map<String, bool> _expandedPersonal = {};
  final Map<String, bool> _expandedLedger = {};

  String get _categoryFilterButtonLabel {
    if (_filterDirection == 'All' && _filterPaymentType == 'All Categories') {
      return 'All categories';
    }
    if (_filterDirection != 'All' && _filterPaymentType != 'All Categories') {
      return '$_filterDirection · $_filterPaymentType';
    }
    return _filterDirection != 'All' ? _filterDirection : _filterPaymentType;
  }

  String get _statusFilterButtonLabel =>
      _filterStatus == 'All Status' ? 'All statuses' : _filterStatus;

  List<TransactionListItem> _filteredFlatForCurrentTab() {
    final src = _currentTabIndex == 0 ? _personalFlat : _ledgerFlat;
    return applyTransactionHistoryFilters(
      src,
      direction: _filterDirection,
      paymentType: _filterPaymentType,
      statusLabel: _filterStatus,
    );
  }

  void _recomputeGrouped() {
    final pFiltered = applyTransactionHistoryFilters(
      _personalFlat,
      direction: _filterDirection,
      paymentType: _filterPaymentType,
      statusLabel: _filterStatus,
    );
    final lFiltered = applyTransactionHistoryFilters(
      _ledgerFlat,
      direction: _filterDirection,
      paymentType: _filterPaymentType,
      statusLabel: _filterStatus,
    );
    final pg = groupTransactionsByMonth(pFiltered);
    final lg = groupTransactionsByMonth(lFiltered);
    _personalMonthly = pg.entries.toList();
    _ledgerMonthly = lg.entries.toList();
    _expandedPersonal
      ..clear()
      ..addEntries(
        List.generate(
          _personalMonthly.length,
          (i) => MapEntry(_personalMonthly[i].key, i == 0),
        ),
      );
    _expandedLedger
      ..clear()
      ..addEntries(
        List.generate(
          _ledgerMonthly.length,
          (i) => MapEntry(_ledgerMonthly[i].key, i == 0),
        ),
      );
  }

  Future<void> _exportStatement(
    StatementExportRequest request,
    UserModel user,
  ) async {
    final items = _filteredFlatForCurrentTab();
    final sym = currencySymbolForUser(user);
    final accountLabel =
        _currentTabIndex == 0 ? 'Communal Personal' : 'Ledger Cooperative';
    final csv = buildTransactionStatementCsv(
      items: items,
      currencySymbol: sym,
      rangeStart: request.startInclusive,
      rangeEnd: request.endInclusive,
      accountLabel: accountLabel,
    );
    final lines = csv.split('\n');
    if (lines.length < 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions in this period for the current filters.'),
        ),
      );
      return;
    }
    if (request.delivery != 'Download') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Server email delivery is not set up yet. Use your share sheet to save or send the CSV.',
          ),
        ),
      );
    }
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final bytes = Uint8List.fromList(utf8.encode(csv));
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'text/csv',
            name: 'communal_statement_$stamp.csv',
          ),
        ],
        text: 'Communal transaction statement ($accountLabel)',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  bool _showLedgerTab(UserModel? user) {
    if (user == null) return false;
    final ln = user.ledgerNumber?.trim() ?? '';
    return user.hasCooperativeMembership && ln.isNotEmpty;
  }

  Future<void> _load() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Please sign in to view transactions.';
        });
      }
      return;
    }
    final user = auth.user;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final personal = await _repo.fetchPersonalHistoryMerged(user);
      final ledger = _showLedgerTab(user)
          ? await _repo.fetchLedgerHistoryOnly(user)
          : const <TransactionListItem>[];

      if (!mounted) return;
      setState(() {
        _personalFlat = personal;
        _ledgerFlat = ledger;
        if (!_showLedgerTab(user) && _currentTabIndex != 0) {
          _currentTabIndex = 0;
        }
        _recomputeGrouped();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<MapEntry<String, List<TransactionListItem>>> get _activeMonthly =>
      _currentTabIndex == 0 ? _personalMonthly : _ledgerMonthly;

  Map<String, bool> get _activeExpanded =>
      _currentTabIndex == 0 ? _expandedPersonal : _expandedLedger;

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
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.sp),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Transaction History',
            style: TextStyle(
              fontSize: 23.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: GestureDetector(
                onTap: () async {
                  final auth = context.read<AuthBloc>().state;
                  final u = auth is AuthAuthenticated ? auth.user : null;
                  final email = u?.email?.trim();
                  final req = await showModalBottomSheet<StatementExportRequest>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => DownloadStatementBottomSheet(
                      initialEmail: email,
                    ),
                  );
                  if (!context.mounted || req == null || u == null) return;
                  await _exportStatement(req, u);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download,
                        size: 18.sp,
                        color: Colors.grey.shade700,
                      ),
                      hSpace(6),
                      Text(
                        'Statement',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (prev, next) {
            if (prev is AuthAuthenticated && next is AuthAuthenticated) {
              return prev.user.id != next.user.id ||
                  prev.user.walletBalanceKobo != next.user.walletBalanceKobo ||
                  prev.user.ledgerNumber != next.user.ledgerNumber ||
                  prev.user.countryIso != next.user.countryIso ||
                  prev.user.walletCurrencyCode != next.user.walletCurrencyCode ||
                  prev.user.hasCooperativeMembership !=
                      next.user.hasCooperativeMembership;
            }
            return prev.runtimeType != next.runtimeType;
          },
          listener: (_, __) => _load(),
          builder: (context, authState) {
            final user = authState is AuthAuthenticated ? authState.user : null;
            final showLedger = _showLedgerTab(user);

            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16.sp),
                      ),
                      vSpace(16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                if (showLedger)
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTab(
                            'Communal (Personal)',
                            0,
                            theme,
                          ),
                        ),
                        Expanded(
                          child: _buildTab(
                            'Ledger (Cooperative)',
                            1,
                            theme,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                    child: Text(
                      'Communal (Personal)',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                  child: Row(
                    children: [
                      Flexible(
                        child: _buildFilterButton(
                          icon: Icons.filter_list,
                          label: _categoryFilterButtonLabel,
                          onTap: _openCategoryFilterSheet,
                        ),
                      ),
                      hSpace(12),
                      Flexible(
                        child: _buildFilterButton(
                          icon: null,
                          label: _statusFilterButtonLabel,
                          onTap: _openStatusFilterSheet,
                        ),
                      ),
                    ],
                  ),
                ),
                vSpace(8),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _activeMonthly.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: 120.h),
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 48.sp,
                                color: Colors.grey.shade400,
                              ),
                              vSpace(12),
                              Center(
                                child: Text(
                                  'No transactions yet',
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            itemBuilder: (_, index) => _buildMonthSection(
                              _activeMonthly[index].key,
                              _activeMonthly[index].value,
                              user != null
                                  ? currencySymbolForUser(user)
                                  : currencySymbolForCode('NGN'),
                            ),
                            separatorBuilder: (_, __) => vSpace(16),
                            itemCount: _activeMonthly.length,
                          ),
                  ),
                ),
              ],
            );
          },
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

  Widget _buildTab(String label, int index, ThemeData theme) {
    final isActive = _currentTabIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? theme.primaryColor : Colors.grey.shade600,
            ),
          ),
          vSpace(8),
          Container(
            height: 3.h,
            decoration: BoxDecoration(
              color: isActive ? theme.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCategoryFilterSheet() async {
    final result = await showModalBottomSheet<CategoryFilterResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FilterCategoryBottomSheet(
        initialDirection: _filterDirection,
        initialPaymentType: _filterPaymentType,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _filterDirection = result.direction;
      _filterPaymentType = result.paymentType;
      _recomputeGrouped();
    });
  }

  Future<void> _openStatusFilterSheet() async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FilterStatusBottomSheet(
        initialStatus: _filterStatus,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _filterStatus = result;
      _recomputeGrouped();
    });
  }

  Widget _buildFilterButton({
    IconData? icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18.sp, color: Colors.grey.shade700),
              hSpace(6),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            hSpace(4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18.sp,
              color: Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSection(
    String month,
    List<TransactionListItem> transactions,
    String currencySymbol,
  ) {
    final expanded = _activeExpanded;
    final isExpanded = expanded[month] ?? false;
    // API `type` is debit whenever the user is sender, even if the transfer
    // failed — exclude failed rows from In/Out totals (no balance movement).
    final incoming = transactions
        .where(
          (t) =>
              t.isCredit && t.details.status != TransactionStatus.failed,
        )
        .fold<double>(0, (sum, item) => sum + item.details.amount);
    final outgoing = transactions
        .where(
          (t) =>
              !t.isCredit && t.details.status != TransactionStatus.failed,
        )
        .fold<double>(0, (sum, item) => sum + item.details.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              expanded[month] = !isExpanded;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    Text(
                      month,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    hSpace(6),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: Colors.grey.shade600,
                      size: 22.sp,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'In: $currencySymbol${formatMoney(incoming)}',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                hSpace(12),
                Text(
                  'Out: $currencySymbol${formatMoney(outgoing)}',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          vSpace(8),
          for (int i = 0; i < transactions.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == transactions.length - 1 ? 0 : 8.h,
              ),
              child: TransactionTile(
                item: transactions[i],
                onTap: () => context.pushNamed(
                  'transaction-details',
                  extra: transactions[i].details,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
