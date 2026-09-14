import 'dart:async';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:communal_mobile/core/utils/amount_input_formatter.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/ng_mobile_network.dart';
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
  const TransferExternalScreen({
    super.key,
    this.initialRecipient,
    this.initialAmount,
  });

  final TransferFavorite? initialRecipient;

  /// In major units. "Transfer again" carries the last amount here; it lands in
  /// the field and stays editable.
  final double? initialAmount;

  @override
  State<TransferExternalScreen> createState() => _TransferExternalScreenState();
}

class _TransferExternalScreenState extends State<TransferExternalScreen> {
  static const List<int> _quickAmounts = [
    1000, 3000, 5000, 10000, 15000, 20000, 30000, 50000, 100000,
  ];
  static const Color _verifiedGreen = Color(0xFF0FAA50);

  /// The fewest digits worth suggesting a bank for.
  static const int _minSuggestDigits = 3;

  /// The longest prefix sent for bank hints; the server caps it here too.
  static const int _hintPrefixDigits = 7;

  final _repo = getIt<TransferRepository>();
  final _favorites = getIt<TransferFavoritesPrefs>();

  final _accountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();

  List<TransferBank> _banks = const [];
  List<TransferSuggestion> _knownRecipients = const [];
  List<TransferSuggestion> _rawSuggestions = const [];
  List<TransferBank> _candidateBanks = const [];
  List<String> _hintCodes = const [];
  String _hintsFor = '';
  TransferBank? _selectedBank;

  /// True when the bank was picked for the member rather than by them, so a
  /// change to the number clears it instead of carrying a guess forward.
  bool _bankAutoDetected = false;
  TransferFavorite? _verifiedRecipient;
  bool _loadingBanks = false;
  String? _banksError;
  bool _loadingSuggestions = false;
  bool _verifying = false;
  bool _suggestionsDismissed = false;
  bool _initialResolved = false;
  Timer? _debounce;
  String _resolvedFor = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecipient;
    if (initial != null) {
      _accountCtrl.text = initial.accountNumber;
      _suggestionsDismissed = true;
    }
    final amount = widget.initialAmount;
    if (amount != null && amount > 0) {
      _amountCtrl.text = amount == amount.roundToDouble()
          ? AmountInputFormatter.formatInt(amount.round())
          : amount.toStringAsFixed(2);
    }
    _accountCtrl.addListener(_onAccountChanged);
    _amountCtrl.addListener(() => setState(() {}));
    _narrationCtrl.addListener(() => setState(() {}));
    _loadBanks();
    _loadKnownRecipients();
  }

  TransferBank? _matchBankByNip(String? nip) {
    final n = (nip ?? '').trim();
    if (n.isEmpty) return null;
    for (final b in _banks) {
      if (b.nipCode == n) return b;
    }
    return null;
  }

  TransferBank? _matchBankByName(String? name) {
    final n = (name ?? '').trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final b in _banks) {
      if (b.name.trim().toLowerCase() == n) return b;
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
      setState(() => _banks = rows);
      if (widget.initialRecipient != null && !_initialResolved) {
        unawaited(_resolveInitialRecipient());
      } else if (_accountCtrl.text.trim().length >= _minSuggestDigits) {
        _applyLocalMatches();
      }
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
      if (_accountCtrl.text.trim().length >= _minSuggestDigits &&
          !_suggestionsDismissed) {
        _applyLocalMatches();
      }
    } catch (_) {
      // A recipient list we could not load only costs the shortcut.
    }
  }

  /// "Transfer again": the account, its bank and the amount arrive filled in.
  /// Our own books are asked first, so a Communal wallet stays a book transfer;
  /// otherwise the bank carried over is confirmed by name enquiry.
  Future<void> _resolveInitialRecipient() async {
    final initial = widget.initialRecipient;
    if (initial == null || _initialResolved) return;
    _initialResolved = true;
    setState(() {
      _selectedBank ??=
          _matchBankByNip(initial.nipCode) ?? _matchBankByName(initial.bank);
    });
    final acct = _accountCtrl.text.trim();
    if (acct.length != 10) {
      setState(() => _suggestionsDismissed = false);
      _applyLocalMatches();
      return;
    }
    await _probeAccount(autoDetect: false);
    if (!mounted || _verifiedRecipient != null) return;
    if (_selectedBank != null) {
      await _verifyRecipient();
    } else {
      setState(() => _suggestionsDismissed = false);
      _applyLocalMatches();
    }
  }

  void _onAccountChanged() {
    setState(() {
      _suggestionsDismissed = false;
      _verifiedRecipient = null;
      if (_bankAutoDetected) {
        _selectedBank = null;
        _bankAutoDetected = false;
      }
    });
    _debounce?.cancel();
    final q = _accountCtrl.text.trim();
    if (q.length < _minSuggestDigits) {
      setState(() {
        _rawSuggestions = const [];
        _candidateBanks = const [];
        _resolvedFor = '';
      });
      return;
    }
    // Local matching is free, so it happens on the keystroke itself and the
    // panel is never empty while the debounce runs. The debounce guards the
    // lookups that cost a round trip.
    _applyLocalMatches();
    _debounce = Timer(const Duration(milliseconds: 300), _probeAccount);
  }

  /// Fills the panel from what this device already knows: the recipients whose
  /// number starts with what they have typed, then the banks the number most
  /// likely belongs to.
  ///
  /// Communal wallets are matched here too, not only external recipients. This
  /// is the screen for paying another bank, but the number being typed decides
  /// that, not the screen: an account on our own books belongs at the top of the
  /// panel so it is paid as a book transfer rather than over NIP.
  void _applyLocalMatches() {
    final q = _accountCtrl.text.trim();
    final matches = _knownRecipients
        .where((e) => e.accountNumber.startsWith(q))
        .toList(growable: false)
      ..sort((a, b) {
        if (a.isInternal == b.isInternal) return 0;
        return a.isInternal ? -1 : 1;
      });
    setState(() {
      _rawSuggestions = matches;
      _candidateBanks = _narrowedBanks(q, exclude: matches);
    });
  }

  List<String> _activeHintCodes(String q) =>
      _hintsFor.isNotEmpty && q.startsWith(_hintsFor) ? _hintCodes : const [];

  /// OPay, PalmPay and Moniepoint number personal accounts after the holder's
  /// phone number, so a number that starts like a mobile number is likely theirs.
  bool _looksLikePhoneAccount(String q) =>
      q.length >= _minSuggestDigits &&
      '789'.contains(q[0]) &&
      detectNgMobileNetwork(q) != null;

  bool _isPhoneNumberBank(TransferBank b) {
    final n = b.name.toLowerCase();
    return n.contains('opay') ||
        n.contains('paycom') ||
        n.contains('palmpay') ||
        n.contains('moniepoint');
  }

  /// Banks worth offering for the number as typed, likeliest first.
  ///
  /// A NUBAN does not contain its bank's code, so no digit of it names the bank.
  /// What narrows it early is evidence: the banks the platform has seen accounts
  /// with this prefix at, and whether the number reads like a phone-number
  /// account. Once all ten digits are in, the check digit rules out about nine
  /// banks in ten, and nothing that fails it is offered.
  List<TransferBank> _narrowedBanks(
    String accountNumber, {
    required List<TransferSuggestion> exclude,
  }) {
    if (_banks.isEmpty) return const [];
    final alreadyShown = exclude.map((e) => (e.nipCode ?? '').trim()).toSet();
    final nuban = isNubanShaped(accountNumber);
    final out = <TransferBank>[];
    final seen = <String>{};
    void add(TransferBank b) {
      if (alreadyShown.contains(b.nipCode)) return;
      if (nuban && !nubanMatchesBank(accountNumber, b.nipCode)) return;
      if (seen.add(b.nipCode)) out.add(b);
    }

    for (final code in _activeHintCodes(accountNumber)) {
      final b = _matchBankByNip(code);
      if (b != null) add(b);
    }
    if (_looksLikePhoneAccount(accountNumber)) {
      _banks.where(_isPhoneNumberBank).forEach(add);
    }
    // fetchBanks already returns the list usage-ranked, so order is preserved.
    _banks.where((b) => b.uses > 0).forEach(add);
    if (nuban) {
      for (final b in _banks) {
        if (out.length >= 5) break;
        add(b);
      }
    }
    return out.take(5).toList(growable: false);
  }

  Future<void> _loadBankHints(String q) async {
    final prefix =
        q.length > _hintPrefixDigits ? q.substring(0, _hintPrefixDigits) : q;
    if (prefix.length < _minSuggestDigits || _hintsFor == prefix) return;
    final codes = await _repo.fetchBankHints(prefix);
    if (!mounted || !_accountCtrl.text.trim().startsWith(prefix)) return;
    setState(() {
      _hintsFor = prefix;
      _hintCodes = codes;
    });
    if (!_suggestionsDismissed) _applyLocalMatches();
  }

  /// Names the account outright when we can, off our own records, and asks for
  /// the likely banks on the way.
  ///
  /// A wallet on our books makes this a book transfer — instant, free, and it
  /// would otherwise have gone out through NIP and been charged for. A
  /// recipient the member has paid before already has a counterparty id, so the
  /// name enquiry is skipped entirely.
  Future<void> _probeAccount({bool autoDetect = true}) async {
    if (!mounted) return;
    final q = _accountCtrl.text.trim();
    if (q.length < _minSuggestDigits) return;
    unawaited(_loadBankHints(q));
    if (q.length < 6 || _resolvedFor == q) return;
    if (q.length < 10) {
      try {
        await _searchCommunalAccounts(q);
      } catch (_) {
        // Nothing to show is the ordinary answer here — the member picks a bank.
      }
      return;
    }

    setState(() => _loadingSuggestions = true);
    TransferSuggestion? match;
    try {
      match = await _repo.resolveAccount(q);
    } catch (_) {
      match = null;
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
    if (!mounted || _accountCtrl.text.trim() != q) return;
    _resolvedFor = q;
    if (match == null) {
      if (autoDetect) await _autoDetectBank(q);
      return;
    }

    final found = match;
    final nip = (found.nipCode ?? '').trim();
    final bankName = found.bank.trim().isNotEmpty
        ? found.bank.trim()
        : (found.isInternal
              ? 'Communal'
              : (_matchBankByNip(nip)?.name ?? _selectedBank?.name ?? ''));
    setState(() {
      _rawSuggestions = const [];
      _candidateBanks = const [];
      _suggestionsDismissed = true;
      if (found.isExternal) {
        _selectedBank =
            _matchBankByNip(nip) ?? _matchBankByName(bankName) ?? _selectedBank;
        _bankAutoDetected = false;
      }
      _verifiedRecipient = TransferFavorite(
        source: found.isInternal ? 'internal' : 'external',
        accountId: found.isInternal
            ? found.accountId
            : (found.counterPartyId ?? ''),
        bank: bankName,
        accountNumber: found.accountNumber,
        accountName: found.accountName,
        nipCode: found.isInternal ? null : nip,
      );
    });
  }

  /// With all ten digits in and nothing on our books for the number, picks the
  /// bank for the member when the evidence points at one: the likeliest bank for
  /// the prefix that the number is valid at, or else the one bank they have paid
  /// before that it is valid at. The name enquiry then confirms the guess, and a
  /// wrong one quietly hands the choice back.
  Future<void> _autoDetectBank(String q) async {
    final chosen = _selectedBank;
    if (chosen != null) {
      if (nubanMatchesBank(q, chosen.nipCode)) await _verifyRecipient();
      return;
    }
    await _loadBankHints(q);
    if (!mounted || _accountCtrl.text.trim() != q) return;

    TransferBank? pick;
    for (final code in _activeHintCodes(q)) {
      final b = _matchBankByNip(code);
      if (b != null && nubanMatchesBank(q, b.nipCode)) {
        pick = b;
        break;
      }
    }
    if (pick == null) {
      final used = _banks
          .where((b) => b.uses > 0 && nubanMatchesBank(q, b.nipCode))
          .toList(growable: false);
      if (used.length == 1) pick = used.first;
    }
    if (pick == null) return;

    setState(() {
      _selectedBank = pick;
      _bankAutoDetected = true;
      _suggestionsDismissed = true;
    });
    await _verifyRecipient(silent: true);
  }

  /// Asks the server which Communal accounts begin with the digits typed so far.
  ///
  /// This is what the debounce buys before the tenth digit: a wallet on our books
  /// is recognised — from anywhere on the platform, not only the member's own
  /// cooperative — while the number is still being typed, so the member never
  /// gets sent down the NIP route for money that never leaves Communal. Rows join
  /// the local pool, which is what the next keystroke is matched against.
  Future<void> _searchCommunalAccounts(String q) async {
    final rows = await _repo.fetchBankSuggestions(query: q);
    if (!mounted || _accountCtrl.text.trim() != q) return;
    _resolvedFor = q;
    final seen = _knownRecipients.map((e) => e.accountNumber).toSet();
    final added = rows
        .where((e) => e.isInternal && seen.add(e.accountNumber))
        .toList(growable: false);
    if (added.isEmpty) return;
    _knownRecipients = [..._knownRecipients, ...added];
    if (!_suggestionsDismissed) _applyLocalMatches();
  }

  bool get _showSuggestionPanel {
    final q = _accountCtrl.text.trim();
    return q.length >= _minSuggestDigits && !_suggestionsDismissed;
  }

  List<_SuggestRow> get _suggestionRows {
    // Recipients the member has paid before come first — those are answers, not
    // guesses. Below them sit the banks the number most likely belongs to.
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

  String _suggestionBankLabel(TransferSuggestion s) {
    final bank = s.bank.trim();
    if (bank.isNotEmpty) return bank;
    if (s.isInternal) return 'Communal';
    return _matchBankByNip(s.nipCode)?.name ?? 'Bank account';
  }

  String _bankRowSubtitle(TransferBank b) {
    final q = _accountCtrl.text.trim();
    if (_activeHintCodes(q).contains(b.nipCode)) {
      return 'Likely bank for this number';
    }
    if (_isPhoneNumberBank(b) && _looksLikePhoneAccount(q)) {
      return 'Uses phone numbers as account numbers';
    }
    if (isNubanShaped(q)) return 'This number is valid at this bank';
    if (b.uses > 0) return "You've sent money here before";
    return 'Tap to check this number';
  }

  Future<void> _openBankPicker() async {
    final acct = _accountCtrl.text.trim();
    if (acct.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit account number first.')),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
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
      _bankAutoDetected = false;
      _rawSuggestions = const [];
      _suggestionsDismissed = true;
    });
    await _verifyRecipient();
  }

  /// The banks to surface at the top of the picker.
  ///
  /// The prefix's likely banks lead, then banks the typed number's check digit
  /// allows in the server's usage order, which counts the member's own settled
  /// transfers and so survives a reinstall. Locally saved recipients only fill
  /// out the tail, since a recency list of people is not a count of banks.
  List<TransferBank> _featuredBanks() {
    final acct = _accountCtrl.text.trim();
    final out = <TransferBank>[];
    final seen = <String>{};
    for (final code in _activeHintCodes(acct)) {
      final b = _matchBankByNip(code);
      if (b != null && nubanMatchesBank(acct, b.nipCode) && seen.add(b.nipCode)) {
        out.add(b);
      }
    }
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

  /// Confirms the selected bank holds the typed number. [silent] is for a bank
  /// the screen picked itself: a miss there is not the member's mistake, so it
  /// clears the guess and reopens the suggestions instead of raising an error.
  Future<void> _verifyRecipient({bool silent = false}) async {
    final bank = _selectedBank;
    final acct = _accountCtrl.text.trim();
    if (bank == null || acct.length != 10) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _verifying = true);
    try {
      // Our own books first, whatever bank the member picked. Asking the bank
      // before asking ourselves is how a number that is a Communal wallet ends up
      // with a counterparty minted for it and a NIP fee attached — for money that
      // never leaves the platform.
      final local = await _repo.resolveAccount(acct);
      if (!mounted) return;
      if (local != null && local.isInternal) {
        setState(() {
          _resolvedFor = acct;
          _verifiedRecipient = TransferFavorite(
            source: 'internal',
            accountId: local.accountId,
            bank: local.bank.trim().isNotEmpty ? local.bank.trim() : 'Communal',
            accountNumber: local.accountNumber,
            accountName: local.accountName,
          );
        });
        return;
      }

      final verified = await _repo.verifyAccount(
        bankCode: bank.nipCode,
        accountNumber: acct,
      );
      final cpId = await _repo.createCounterParty(
        bankCode: bank.nipCode,
        accountNumber: verified.accountNumber,
        accountName: verified.accountName,
      );
      if (!mounted || _accountCtrl.text.trim() != acct) return;
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
      if (silent) {
        setState(() {
          _verifiedRecipient = null;
          if (_bankAutoDetected) {
            _selectedBank = null;
            _bankAutoDetected = false;
          }
          _suggestionsDismissed = false;
        });
        _applyLocalMatches();
      } else {
        setState(() => _verifiedRecipient = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _onPickRecipient(TransferSuggestion s) {
    FocusManager.instance.primaryFocus?.unfocus();
    final nip = (s.nipCode ?? '').trim();
    final counterPartyId = (s.counterPartyId ?? '').trim();
    final bankName = _suggestionBankLabel(s);
    setState(() {
      _accountCtrl.text = s.accountNumber;
      _selectedBank = nip.isEmpty ? _selectedBank : _matchBankByNip(nip);
      _bankAutoDetected = false;
      _rawSuggestions = const [];
      _candidateBanks = const [];
      _suggestionsDismissed = true;
      _resolvedFor = s.accountNumber;
      if (s.isInternal) {
        // A Communal wallet is addressed by its deposit account id and needs no
        // bank, no counterparty and no name enquiry. Falling through to the
        // external branch here would mint a counterparty for it and charge the
        // member NIP to reach an account on our own books.
        _verifiedRecipient = TransferFavorite(
          source: 'internal',
          accountId: s.accountId,
          bank: bankName,
          accountNumber: s.accountNumber,
          accountName: s.accountName,
        );
      } else {
        // The row already carries the counterparty a NIP transfer is addressed
        // to. Verifying it again would ask the bank a question we know the
        // answer to.
        _verifiedRecipient = counterPartyId.isEmpty
            ? null
            : TransferFavorite(
                source: 'external',
                accountId: counterPartyId,
                bank: bankName,
                accountNumber: s.accountNumber,
                accountName: s.accountName,
                nipCode: nip,
              );
      }
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
      _bankAutoDetected = false;
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
    FocusManager.instance.primaryFocus?.unfocus();
    final fmt = AmountInputFormatter.formatInt(v);
    _amountCtrl.value = TextEditingValue(
      text: fmt,
      selection: TextSelection.collapsed(offset: fmt.length),
    );
    setState(() {});
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();
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
    final onSurface = theme.colorScheme.onSurface;

    final showPanel = _showSuggestionPanel;
    final rows = _suggestionRows;
    final verifiedBank = _verifiedRecipient?.bank.trim() ?? '';
    final bankLabel = _selectedBank?.name ??
        (verifiedBank.isNotEmpty ? verifiedBank : null);

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
                    color: onSurface,
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
                                            name: _suggestionBankLabel(suggestion),
                                            logoUrl: suggestion.logoUrl ??
                                                _matchBankByNip(suggestion.nipCode)
                                                    ?.logoUrl,
                                          ),
                                          title: Text(
                                            suggestion.accountName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18.sp,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${_suggestionBankLabel(suggestion)} • ${suggestion.accountNumber}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15.sp,
                                              color: onSurface.withValues(alpha: 0.7),
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
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18.sp,
                                            ),
                                          ),
                                          subtitle: Text(
                                            _bankRowSubtitle(bank),
                                            style: TextStyle(
                                              fontSize: 15.sp,
                                              color: onSurface.withValues(alpha: 0.7),
                                            ),
                                          ),
                                          onTap: () => _onPickBankRow(bank),
                                        ),
                                    },
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(10.w, 6.h, 10.w, 10.h),
                                    child: Material(
                                      // Card surface so the tile sits on the
                                      // suggestion panel cleanly in both themes.
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
                                                color: onSurface,
                                              ),
                                              hSpace(8),
                                              Text(
                                                'Show all Banks',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 17.sp,
                                                  color: onSurface,
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
                            color: onSurface.withValues(alpha: 0.6),
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
                              fillColor: theme.colorScheme.surfaceContainerHighest,
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
                                if (bankLabel != null) ...[
                                  BrandLogo(
                                    name: bankLabel,
                                    logoUrl: _selectedBank?.logoUrl,
                                    size: 28,
                                  ),
                                  hSpace(10),
                                ],
                                Expanded(
                                  child: Text(
                                    bankLabel ??
                                        (_loadingBanks
                                            ? 'Loading banks…'
                                            : "Select Recipient's Bank"),
                                    style: TextStyle(
                                      fontSize: 19.sp,
                                      color: bankLabel == null
                                          ? onSurface.withValues(alpha: 0.5)
                                          : onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: onSurface.withValues(alpha: 0.6),
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
                                      verifiedBank.isNotEmpty
                                          ? verifiedBank
                                          : (_selectedBank?.name ?? ''),
                                      style: TextStyle(
                                        fontSize: 17.sp,
                                        fontWeight: FontWeight.w700,
                                        color: onSurface,
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
                                  color: onSurface,
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
                          color: onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      vSpace(6),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: onSurface),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                          AmountInputFormatter(decimals: decimalsFor(currencyCode)),
                        ],
                        decoration: InputDecoration(
                          hintText: '0 ($currencyCode)',
                          hintStyle: TextStyle(
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
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
                          color: theme.colorScheme.surfaceContainerHighest,
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
                                    color: onSurface,
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
