import 'dart:async';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  bool _isSearchingAccount = false;
  bool _showTopSuggestionPanel = false;
  List<_InternalRow> _topAccountSuggestions = const [];

  List<TransferSuggestion> _internalMembers = const [];
  List<TransferBeneficiary> _beneficiaries = const [];
  List<String> _cooperativeTabs = const ['Beneficiaries'];
  String _activeTab = 'Beneficiaries';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecipient;
    if (initial != null) {
      _accountNumberCtrl.text = initial.accountNumber;
    }
    _accountNumberCtrl.addListener(_onAccountNumberFieldChanged);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
    _load();
  }

  @override
  void dispose() {
    _accountDebounce?.cancel();
    _accountNumberCtrl.removeListener(_onAccountNumberFieldChanged);
    _accountNumberCtrl.dispose();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    var internalMembers = <TransferSuggestion>[];
    var beneficiaries = <TransferBeneficiary>[];
    final authState = context.read<AuthBloc>().state;

    try {
      // Drop the signed-in user's own wallet account from the
      // suggestions: the recipient picker is for sending TO someone,
      // and self-transfers either fail at the backend or get caught
      // on the verify screen — either way the entry is misleading
      // because the user expects to see other people's accounts here.
      // Match by walletAccountNumber (canonical) and fall back to
      // walletAccountName when the wallet number isn't yet hydrated.
      final selfAcct = authState is AuthAuthenticated
          ? (authState.user.walletAccountNumber ?? '').trim()
          : '';
      final selfName = authState is AuthAuthenticated
          ? (authState.user.walletAccountName ?? '').trim().toLowerCase()
          : '';
      bool isSelf(TransferSuggestion s) {
        if (selfAcct.isNotEmpty && s.accountNumber.trim() == selfAcct) {
          return true;
        }
        if (selfName.isNotEmpty &&
            s.accountName.trim().toLowerCase() == selfName) {
          return true;
        }
        return false;
      }

      final allSuggestions = await _repo.fetchBankSuggestions();
      internalMembers = allSuggestions
          .where((e) => e.isInternal && !isSelf(e))
          .toList(growable: false)
        ..sort(
          (a, b) => a.accountName.toLowerCase().compareTo(
            b.accountName.toLowerCase(),
          ),
        );
    } catch (_) {
      // Keep screen usable: manual account entry + Continue still work.
    }

    try {
      final allBeneficiaries = await _repo.fetchBeneficiaries();
      beneficiaries =
          allBeneficiaries.where((e) => e.isInternal).toList(growable: false)
            ..sort(
              (a, b) => a.accountName.toLowerCase().compareTo(
                b.accountName.toLowerCase(),
              ),
            );
    } catch (_) {
      // Beneficiaries tab stays visible; list may be empty.
    }

    if (!mounted) return;
    final userCoopName = authState is AuthAuthenticated
        ? (authState.user.cooperativeName?.trim() ?? '')
        : '';
    final tabs = <String>[
      if (beneficiaries.isNotEmpty) 'Beneficiaries',
      if (userCoopName.isNotEmpty &&
          internalMembers.any((e) => e.cooperativeName.trim() == userCoopName))
        userCoopName,
    ];
    setState(() {
      _internalMembers = internalMembers;
      _beneficiaries = beneficiaries;
      _cooperativeTabs = tabs;
      if (!_cooperativeTabs.contains(_activeTab)) {
        _activeTab = _cooperativeTabs.isNotEmpty ? _cooperativeTabs.first : '';
      }
      _isLoading = false;
    });
  }

  void _onAccountNumberFieldChanged() {
    setState(() {});
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

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.all(14.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter Account Number',
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            vSpace(8),
                            TextField(
                              controller: _accountNumberCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: '10 Digit Account Number',
                                hintStyle: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor,
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
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontSize: 19.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (_topAccountSuggestions.isEmpty &&
                                  _internalMembers.isNotEmpty)
                                Text(
                                  'Invalid account number, please enter a valid communal account',
                                  style: TextStyle(
                                    color: const Color(0xFFD32F2F),
                                    fontSize: 19.sp,
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
                                                  fontSize: 17.sp,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              r.accountName,
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontSize: 19.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            subtitle: Text(
                                              r.accountNumber,
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                                fontSize: 17.sp,
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
                          fontSize: 19.sp,
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
                      if (_cooperativeTabs.length > 1) ...[
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
                                        : Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white.withValues(alpha: 0.85)
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
                      ], // end tabs conditional
                      vSpace(8),
                      if (rows.isNotEmpty)
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
                                    fontSize: 17.sp,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              ...section.map(
                                (r) => Padding(
                                  padding: EdgeInsets.only(bottom: 8.h),
                                  child: ListTile(
                                    tileColor: Theme.of(context).cardColor,
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
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              if (letters.isNotEmpty)
                Positioned(
                  right: 4.w,
                  // Sit below the search field + tab strip so the strip
                  // doesn't overlap the row of cooperative tabs at the
                  // top of the scroll view, and stop short of the
                  // bottom safe-area so it doesn't run into the system
                  // gesture bar / next-step CTA when one appears.
                  top: 220.h,
                  bottom: 32.h,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: letters.map((l) {
                        return GestureDetector(
                          onTap: () => _jumpToLetter(l),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.w),
                            child: Text(
                              l,
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Replaces the previous ad-hoc `Material(color: Colors.white …)`
        // overlay that rendered as a bright white veil on dark mode.
        // The shared `LoaderOverlay` already handles the dark scrim
        // and tints the loader GIF white when the active theme is
        // dark.
        if (_isLoading)
          const Positioned.fill(child: LoaderOverlay()),
      ],
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
