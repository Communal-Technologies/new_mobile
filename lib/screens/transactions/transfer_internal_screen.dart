import 'dart:async';

import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class TransferInternalScreen extends StatefulWidget {
  const TransferInternalScreen({super.key, this.initialRecipient});

  final TransferFavorite? initialRecipient;

  @override
  State<TransferInternalScreen> createState() => _TransferInternalScreenState();
}

class _TransferInternalScreenState extends State<TransferInternalScreen> {
  final _accountNumberCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _repo = getIt<TransferRepository>();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _letterKeys = {};
  Timer? _accountDebounce;

  bool _isLoading = true;
  String? _error;
  bool _isSearchingAccount = false;
  bool _showTopSuggestionPanel = false;
  List<_InternalRow> _topAccountSuggestions = const [];

  List<TransferSuggestion> _internalMembers = const [];
  List<TransferBeneficiary> _beneficiaries = const [];
  List<String> _cooperativeTabs = const [];
  String _activeTab = 'Beneficiaries';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecipient;
    if (initial != null) {
      _accountNumberCtrl.text = initial.accountNumber;
    }
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
    _load();
  }

  @override
  void dispose() {
    _accountDebounce?.cancel();
    _accountNumberCtrl.dispose();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await Future.wait([
        _repo.fetchBankSuggestions(),
        _repo.fetchBeneficiaries(),
      ]);
      final allSuggestions = res[0] as List<TransferSuggestion>;
      final allBeneficiaries = res[1] as List<TransferBeneficiary>;

      final internalMembers =
          allSuggestions.where((e) => e.isInternal).toList(growable: false)
            ..sort(
              (a, b) => a.accountName.toLowerCase().compareTo(
                b.accountName.toLowerCase(),
              ),
            );
      final beneficiaries =
          allBeneficiaries.where((e) => e.isInternal).toList(growable: false)
            ..sort(
              (a, b) => a.accountName.toLowerCase().compareTo(
                b.accountName.toLowerCase(),
              ),
            );

      final coopNames = internalMembers
          .map((e) => e.cooperativeName.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final tabs = <String>['Beneficiaries', ...coopNames.take(10)];
      if (!mounted) return;
      setState(() {
        _internalMembers = internalMembers;
        _beneficiaries = beneficiaries;
        _cooperativeTabs = tabs;
        if (!_cooperativeTabs.contains(_activeTab))
          _activeTab = 'Beneficiaries';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_InternalRow> _currentRows() {
    final accountFilter = _accountNumberCtrl.text.trim();
    List<_InternalRow> rows;
    if (_activeTab == 'Beneficiaries') {
      rows = _beneficiaries
          .map(
            (b) => _InternalRow(
              accountId: b.accountId,
              accountName: b.accountName,
              accountNumber: b.accountNumber,
              cooperativeName: b.bankName,
              bankName: b.bankName,
              nipCode: b.nipCode,
            ),
          )
          .toList(growable: false);
    } else {
      rows = _internalMembers
          .where((m) => m.cooperativeName.trim() == _activeTab)
          .map(
            (m) => _InternalRow(
              accountId: m.accountId,
              accountName: m.accountName,
              accountNumber: m.accountNumber,
              cooperativeName: m.cooperativeName.trim(),
              bankName: m.bank,
              nipCode: m.nipCode,
            ),
          )
          .toList(growable: false);
    }

    if (_searchQuery.isNotEmpty) {
      rows = rows
          .where(
            (r) =>
                r.accountName.toLowerCase().contains(_searchQuery) ||
                r.accountNumber.toLowerCase().contains(_searchQuery),
          )
          .toList(growable: false);
    }
    if (accountFilter.isNotEmpty) {
      rows = rows
          .where((r) => r.accountNumber.contains(accountFilter))
          .toList(growable: false);
    }
    rows.sort(
      (a, b) =>
          a.accountName.toLowerCase().compareTo(b.accountName.toLowerCase()),
    );
    return rows;
  }

  Map<String, List<_InternalRow>> _groupedByLetter(List<_InternalRow> rows) {
    final map = <String, List<_InternalRow>>{};
    for (final r in rows) {
      final letter = r.accountName.trim().isEmpty
          ? '#'
          : r.accountName[0].toUpperCase();
      map.putIfAbsent(letter, () => <_InternalRow>[]).add(r);
    }
    return map;
  }

  void _jumpToLetter(String letter) {
    final key = _letterKeys[letter];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 200),
      alignment: 0.04,
      curve: Curves.easeOut,
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

  void _openAmount(_InternalRow row) {
    final fav = TransferFavorite(
      source: 'internal',
      accountId: row.accountId,
      bank: row.bankName,
      accountNumber: row.accountNumber,
      accountName: row.accountName,
      nipCode: row.nipCode,
    );
    context.pushNamed(
      'transfer-internal-amount',
      extra: {'favorite': fav.toJson()},
    );
  }

  void _onTopAccountNumberChanged(String value) {
    _accountDebounce?.cancel();
    final query = value.trim();
    if (query.length < 4) {
      setState(() {
        _isSearchingAccount = false;
        _showTopSuggestionPanel = false;
        _topAccountSuggestions = const [];
      });
      return;
    }
    setState(() {
      _isSearchingAccount = true;
      _showTopSuggestionPanel = true;
      _topAccountSuggestions = const [];
    });
    _accountDebounce = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      final rows =
          _internalMembers
              .map(
                (m) => _InternalRow(
                  accountId: m.accountId,
                  accountName: m.accountName,
                  accountNumber: m.accountNumber,
                  cooperativeName: m.cooperativeName.trim(),
                  bankName: m.bank,
                  nipCode: m.nipCode,
                ),
              )
              .where((r) => r.accountNumber.contains(query))
              .toList(growable: false)
            ..sort(
              (a, b) => a.accountName.toLowerCase().compareTo(
                b.accountName.toLowerCase(),
              ),
            );
      setState(() {
        _isSearchingAccount = false;
        _topAccountSuggestions = rows.take(8).toList(growable: false);
        _showTopSuggestionPanel = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _currentRows();
    final grouped = _groupedByLetter(rows);
    final letters = grouped.keys.toList()..sort();
    _letterKeys
      ..clear()
      ..addEntries(letters.map((l) => MapEntry(l, GlobalKey())));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Select Communal Account'),
      ),
      body: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 18.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEEF0),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: const Color(0xFFFFD5DA)),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: const Color(0xFFC62828),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        vSpace(10),
                      ],
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.all(14.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter Account Number',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            vSpace(8),
                            TextField(
                              controller: _accountNumberCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '10 Digit Account Number',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.35),
                                    width: 1.1,
                                  ),
                                ),
                              ),
                              onChanged: _onTopAccountNumberChanged,
                            ),
                            if (_showTopSuggestionPanel) ...[
                              vSpace(8),
                              if (_isSearchingAccount)
                                SizedBox(
                                  width: double.infinity,
                                  child: Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          999.r,
                                        ),
                                        child: Container(
                                          width: 220.w,
                                          height: 8.h,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF00D9FF),
                                                Color(0xFF00A8E8),
                                                Color(0xFFFFC107),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      vSpace(10),
                                      Text(
                                        'Searching Account...',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (_topAccountSuggestions.isEmpty)
                                Text(
                                  'Invalid account number, please enter a valid communal account',
                                  style: TextStyle(
                                    color: const Color(0xFFD32F2F),
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF742CE7,
                                    ).withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4.w,
                                    vertical: 2.h,
                                  ),
                                  child: Column(
                                    children: _topAccountSuggestions
                                        .map(
                                          (r) => ListTile(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 8.w,
                                                  vertical: 2.h,
                                                ),
                                            visualDensity:
                                                const VisualDensity(
                                                  horizontal: 0,
                                                  vertical: 1.1,
                                                ),
                                            onTap: () => _openAmount(r),
                                            leading: CircleAvatar(
                                              radius: 21.r,
                                              backgroundColor: const Color(
                                                0xFF8F6BFF,
                                              ),
                                              child: Text(
                                                _initials(r.accountName),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14.sp,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              r.accountName,
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            subtitle: Text(
                                              r.accountNumber,
                                              style: TextStyle(
                                                color: Colors.black54,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      vSpace(14),
                      Text(
                        'Search Account',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      vSpace(8),
                      CustomTextField(
                        controller: _searchCtrl,
                        hintText: 'Enter Account number or name',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF909090),
                        ),
                      ),
                      vSpace(10),
                      SizedBox(
                        height: 38.h,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _cooperativeTabs.length,
                          separatorBuilder: (_, __) => hSpace(8),
                          itemBuilder: (_, i) {
                            final t = _cooperativeTabs[i];
                            final active = _activeTab == t;
                            return GestureDetector(
                              onTap: () => setState(() => _activeTab = t),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 8.h,
                                ),
                                decoration: active
                                    ? BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      )
                                    : null,
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    color: active
                                        ? Colors.white
                                        : Theme.of(context).primaryColor,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      vSpace(8),
                      if (rows.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('No accounts found.'),
                        )
                      else
                        ...letters.map((letter) {
                          final section = grouped[letter]!;
                          return Column(
                            key: _letterKeys[letter],
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 8.h, bottom: 6.h),
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.sp,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              ...section.map(
                                (r) => Padding(
                                  padding: EdgeInsets.only(bottom: 8.h),
                                  child: ListTile(
                                    tileColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    onTap: () => _openAmount(r),
                                    leading: CircleAvatar(
                                      radius: 20.r,
                                      backgroundColor: const Color(0xFF8F6BFF),
                                      child: Text(
                                        _initials(r.accountName),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      r.accountName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${r.cooperativeName.isEmpty ? 'Communal' : r.cooperativeName} • ${r.accountNumber}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
                if (letters.isNotEmpty)
                  Positioned(
                    right: 2.w,
                    top: 86.h,
                    bottom: 16.h,
                    child: SafeArea(
                      child: Container(
                        width: 24.w,
                        padding: EdgeInsets.symmetric(vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: letters.map((l) {
                            return GestureDetector(
                              onTap: () => _jumpToLetter(l),
                              child: Text(
                                l,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                if (_isLoading)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Image.asset(
                          Images.loader,
                          width: 84.w,
                          height: 84.w,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _InternalRow {
  const _InternalRow({
    required this.accountId,
    required this.accountName,
    required this.accountNumber,
    required this.cooperativeName,
    required this.bankName,
    this.nipCode,
  });

  final String accountId;
  final String accountName;
  final String accountNumber;
  final String cooperativeName;
  final String bankName;
  final String? nipCode;
}
