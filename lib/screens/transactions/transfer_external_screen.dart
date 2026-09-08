import 'dart:async';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:communal_mobile/core/utils/amount_input_formatter.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/nuban.dart';
import 'package:communal_mobile/core/utils/tier_limit_check.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/brand_logo.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/transactions/transfer_external_bank_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

sealed class _SuggestRow {}

class _SuggestRecipient extends _SuggestRow {
  _SuggestRecipient(this.suggestion);
  final TransferSuggestion suggestion;
}

class _SuggestBank extends _SuggestRow {
  _SuggestBank(this.bank);
  final TransferBank bank;
}

class TransferExternalScreen extends StatefulWidget {
  const TransferExternalScreen({super.key, this.initialRecipient});

  final TransferFavorite? initialRecipient;

  @override
  State<TransferExternalScreen> createState() => _TransferExternalScreenState();
}

class _TransferExternalScreenState extends State<TransferExternalScreen> {
  static const List<int> _quickAmounts = [
    1000, 3000, 5000, 10000, 15000, 20000, 30000, 50000, 100000,
  ];
  static const Color _verifiedGreen = Color(0xFF0FAA50);

  final _repo = getIt<TransferRepository>();
  final _favorites = getIt<TransferFavoritesPrefs>();

  final _accountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();

  List<TransferBank> _banks = const [];
  List<TransferSuggestion> _knownRecipients = const [];
  List<TransferSuggestion> _rawSuggestions = const [];
  List<TransferBank> _candidateBanks = const [];
  TransferBank? _selectedBank;
  TransferFavorite? _verifiedRecipient;
  bool _loadingBanks = false;
  String? _banksError;
  bool _loadingSuggestions = false;
  bool _verifying = false;
  bool _suggestionsDismissed = false;
  Timer? _debounce;
  String _resolvedFor = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecipient;
    if (initial != null) {
      _accountCtrl.text = initial.accountNumber;
      _selectedBank = _matchBankByNip(initial.nipCode);
    }
    _accountCtrl.addListener(_onAccountChanged);
    _amountCtrl.addListener(() => setState(() {}));
    _narrationCtrl.addListener(() => setState(() {}));
    _loadBanks();
    _loadKnownRecipients();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_banks.isEmpty) return;
      if (_accountCtrl.text.trim().length == 10 && _selectedBank != null) {
        _verifyRecipient();
      }
    });
  }

  TransferBank? _matchBankByNip(String? nip) {
    final n = (nip ?? '').trim();
    if (n.isEmpty) return null;
    for (final b in _banks) {
      if (b.nipCode == n) return b;
    }
    return null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _accountCtrl.removeListener(_onAccountChanged);
    _accountCtrl.dispose();
    _amountCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBanks({bool forceRefresh = false}) async {
    setState(() {
      _loadingBanks = true;
      _banksError = null;
    });
    try {
      final rows = await _repo.fetchBanks(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _banks = rows;
        if (widget.initialRecipient != null) {
          _selectedBank ??= _matchBankByNip(widget.initialRecipient!.nipCode);
        }
      });
      if (_accountCtrl.text.trim().length >= 4) _applyLocalMatches();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _banksError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  /// The member's own recipients, held locally so a keystroke can be matched
  /// without a round-trip. The repository serves its cache immediately and
  /// revalidates behind us.
  Future<void> _loadKnownRecipients() async {
    try {
      final list = await _repo.cachedBankSuggestions();
      if (!mounted) return;
      setState(() => _knownRecipients = list);
      if (_accountCtrl.text.trim().length >= 4) _applyLocalMatches();
    } catch (_) {
      // A recipient list we could not load only costs the shortcut.
    }
  }

  void _onAccountChanged() {
    setState(() {
      _suggestionsDismissed = false;
      _verifiedRecipient = null;
    });
    _debounce?.cancel();
    final q = _accountCtrl.text.trim();
    if (q.length < 4) {
      setState(() {
        _rawSuggestions = const [];
        _candidateBanks = const [];
        _resolvedFor = '';
      });
      return;
    }
    // Local matching is free, so it happens on the keystroke itself and the
    // panel is never empty while the debounce runs. The debounce now guards the
    // one thing that costs something: the exact-number lookup.
    _applyLocalMatches();
    _debounce = Timer(const Duration(milliseconds: 380), _probeAccount);
  }

  /// Fills the panel from what this device already knows: the member's own
  /// recipients whose number starts with what they have typed, and — once all
  /// ten digits are in — the banks whose code could have produced that number's
  /// check digit, best-used first.
  void _applyLocalMatches() {
    final q = _accountCtrl.text.trim();
    final matches = _knownRecipients
        .where((e) => e.isExternal && e.accountNumber.startsWith(q))
        .toList(growable: false);
    setState(() {
      _rawSuggestions = matches;
      _candidateBanks = _narrowedBanks(q, exclude: matches);
    });
  }

  /// Banks worth offering for the number as typed.
  ///
  /// A NUBAN's check digit is computed from the bank's own code, so a complete
  /// ten digits rule out about nine banks in ten — that shortlist is the whole
  /// point of waiting for the member to finish typing. Before the tenth digit
  /// nothing can be ruled out, so the offer is the banks they actually use.
  List<TransferBank> _narrowedBanks(
    String accountNumber, {
    required List<TransferSuggestion> exclude,
  }) {
    if (_banks.isEmpty) return const [];
    final alreadyShown = exclude.map((e) => (e.nipCode ?? '').trim()).toSet();
    Iterable<TransferBank> pool = _banks.where(
      (b) => !alreadyShown.contains(b.nipCode),
    );
    if (isNubanShaped(accountNumber)) {
      pool = pool.where((b) => nubanMatchesBank(accountNumber, b.nipCode));
    } else {
      pool = pool.where((b) => b.uses > 0);
    }
    // fetchBanks already returns the list usage-ranked, so order is preserved.
    return pool.take(isNubanShaped(accountNumber) ? 5 : 3).toList(
      growable: false,
    );
  }

  /// Names the account outright when we can, off our own records.
  ///
  /// A wallet on our books makes this a book transfer — instant, free, and it
  /// would otherwise have gone out through NIP and been charged for. A
  /// recipient the member has paid before already has a counterparty id, so the
  /// name enquiry is skipped entirely.
  Future<void> _probeAccount() async {
    if (!mounted) return;
    final q = _accountCtrl.text.trim();
    if (q.length != 10 || _resolvedFor == q) return;
    setState(() => _loadingSuggestions = true);
    try {
      final match = await _repo.resolveAccount(q);
      if (!mounted || _accountCtrl.text.trim() != q) return;
      _resolvedFor = q;
      if (match == null) return;
      final nip = (match.nipCode ?? '').trim();
      setState(() {
        _rawSuggestions = const [];
        _candidateBanks = const [];
        _suggestionsDismissed = true;
        if (match.isExternal && nip.isNotEmpty) {
          _selectedBank = _matchBankByNip(nip) ?? _selectedBank;
        }
        _verifiedRecipient = TransferFavorite(
          source: match.isInternal ? 'internal' : 'external',
          accountId: match.isInternal
              ? match.accountId
              : (match.counterPartyId ?? ''),
          bank: match.bank.trim().isNotEmpty
              ? match.bank.trim()
              : (_selectedBank?.name ?? ''),
          accountNumber: match.accountNumber,
          accountName: match.accountName,
          nipCode: match.isInternal ? null : nip,
        );
      });
    } catch (_) {
      // Nothing to show is the ordinary answer here — the member picks a bank.
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  bool get _showSuggestionPanel {
    final q = _accountCtrl.text.trim();
    return q.length >= 4 && !_suggestionsDismissed;
  }

  List<_SuggestRow> get _suggestionRows {
    // Recipients the member has paid before come first — those are answers, not
    // guesses. Below them sit the banks that could have issued the number, which
    // is what the panel offers once there is nothing left to recognise. Dedupe by
    // account number (already deduped server-side, belt-and-braces here).
    final rows = <_SuggestRow>[];
    final seenAcct = <String>{};
    for (final s in _rawSuggestions) {
      if (rows.length >= 6) break;
      if (!seenAcct.add(s.accountNumber)) continue;
      rows.add(_SuggestRecipient(s));
    }
    for (final b in _candidateBanks) {
      if (rows.length >= 6) break;
      rows.add(_SuggestBank(b));
    }
    return rows;
  }

  Future<void> _openBankPicker() async {
    final acct = _accountCtrl.text.trim();
    if (acct.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit account number first.')),
      );
      return;
    }
    final featured = _featuredBanks();
    final picked = await Navigator.of(context).push<TransferBank>(
      MaterialPageRoute(
        builder: (ctx) => TransferExternalBankPickerScreen(
          banks: _banks,
          featuredBanks: featured,
          featuredTitle: isNubanShaped(acct)
              ? 'Likely for this account number'
              : 'Banks you transfer to',
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedBank = picked;
      _rawSuggestions = const [];
      _suggestionsDismissed = true;
    });
    await _verifyRecipient();
  }

  /// The banks to surface at the top of the picker.
  ///
  /// Narrowed by the typed number's check digit first — with ten digits in, a
  /// bank that could not have issued it does not belong at the top of the list —
  /// then in the server's usage order, which counts the member's own settled
  /// transfers and so survives a reinstall. Locally saved recipients only fill
  /// out the tail, since a recency list of people is not a count of banks.
  List<TransferBank> _featuredBanks() {
    final acct = _accountCtrl.text.trim();
    final out = <TransferBank>[];
    final seen = <String>{};
    final plausible = _banks
        .where((b) => nubanMatchesBank(acct, b.nipCode))
        .where((b) => isNubanShaped(acct) || b.uses > 0);
    for (final b in plausible) {
      if (out.length >= 10) break;
      if (seen.add(b.nipCode)) out.add(b);
    }
    for (final f in _favorites.getAll()) {
      if (out.length >= 10) break;
      if (f.isInternal) continue;
      final b = _matchBankByNip(f.nipCode);
      if (b != null && seen.add(b.nipCode)) out.add(b);
    }
    for (final b in _banks) {
      if (out.length >= 10) break;
      if (seen.add(b.nipCode)) out.add(b);
    }
    return out.take(10).toList(growable: false);
  }

  Future<void> _verifyRecipient() async {
    final bank = _selectedBank;
    final acct = _accountCtrl.text.trim();
    if (bank == null || acct.length != 10) return;
    setState(() => _verifying = true);
    try {
      final verified = await _repo.verifyAccount(
        bankCode: bank.nipCode,
        accountNumber: acct,
      );
      final cpId = await _repo.createCounterParty(
        bankCode: bank.nipCode,
        accountNumber: verified.accountNumber,
        accountName: verified.accountName,
      );
      if (!mounted) return;
      final bankName = verified.bankName?.trim().isNotEmpty == true
          ? verified.bankName!.trim()
          : bank.name;
      setState(() {
        _verifiedRecipient = TransferFavorite(
          source: 'external',
          accountId: cpId,
          bank: bankName,
          accountNumber: verified.accountNumber,
          accountName: verified.accountName,
          nipCode: bank.nipCode,
        );
      });
      // The recipient list is what the next keystroke is matched against, so a
      // recipient just minted belongs in it now rather than after a refresh.
      _repo.rememberSuggestion(
        TransferSuggestion(
          source: 'external',
          accountId: '',
          bank: bankName,
          cooperativeName: '',
          accountNumber: verified.accountNumber,
          accountName: verified.accountName,
          nipCode: bank.nipCode,
          counterPartyId: cpId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifiedRecipient = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _onPickRecipient(TransferSuggestion s) {
    final nip = (s.nipCode ?? '').trim();
    final counterPartyId = (s.counterPartyId ?? '').trim();
    setState(() {
      _accountCtrl.text = s.accountNumber;
      _selectedBank = nip.isEmpty ? _selectedBank : _matchBankByNip(nip);
      _rawSuggestions = const [];
      _candidateBanks = const [];
      _suggestionsDismissed = true;
      _resolvedFor = s.accountNumber;
      // The row already carries the counterparty a NIP transfer is addressed to.
      // Verifying it again would ask the bank a question we know the answer to.
      _verifiedRecipient = counterPartyId.isEmpty
          ? null
          : TransferFavorite(
              source: 'external',
              accountId: counterPartyId,
              bank: s.bank.trim().isNotEmpty
                  ? s.bank.trim()
                  : (_selectedBank?.name ?? ''),
              accountNumber: s.accountNumber,
              accountName: s.accountName,
              nipCode: nip,
            );
    });
    if (_verifiedRecipient == null &&
        _selectedBank != null &&
        _accountCtrl.text.trim().length == 10) {
      _verifyRecipient();
    }
  }

  void _onPickBankRow(TransferBank b) {
    setState(() {
      _selectedBank = b;
      _rawSuggestions = const [];
      _candidateBanks = const [];
      _suggestionsDismissed = true;
    });
    if (_accountCtrl.text.trim().length == 10) {
      _verifyRecipient();
    }
  }

  /// User's resolved currency from the auth profile (defaults to NGN when
  /// pre-auth or undeterminable). Audit M20 leaf migration — replaces the
  /// hardcoded `* 100` kobo math.
  String _resolvedCurrency() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      return resolveCurrencyCode(auth.user);
    }
    return 'NGN';
  }

  int? _amountMinor(String currency) {
    // Parse the typed major-unit value (supports decimals e.g. 550.50) into
    // integer minor units. Money.tryParseMajor strips the thousands commas.
    final money = Money.tryParseMajor(_amountCtrl.text, currency);
    if (money == null || money.amountMinor <= 0) return null;
    return money.amountMinor;
  }

  bool get _continueEnabled {
    if (_verifiedRecipient == null) return false;
    return _amountMinor(_resolvedCurrency()) != null;
  }

  void _applyQuickAmount(int v) {
    final fmt = AmountInputFormatter.formatInt(v);
    _amountCtrl.value = TextEditingValue(
      text: fmt,
      selection: TextSelection.collapsed(offset: fmt.length),
    );
    setState(() {});
  }

  void _continue() {
    final v = _verifiedRecipient;
    if (v == null || !_continueEnabled) return;
    final currency = _resolvedCurrency();
    final amountMinor = _amountMinor(currency);
    if (amountMinor == null) return;

    // Audit M21: bail before navigating if the amount can't possibly
    // succeed given the user's tier (KYC not done, or amount > daily
    // cap). Saves a wasted round-trip and gives the user a clearer
    // message than the backend's generic 4xx.
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      final tierError = checkTransferAgainstTierLimits(
        user: auth.user,
        amountMinor: amountMinor,
        currency: currency,
      );
      if (tierError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tierError)));
        return;
      }
    }

    context.pushNamed(
      'transfer-internal-review',
      extra: {
        'favorite': v.toJson(),
        'amountMinor': amountMinor,
        'currency': currency,
        'narration': _narrationCtrl.text.trim(),
        'saveAsBeneficiary': false,
        // A number that turned out to be a Communal wallet goes out as a book
        // transfer: it is instant, it carries no NIP fee, and sending it over
        // NIP would charge the member to reach an account on our own books.
        'useExternalNipFlow': !v.isInternal,
      },
    );
  }

  Widget _bankLeadingIcon({required String name, String? logoUrl}) {
    return BrandLogo(name: name, logoUrl: logoUrl, size: 48);
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isOnline = context.watch<ConnectivityCubit>().isConnected;
    final currencyCode =
        authState is AuthAuthenticated ? resolveCurrencyCode(authState.user) : 'NGN';
    final display = authState is AuthAuthenticated
        ? walletCurrencyDisplay(authState.user)
        : activeCurrency.display;
    final theme = Theme.of(context);
    final suggestBg = theme.primaryColor.withValues(alpha: 0.10);

    final showPanel = _showSuggestionPanel;
    final rows = _suggestionRows;

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => context.pop(),
            ),
            title: Row(
              children: [
                Text(
                  'To Other Bank Accounts',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
              child: SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: (isOnline && _continueEnabled) ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _whiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: _accountCtrl,
                        keyboardType: TextInputType.number,
                        labelText: 'Account number',
                        hintText: '10 Digits Account Number',
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      if (showPanel) ...[
                        vSpace(8),
                        if (_loadingSuggestions)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: Center(
                              child: Image.asset(
                                Images.loader,
                                width: 44,
                                height: 44,
                                gaplessPlayback: true,
                              ),
                            ),
                          )
                        else ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10.r),
                            child: ColoredBox(
                              color: suggestBg,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final r in rows)
                                    switch (r) {
                                      _SuggestRecipient(:final suggestion) =>
                                        ListTile(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 2.h,
                                          ),
                                          minLeadingWidth: 52.w,
                                          leading: _bankLeadingIcon(
                                            name: suggestion.bank,
                                            logoUrl: suggestion.logoUrl,
                                          ),
                                          title: Text(
                                            suggestion.bank,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 19.sp,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${suggestion.accountName} • ${suggestion.accountNumber}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 17.sp,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          onTap: () => _onPickRecipient(suggestion),
                                        ),
                                      _SuggestBank(:final bank) => ListTile(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 2.h,
                                          ),
                                          minLeadingWidth: 52.w,
                                          leading: _bankLeadingIcon(
                                            name: bank.name,
                                            logoUrl: bank.logoUrl,
                                          ),
                                          title: Text(
                                            bank.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 19.sp,
                                            ),
                                          ),
                                          subtitle: Text(
                                            bank.uses > 0
                                                ? 'You transfer here often'
                                                : 'Tap to check this number',
                                            style: TextStyle(
                                              fontSize: 17.sp,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                          onTap: () => _onPickBankRow(bank),
                                        ),
                                    },
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(10.w, 6.h, 10.w, 10.h),
                                    child: Material(
                                      // Was hard-coded white — read as a
                                      // pure-white tile on dark mode.
                                      // Use the card surface so it sits
                                      // on the suggest panel cleanly in
                                      // both themes.
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(10.r),
                                      child: InkWell(
                                        onTap: _openBankPicker,
                                        borderRadius: BorderRadius.circular(10.r),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 10.h,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.account_balance,
                                                size: 22.sp,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                              hSpace(8),
                                              Text(
                                                'Show all Banks',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 17.sp,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (!showPanel) ...[
                        vSpace(14),
                        Text(
                          'Select Bank',
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        vSpace(6),
                        if (_banksError != null) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEF0),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: const Color(0xFFD7263D)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFD7263D),
                                  size: 18,
                                ),
                                hSpace(8),
                                Expanded(
                                  child: Text(
                                    _banksError!,
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      color: const Color(0xFFD7263D),
                                    ),
                                  ),
                                ),
                                hSpace(8),
                                GestureDetector(
                                  onTap: () =>
                                      _loadBanks(forceRefresh: true),
                                  child: Text(
                                    'Retry',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFD7263D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          vSpace(8),
                        ],
                        InkWell(
                          onTap: _loadingBanks ? null : _openBankPicker,
                          borderRadius: BorderRadius.circular(12.r),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 14.h,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                    color: Theme.of(context).dividerColor),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedBank?.name ??
                                        (_loadingBanks ? 'Loading banks…' : "Select Recipient's Bank"),
                                    style: TextStyle(
                                      fontSize: 19.sp,
                                      color: _selectedBank == null
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_verifiedRecipient != null) ...[
                        vSpace(12),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: _verifiedGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: _verifiedGreen.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _verifiedRecipient!.bank,
                                      style: TextStyle(
                                        fontSize: 17.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.check_circle, color: _verifiedGreen, size: 18.sp),
                                  hSpace(4),
                                  Text(
                                    'verified',
                                    style: TextStyle(
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.w700,
                                      color: _verifiedGreen,
                                    ),
                                  ),
                                ],
                              ),
                              vSpace(8),
                              Text(
                                '${_verifiedRecipient!.accountName} • ${_verifiedRecipient!.accountNumber}',
                                style: TextStyle(
                                  fontSize: 19.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                vSpace(14),
                _whiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      vSpace(6),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                          AmountInputFormatter(decimals: decimalsFor(currencyCode)),
                        ],
                        decoration: InputDecoration(
                          hintText: '0 ($currencyCode)',
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
                            borderSide: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      vSpace(10),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: _quickAmounts.map((v) {
                            return InkWell(
                              onTap: () => _applyQuickAmount(v),
                              borderRadius: BorderRadius.circular(16.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 10.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                child: Text(
                                  display.adorn(
                                    v >= 1000 ? '${v ~/ 1000}k' : '$v',
                                  ),
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      vSpace(14),
                      CustomTextField(
                        controller: _narrationCtrl,
                        labelText: 'Narration',
                        hintText: 'What is this for?',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_verifying)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Colors.transparent,
                child: Center(
                  child: Image.asset(
                    Images.loader,
                    width: 52,
                    height: 52,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

