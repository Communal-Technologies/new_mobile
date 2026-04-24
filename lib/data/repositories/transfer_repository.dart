import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
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
  });

  final String source; // internal | external
  final String accountId;
  final String bank;
  final String cooperativeName;
  final String accountNumber;
  final String accountName;
  final String? nipCode;

  bool get isInternal => source.trim().toLowerCase() == 'internal';
  bool get isExternal => source.trim().toLowerCase() == 'external';

  factory TransferSuggestion.fromJson(Map<String, dynamic> json) {
    return TransferSuggestion(
      source: json['source']?.toString() ?? '',
      accountId: json['account_id']?.toString() ?? '',
      bank: json['bank']?.toString() ?? '',
      cooperativeName: json['cooperative_name']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      nipCode: json['nipCode']?.toString(),
    );
  }
}

class AccountVerificationResult {
  const AccountVerificationResult({
    required this.accountName,
    required this.accountNumber,
    required this.bankCode,
  });

  final String accountName;
  final String accountNumber;
  final String bankCode;

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
    );
  }
}

class TransferInitiationResult {
  const TransferInitiationResult({
    required this.transferId,
    required this.reference,
    required this.status,
    required this.type,
  });

  final String transferId;
  final String reference;
  final String status;
  final String type;

  factory TransferInitiationResult.fromJson(
    Map<String, dynamic> json, {
    required String fallbackType,
  }) {
    final attr = (json['attributes'] is Map)
        ? Map<String, dynamic>.from(json['attributes'] as Map)
        : <String, dynamic>{};
    return TransferInitiationResult(
      transferId: json['id']?.toString() ?? '',
      reference: attr['reference']?.toString() ?? '',
      status: attr['status']?.toString() ?? 'PENDING',
      type: json['type']?.toString() ?? fallbackType,
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
  });

  final String accountId;
  final String accountNumber;
  final String accountName;
  final String bankName;
  final String type; // internal | external
  final String? nipCode;

  bool get isInternal => type.trim().toLowerCase() == 'internal';

  factory TransferBeneficiary.fromJson(Map<String, dynamic> json) {
    return TransferBeneficiary(
      accountId: json['account_id']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      nipCode: json['nip_code']?.toString(),
    );
  }
}

class TransferRepository {
  TransferRepository(this._dioClient);

  final DioClient _dioClient;

  Future<List<TransferSuggestion>> fetchBankSuggestions({String? query}) async {
    try {
      final response = await _dioClient.get(
        '/transfer/bank-suggestions',
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
                e.accountId.trim().isNotEmpty &&
                e.accountName.trim().isNotEmpty &&
                e.accountNumber.trim().isNotEmpty,
          )
          .toList(growable: false);
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  Future<AccountVerificationResult> verifyAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    try {
      final response = await _dioClient.post(
        '/transfer/verify-account/${bankCode.trim()}/${accountNumber.trim()}',
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
        '/transfer/create-counter-parties',
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

  Future<void> verifySecurityPin(String pin) async {
    try {
      final response = await _dioClient.post(
        '/members/verify-security-pin',
        data: {'security_pin': pin},
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
        '/members/update-security-pin',
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
    required int amountKobo,
    required String narration,
    String? destinationAccountId,
    String? counterPartyId,
  }) async {
    try {
      final body = <String, dynamic>{
        'type': type,
        'amount': amountKobo,
        'currency': 'NGN',
        'narration': narration.trim(),
        if (destinationAccountId != null &&
            destinationAccountId.trim().isNotEmpty)
          'destinationAccountId': destinationAccountId.trim(),
        if (counterPartyId != null && counterPartyId.trim().isNotEmpty)
          'counterPartyId': counterPartyId.trim(),
      };
      final response = await _dioClient.post('/transfer/initiate', data: body);
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

  Future<List<TransferBeneficiary>> fetchBeneficiaries() async {
    try {
      final response = await _dioClient.get('/members/transfer/beneficiaries');
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
    return e.message ?? 'Request failed';
  }
}
