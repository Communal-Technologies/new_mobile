import 'package:communal_mobile/core/utils/server_time.dart';
import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/mappers/transaction_history_mapper.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:dio/dio.dart';

class TransferSuggestion {
  const TransferSuggestion({
    required this.source,
    required this.accountId,
    required this.bank,
    required this.cooperativeName,
    required this.accountNumber,
    required this.accountName,
    this.nipCode,
    this.counterPartyId,
    this.logoUrl,
  });

  final String source; // internal | external
  final String accountId;
  final String bank;
  final String cooperativeName;
  final String accountNumber;
  final String accountName;
  final String? nipCode;

  /// The Anchor counterparty id an external suggestion already has, which is
  /// what a NIP transfer is actually addressed to. Its absence is why external
  /// suggestions never reached the screen: the row carries `counter_party_id`
  /// and no `account_id`, so filtering on a non-empty account id discarded
  /// every one of them.
  final String? counterPartyId;

  /// Absolute URL to the bank's mark, or null when we hold none — see
  /// [BrandLogo], which draws initials rather than expecting a placeholder.
  final String? logoUrl;

  bool get isInternal => source.trim().toLowerCase() == 'internal';
  bool get isExternal => source.trim().toLowerCase() == 'external';

  /// Whether this row is enough to address a transfer without asking the bank
  /// who owns the account again.
  bool get isPayable => isInternal
      ? accountId.trim().isNotEmpty
      : (counterPartyId ?? '').trim().isNotEmpty;

  factory TransferSuggestion.fromJson(Map<String, dynamic> json) {
    return TransferSuggestion(
      source: json['source']?.toString() ?? '',
      accountId: json['account_id']?.toString() ?? '',
      bank: json['bank']?.toString() ?? '',
      cooperativeName: json['cooperative_name']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      nipCode: json['nipCode']?.toString(),
      counterPartyId: json['counter_party_id']?.toString(),
      logoUrl: json['logo_url']?.toString(),
    );
  }
}

class TransferBank {
  const TransferBank({
    required this.name,
    required this.nipCode,
    this.uses = 0,
    this.logoUrl,
  });

  final String name;
  final String nipCode;

  /// How many settled transfers this member has sent to the bank, counted
  /// server-side off their own history. The list arrives already sorted by it;
  /// the count is kept so a screen can tell a bank the member actually uses
  /// from one that merely sorts near the top.
  final int uses;

  /// Absolute URL to the bank's mark. Absent for most of the 618 banks Anchor
  /// lists, which is why [BrandLogo] treats the monogram as a normal rendering.
  final String? logoUrl;

  factory TransferBank.fromJson(Map<String, dynamic> json) {
    // Two shapes in the wild:
    //
    // 1. New (BankRegistryManager → AnchorNigerianBankRegistry):
    //      { code: "058", label: "GTB", metadata: { nipCode, cbnCode } }
    //
    // 2. Legacy (raw Anchor pass-through some flows still use):
    //      { id, attributes: { name, nipCode, cbnCode } }
    //
    // Read the new shape first because that's what /transfer/banks
    // currently returns; fall through to attributes for anything
    // still emitting the old format. Dropping the legacy branch
    // entirely silently empties the picker (which is what user
    // reported: list-not-loading was actually list-empty-after-parse).
    final label = json['label']?.toString();
    final code = json['code']?.toString();
    if (label != null && label.isNotEmpty) {
      final meta = (json['metadata'] is Map)
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{};
      final nip =
          meta['nipCode']?.toString() ??
          code ??
          meta['cbnCode']?.toString() ??
          '';
      return TransferBank(
        name: label,
        nipCode: nip,
        uses: (json['uses'] as num?)?.toInt() ?? 0,
        logoUrl: json['logo_url']?.toString(),
      );
    }

    final attr = (json['attributes'] is Map)
        ? Map<String, dynamic>.from(json['attributes'] as Map)
        : const <String, dynamic>{};
    return TransferBank(
      name: attr['name']?.toString() ?? '',
      nipCode: attr['nipCode']?.toString() ?? attr['cbnCode']?.toString() ?? '',
      uses: (json['uses'] as num?)?.toInt() ?? 0,
      logoUrl: json['logo_url']?.toString(),
    );
  }
}

class AccountVerificationResult {
  const AccountVerificationResult({
    required this.accountName,
    required this.accountNumber,
    required this.bankCode,
    this.bankName,
  });

  final String accountName;
  final String accountNumber;
  final String bankCode;
  final String? bankName;

  factory AccountVerificationResult.fromJson(
    Map<String, dynamic> json, {
    required String fallbackBankCode,
    required String fallbackAccountNumber,
  }) {
    final attr = (json['attributes'] is Map)
        ? Map<String, dynamic>.from(json['attributes'] as Map)
        : <String, dynamic>{};
    return AccountVerificationResult(
      accountName: attr['accountName']?.toString() ?? '',
      accountNumber: attr['accountNumber']?.toString() ?? fallbackAccountNumber,
      bankCode: attr['bankCode']?.toString() ?? fallbackBankCode,
      bankName: (attr['bank'] is Map)
          ? (attr['bank']['name']?.toString())
          : null,
    );
  }
}

class TransferInitiationResult {
  const TransferInitiationResult({
    required this.transferId,
    required this.reference,
    required this.status,
    required this.type,
    this.failureReason,
  });

  final String transferId;
  final String reference;
  final String status;
  final String type;
  final String? failureReason;

  factory TransferInitiationResult.fromJson(
    Map<String, dynamic> json, {
    required String fallbackType,
  }) {
    final attr = (json['attributes'] is Map)
        ? Map<String, dynamic>.from(json['attributes'] as Map)
        : <String, dynamic>{};
    final fr = attr['failureReason'] ?? attr['failure_reason'];
    return TransferInitiationResult(
      transferId: json['id']?.toString() ?? '',
      reference: attr['reference']?.toString() ?? '',
      status: attr['status']?.toString() ?? 'PENDING',
      type: json['type']?.toString() ?? fallbackType,
      failureReason: fr?.toString(),
    );
  }
}

/// Normalized transfer row from `GET /members/transfer/transactions/{id}/status`.
class RemoteTransferStatus {
  const RemoteTransferStatus({
    required this.statusRaw,
    required this.reference,
    this.failureReason,
    this.amountKobo,
    this.providerOccurredAt,
  });

  final String statusRaw;
  final String reference;
  final String? failureReason;

  /// Anchor amount in kobo when present.
  final int? amountKobo;
  final DateTime? providerOccurredAt;

  factory RemoteTransferStatus.fromDataJson(Map<String, dynamic> json) {
    final rawAmt = json['amount'];
    int? kobo;
    if (rawAmt is int) {
      kobo = rawAmt;
    } else if (rawAmt is num) {
      kobo = rawAmt.round();
    }
    final updated = json['updated_at']?.toString();
    final created = json['created_at']?.toString();
    final when =
        parseServerTime(updated) ?? parseServerTime(created);
    return RemoteTransferStatus(
      statusRaw: json['status']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      failureReason: json['failure_reason']?.toString(),
      amountKobo: kobo,
      providerOccurredAt: when,
    );
  }
}

class TransferBeneficiary {
  const TransferBeneficiary({
    required this.accountId,
    required this.accountNumber,
    required this.accountName,
    required this.bankName,
    required this.type,
    this.nipCode,
    this.logoUrl,
  });

  final String accountId;
  final String accountNumber;
  final String accountName;
  final String bankName;
  final String type; // internal | external
  final String? nipCode;

  /// Absolute URL to the bank's mark, or null when we hold none — see
  /// [BrandLogo], which draws initials rather than expecting a placeholder.
  final String? logoUrl;

  bool get isInternal => type.trim().toLowerCase() == 'internal';

  factory TransferBeneficiary.fromJson(Map<String, dynamic> json) {
    return TransferBeneficiary(
      accountId: json['account_id']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      nipCode: json['nip_code']?.toString(),
      logoUrl: json['logo_url']?.toString(),
    );
  }
}

class NipFeeResult {
  const NipFeeResult({
    required this.fee,
    required this.totalDebit,
    required this.currency,
  });

  final int fee;
  final int totalDebit;
  final String currency;

  factory NipFeeResult.fromJson(Map<String, dynamic> json) {
    return NipFeeResult(
      fee: (json['fee'] as num?)?.toInt() ?? 0,
      totalDebit: (json['total_debit'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'NGN',
    );
  }
}

class TransferRepository {
  TransferRepository(this._dioClient);

  final DioClient _dioClient;

  // In-memory cache for the bank list. Banks rarely change and the
  // payload is the same for every user, so re-fetching on every
  // external-transfer screen open just burns a network round-trip
  // (and on a flaky link, leaves the picker empty). Cache lives for
  // the lifetime of the singleton repository (which is app session)
  // and is invalidated by passing forceRefresh: true.
  static const Duration _bankCacheTtl = Duration(hours: 24);

  /// The catalogue barely moves, but the per-member usage ranking on it does —
  /// it changes with every transfer the member makes. So a cache this old is
  /// still served immediately and refreshed behind the screen, rather than
  /// leaving the ordering a day out of date or making the picker wait.
  static const Duration _bankRevalidateAfter = Duration(minutes: 5);
  List<TransferBank>? _cachedBanks;
  DateTime? _cachedBanksAt;
  Future<List<TransferBank>>? _banksInFlight;

  Future<List<TransferBank>> fetchBanks({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedBanks != null && _cachedBanksAt != null) {
      final age = DateTime.now().difference(_cachedBanksAt!);
      if (age < _bankCacheTtl) {
        if (age >= _bankRevalidateAfter) {
          _refreshBanksInBackground();
        }
        return _cachedBanks!;
      }
    }
    final inFlight = _banksInFlight;
    if (inFlight != null && !forceRefresh) return inFlight;
    final future = _fetchBanksFromServer();
    _banksInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_banksInFlight, future)) _banksInFlight = null;
    }
  }

  void _refreshBanksInBackground() {
    if (_banksInFlight != null) return;
    final future = _fetchBanksFromServer();
    _banksInFlight = future;
    future
        .catchError((_) => _cachedBanks ?? const <TransferBank>[])
        .whenComplete(() {
          if (identical(_banksInFlight, future)) _banksInFlight = null;
        });
  }

  Future<List<TransferBank>> _fetchBanksFromServer() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.transferBanks);
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        throw Exception('Could not load bank list.');
      }
      final raw = data['data'];
      if (raw is! List) return const [];
      final parsed = raw
          .whereType<Map>()
          .map((e) => TransferBank.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.name.trim().isNotEmpty && e.nipCode.trim().isNotEmpty)
          .toList(growable: false);
      // Only overwrite the cache when the response actually contained
      // banks; an empty response (transient backend hiccup) shouldn't
      // poison a perfectly good cache from the previous fetch.
      if (parsed.isNotEmpty) {
        _cachedBanks = parsed;
        _cachedBanksAt = DateTime.now();
      }
      return parsed;
    } on DioException catch (e) {
      // Network/4xx/5xx — fall back to the cached list (if any) so
      // the user can still pick a bank rather than seeing an empty
      // picker. Throw only when there is nothing to show.
      if (_cachedBanks != null && _cachedBanks!.isNotEmpty) {
        return _cachedBanks!;
      }
      throw Exception(_messageFromDio(e));
    }
  }

  Future<List<TransferSuggestion>> fetchBankSuggestions({String? query}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.transferBankSuggestions,
        queryParameters: {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      );
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        throw Exception('Could not load transfer recipients.');
      }
      final rawList = data['data'];
      if (rawList is! List) return const [];
      return rawList
          .whereType<Map>()
          .map((e) => TransferSuggestion.fromJson(Map<String, dynamic>.from(e)))
          .where(
            (e) =>
                e.isPayable &&
                e.accountName.trim().isNotEmpty &&
                e.accountNumber.trim().isNotEmpty,
          )
          .toList(growable: false);
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  // The recipient list a member can be shown while they type. It is small, it
  // is theirs, and it is now served from our own tables, so it is held here and
  // filtered locally: matching on the fourth digit typed has to be instant, and
  // it cannot be if every keystroke is a round-trip.
  static const Duration _suggestionCacheTtl = Duration(minutes: 15);
  static const Duration _suggestionRevalidateAfter = Duration(minutes: 2);
  List<TransferSuggestion>? _cachedSuggestions;
  DateTime? _cachedSuggestionsAt;
  Future<List<TransferSuggestion>>? _suggestionsInFlight;

  /// The member's full recipient list, served from cache when there is one and
  /// refreshed in the background once it is a couple of minutes old — a
  /// recipient they paid on another device should turn up without a restart.
  Future<List<TransferSuggestion>> cachedBankSuggestions({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedSuggestions != null && _cachedSuggestionsAt != null) {
      final age = DateTime.now().difference(_cachedSuggestionsAt!);
      if (age < _suggestionCacheTtl) {
        if (age >= _suggestionRevalidateAfter) refreshSuggestionsInBackground();
        return _cachedSuggestions!;
      }
    }
    final inFlight = _suggestionsInFlight;
    if (inFlight != null && !forceRefresh) return inFlight;
    final future = _loadSuggestions();
    _suggestionsInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_suggestionsInFlight, future)) _suggestionsInFlight = null;
    }
  }

  /// Warms or revalidates the list without making anything wait on it, and
  /// without letting a failure surface as an unhandled error — a stale list is
  /// a better transfer screen than an empty one.
  void refreshSuggestionsInBackground() {
    if (_suggestionsInFlight != null) return;
    final future = _loadSuggestions();
    _suggestionsInFlight = future;
    future
        .catchError((_) => _cachedSuggestions ?? const <TransferSuggestion>[])
        .whenComplete(() {
          if (identical(_suggestionsInFlight, future)) {
            _suggestionsInFlight = null;
          }
        });
  }

  Future<List<TransferSuggestion>> _loadSuggestions() async {
    final fetched = await fetchBankSuggestions();
    if (fetched.isNotEmpty || _cachedSuggestions == null) {
      _cachedSuggestions = fetched;
      _cachedSuggestionsAt = DateTime.now();
    }
    return fetched;
  }

  /// Adds a recipient the member has just paid to the cached list, so the next
  /// screen that reads it recognises them without waiting for a refresh.
  void rememberSuggestion(TransferSuggestion suggestion) {
    if (!suggestion.isPayable) return;
    final existing = _cachedSuggestions ?? const <TransferSuggestion>[];
    final key = suggestion.accountNumber.trim();
    _cachedSuggestions = [
      suggestion,
      ...existing.where((e) => e.accountNumber.trim() != key),
    ];
    _cachedSuggestionsAt ??= DateTime.now();
  }

  /// Names the owner of an exact account number without asking Anchor.
  ///
  /// Answers from a Communal wallet first — that makes it a book transfer,
  /// which is instant and free — then from the recipients this member has paid
  /// before. Returns null when we hold nothing, which is the ordinary case for
  /// a new account at another bank and means "fall through to a name enquiry",
  /// not "wrong number".
  Future<TransferSuggestion?> resolveAccount(String accountNumber) async {
    final digits = accountNumber.trim();
    if (digits.isEmpty) return null;
    try {
      final response = await _dioClient.get(
        ApiEndpoints.transferResolveAccount,
        queryParameters: {'accountNumber': digits},
      );
      final data = response.data;
      if (data is! Map || data['status'] != true) return null;
      final raw = data['data'];
      if (raw is! Map) return null;
      final suggestion = TransferSuggestion.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (!suggestion.isPayable || suggestion.accountName.trim().isEmpty) {
        return null;
      }
      return suggestion;
    } on DioException {
      // A lookup that cannot reach the server must not block the transfer: the
      // screen falls back to picking a bank and running the name enquiry.
      return null;
    }
  }

  Future<AccountVerificationResult> verifyAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.transferVerifyAccount(bankCode, accountNumber),
        data: const <String, dynamic>{},
      );
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        throw Exception('Account verification failed.');
      }
      final raw = data['data'];
      if (raw is! Map) {
        throw Exception('Account verification returned invalid response.');
      }
      return AccountVerificationResult.fromJson(
        Map<String, dynamic>.from(raw),
        fallbackBankCode: bankCode.trim(),
        fallbackAccountNumber: accountNumber.trim(),
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  Future<String> createCounterParty({
    required String bankCode,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.transferCreateCounterParties,
        data: {
          'bankCode': bankCode.trim(),
          'accountNumber': accountNumber.trim(),
          'accountName': accountName.trim(),
        },
      );
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        throw Exception('Could not create counterparty.');
      }
      final raw = data['data'];
      if (raw is! Map || raw['id'] == null) {
        throw Exception('Counterparty creation returned invalid response.');
      }
      final id = raw['id'].toString().trim();
      if (id.isEmpty) {
        throw Exception('Counterparty id is empty.');
      }
      return id;
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// [intent] is what the verification may be spent on: `transfer`,
  /// `pay-obligation`, or `account-action` for a PIN checked to freeze, close or
  /// change a PIN. The service that moves the money accepts only its own, so a
  /// PIN entered to confirm a transfer no longer settles a loan repayment.
  Future<void> verifySecurityPin(String pin, {required String intent}) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.membersVerifySecurityPin,
        data: {'security_pin': pin, 'intent': intent},
      );
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        throw Exception('Security PIN verification failed.');
      }
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  Future<void> updateSecurityPin(String pin) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.membersUpdateSecurityPin,
        data: {'security_pin': pin.trim()},
      );
      final data = response.data;
      if (data is! Map) {
        throw Exception('Unable to update PIN.');
      }
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw Exception(data['message']?.toString() ?? 'Unable to update PIN.');
      }
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  Future<TransferInitiationResult> initiateTransfer({
    required String type,
    required int amountMinor,
    required String narration,
    String? destinationAccountId,
    String? counterPartyId,
    String? currencyCode,
    String? idempotencyKey,
    Map<String, String>? biometricHeaders,
    String? pin,
    Map<String, dynamic>? obligationContext,
    String? beneficiaryName,
    String? beneficiaryBank,
    String? beneficiaryAccount,
  }) async {
    try {
      var ccy = (currencyCode ?? 'NGN').trim().toUpperCase();
      if (ccy.length != 3) ccy = 'NGN';
      final body = <String, dynamic>{
        'type': type,
        'amount': amountMinor,
        'currency': ccy,
        'narration': narration.trim(),
        if (destinationAccountId != null &&
            destinationAccountId.trim().isNotEmpty)
          'destinationAccountId': destinationAccountId.trim(),
        if (counterPartyId != null && counterPartyId.trim().isNotEmpty)
          'counterPartyId': counterPartyId.trim(),
        if (obligationContext != null && obligationContext.isNotEmpty)
          'obligation_context': obligationContext,
        // Beneficiary display info so the recipient shows in history (NIP has no
        // local receiver record server-side).
        if (beneficiaryName != null && beneficiaryName.trim().isNotEmpty)
          'beneficiaryName': beneficiaryName.trim(),
        if (beneficiaryBank != null && beneficiaryBank.trim().isNotEmpty)
          'beneficiaryBank': beneficiaryBank.trim(),
        if (beneficiaryAccount != null && beneficiaryAccount.trim().isNotEmpty)
          'beneficiaryAccount': beneficiaryAccount.trim(),
      };
      // Caller must supply EITHER biometricHeaders OR pin. The backend
      // middleware (RequireBiometricSignature) treats them as mutually
      // exclusive: a partial biometric header set is rejected, and a
      // missing-biometric request falls through to X-Security-Pin.
      final headers = <String, String>{
        if (biometricHeaders != null) ...biometricHeaders,
        if (pin != null && pin.isNotEmpty) 'X-Security-Pin': pin,
      };
      final response = await _dioClient.post(
        ApiEndpoints.transferInitiate,
        data: body,
        idempotencyKey: idempotencyKey,
        extraHeaders: headers.isEmpty ? null : headers,
      );
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        throw Exception('Transfer initiation failed.');
      }
      final raw = data['data'];
      if (raw is! Map) {
        throw Exception('Transfer initiation returned invalid response.');
      }
      return TransferInitiationResult.fromJson(
        Map<String, dynamic>.from(raw),
        fallbackType: type,
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Single-transaction fetch keyed by trx_reference OR
  /// external_reference. Used by the push-tap deep link — a
  /// transaction-typed push only carries a reference and the receipt
  /// screen needs a fully built [TransactionDetailsData] in `extra`.
  ///
  /// Returns null when the reference is empty or the row doesn't
  /// belong to the caller (server returns 404 in that case).
  Future<TransactionDetailsData?> fetchTransactionByReference(
    String reference, {
    required String currencySymbol,
  }) async {
    final ref = reference.trim();
    if (ref.isEmpty) return null;
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersTransactionByReference(ref),
      );
      final data = response.data;
      // transactions-svc wraps every success in {status, data}; the older
      // monolith route returned the row under `transaction`.
      final raw = data is Map ? (data['data'] ?? data['transaction']) : null;
      if (raw is! Map) return null;
      // Reuse the list-row mapper — same shape returned by
      // /personal-transactions, so the existing communal-row builder
      // handles it without a parallel constructor.
      final item = mapCommunalTransactionToListItem(
        Map<String, dynamic>.from(raw),
        currencySymbol: currencySymbol,
      );
      return item.details;
    } on DioException {
      return null;
    }
  }

  Future<RemoteTransferStatus> fetchTransferStatus(String transferId) async {
    final id = transferId.trim();
    if (id.isEmpty) {
      throw Exception('Missing transfer id.');
    }
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersTransferStatus(id),
      );
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        throw Exception('Could not load transfer status.');
      }
      final raw = data['data'];
      if (raw is! Map) {
        throw Exception('Invalid transfer status response.');
      }
      return RemoteTransferStatus.fromDataJson(Map<String, dynamic>.from(raw));
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  Future<NipFeeResult> fetchNipFee({required int amountMinor}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.transferFee,
        queryParameters: {'amount': amountMinor, 'type': 'NIPTransfer'},
      );
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        throw Exception('Could not load transfer fee.');
      }
      final raw = data['data'];
      if (raw is! Map) {
        throw Exception('Invalid fee response.');
      }
      return NipFeeResult.fromJson(Map<String, dynamic>.from(raw));
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  Future<List<TransferBeneficiary>> fetchBeneficiaries() async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersTransferBeneficiaries,
      );
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        throw Exception('Could not load beneficiaries.');
      }
      final raw = data['data'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => TransferBeneficiary.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  String _messageFromDio(DioException e) {
    // Server-supplied message wins when there is one. The backend
    // already shapes these for end users (validation errors,
    // domain-level failures, etc.).
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
      final errors = data['errors'];
      if (errors is Map) {
        final values = <String>[];
        for (final entry in errors.entries) {
          final v = entry.value;
          if (v is List && v.isNotEmpty) {
            values.add(v.first.toString());
          } else if (v != null) {
            values.add(v.toString());
          }
        }
        if (values.isNotEmpty) return values.join(' ');
      }
    }
    // No body / no message → translate the transport failure to copy
    // the user can act on. Dio's raw `e.message` (e.g. "The request
    // was canceled.", "Connecting timed out [10s]") leaks
    // implementation language and was being shown verbatim in
    // toasts.
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server is taking too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return "Couldn't reach the server. Check your internet connection and try again.";
      case DioExceptionType.cancel:
        return 'The request was cancelled. Please try again.';
      case DioExceptionType.badCertificate:
        return 'Secure connection to the server failed. Please try again later.';
      case DioExceptionType.badResponse:
        // Body had no message; status code-only context.
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          return 'You are not authorised. Sign out and back in, then retry.';
        }
        if (code != null && code >= 500) {
          return 'The server is having trouble right now. Please try again in a moment.';
        }
        return 'Request failed. Please try again.';
      case DioExceptionType.unknown:
        return 'Network error. Please check your connection and try again.';
    }
  }
}
