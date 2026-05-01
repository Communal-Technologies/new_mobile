import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/bills/bill_customer.dart';
import 'package:communal_mobile/data/models/bills/bill_product.dart';
import 'package:communal_mobile/data/models/bills/bill_provider.dart';
import 'package:communal_mobile/data/models/bills/bill_transaction.dart';
import 'package:dio/dio.dart';

/// Talks to the backend's `/v1/bills/*` endpoints — Anchor-backed
/// airtime + data purchases. The backend handles the JSON:API envelope,
/// webhook reconciliation, and idempotency caching; mobile only deals
/// with our own friendly response shape.
///
/// Backend contract: `docs/bill-payments.md` in the backend repo.
class BillsRepository {
  BillsRepository(this._dio);

  final DioClient _dio;

  /// Backend wraps every response in `{status, message, data}`. This
  /// helper returns `data` (or throws with the server-supplied message)
  /// so callers don't have to repeat the unpacking.
  T _unwrap<T>(Response res, T Function(dynamic data) parse) {
    final body = res.data;
    if (body is Map && body['status'] == false) {
      final msg = body['message']?.toString() ?? 'Request failed';
      throw Exception(msg);
    }
    final data = body is Map ? body['data'] : null;
    return parse(data);
  }

  /// Surfaces the backend's error envelope through DioException so the
  /// caller sees the same `Exception(message)` shape regardless of
  /// network vs. validation vs. provider failure.
  Never _throwForDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      throw Exception(data['message'].toString());
    }
    throw Exception(e.message ?? 'Network error');
  }

  Future<List<BillProvider>> fetchAirtimeProviders() async {
    try {
      final res = await _dio.get(ApiEndpoints.billsAirtimeProviders);
      return _unwrap(res, (data) => _parseProviders(data));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  Future<List<BillProvider>> fetchDataProviders() async {
    try {
      final res = await _dio.get(ApiEndpoints.billsDataProviders);
      return _unwrap(res, (data) => _parseProviders(data));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  Future<List<BillProvider>> fetchElectricityProviders() async {
    try {
      final res = await _dio.get(ApiEndpoints.billsElectricityProviders);
      return _unwrap(res, (data) => _parseProviders(data));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  Future<List<BillProvider>> fetchTelevisionProviders() async {
    try {
      final res = await _dio.get(ApiEndpoints.billsTelevisionProviders);
      return _unwrap(res, (data) => _parseProviders(data));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  /// Pre-purchase meter / smartcard lookup. `billerSlug` is the
  /// provider's `slug` (e.g. `ikeja_electric_prepaid`, `dstv`).
  /// Returns the customer name + number registered to that account.
  Future<BillCustomer> validateCustomer({
    required String billerSlug,
    required String accountNumber,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.billsCustomerValidation(billerSlug, accountNumber),
      );
      return _unwrap(res, (data) => BillCustomer.fromJson(_asMap(data)));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  Future<List<BillProduct>> fetchProductsForBiller(String billerId) async {
    try {
      final res = await _dio.get(ApiEndpoints.billsBillerProducts(billerId));
      return _unwrap(res, (data) => _parseProducts(data));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  /// Initiate an airtime purchase. `amountMinor` is in kobo. The
  /// `idempotencyKey` MUST be generated client-side via
  /// `core/utils/idempotency.dart#newIdempotencyKey()` and reused on
  /// retry — see backend contract doc.
  ///
  /// `authHeaders` carries either the biometric triple
  /// (`X-Biometric-{Device-Id, Nonce-Id, Signature}`) or the PIN
  /// fallback (`X-Security-Pin`). The backend middleware
  /// `biometric-sig:bill-purchase` rejects the call without one of
  /// those.
  Future<BillTransaction> purchaseAirtime({
    required String provider,
    required String phoneNumber,
    required int amountMinor,
    required String idempotencyKey,
    required Map<String, String> authHeaders,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.billsAirtimePurchase,
        data: {
          'provider': provider,
          'phone_number': phoneNumber,
          'amount': amountMinor,
        },
        idempotencyKey: idempotencyKey,
        extraHeaders: authHeaders,
      );
      return _unwrap(res, (data) => BillTransaction.fromJson(_asMap(data)));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  /// Initiate a data purchase. `amountMinor` must equal the product's
  /// `priceMinor` (Anchor rejects mismatches). `productSlug` comes from
  /// `fetchProductsForBiller`. `authHeaders` carries the biometric or
  /// PIN-fallback headers — see [purchaseAirtime] for details.
  Future<BillTransaction> purchaseData({
    required String provider,
    required String phoneNumber,
    required String productSlug,
    required int amountMinor,
    required String idempotencyKey,
    required Map<String, String> authHeaders,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.billsDataPurchase,
        data: {
          'provider': provider,
          'phone_number': phoneNumber,
          'product_slug': productSlug,
          'amount': amountMinor,
        },
        idempotencyKey: idempotencyKey,
        extraHeaders: authHeaders,
      );
      return _unwrap(res, (data) => BillTransaction.fromJson(_asMap(data)));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  /// Initiate an electricity purchase. The meter must be validated via
  /// [validateCustomer] first. `provider` is the biller slug (e.g.
  /// `ikeja_electric_prepaid`); `productSlug` distinguishes prepaid vs
  /// postpaid product lines.
  Future<BillTransaction> purchaseElectricity({
    required String provider,
    required String meterAccountNumber,
    required String phoneNumber,
    required String productSlug,
    required int amountMinor,
    required String idempotencyKey,
    required Map<String, String> authHeaders,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.billsElectricityPurchase,
        data: {
          'provider': provider,
          'meter_account_number': meterAccountNumber,
          'phone_number': phoneNumber,
          'product_slug': productSlug,
          'amount': amountMinor,
        },
        idempotencyKey: idempotencyKey,
        extraHeaders: authHeaders,
      );
      return _unwrap(res, (data) => BillTransaction.fromJson(_asMap(data)));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  /// Initiate a cable TV (Television) purchase. Smartcard must be
  /// validated via [validateCustomer] first. `productSlug` is the plan
  /// the user picked from `fetchProductsForBiller`.
  Future<BillTransaction> purchaseTelevision({
    required String provider,
    required String smartCardNumber,
    required String phoneNumber,
    required String productSlug,
    required int amountMinor,
    required String idempotencyKey,
    required Map<String, String> authHeaders,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.billsTelevisionPurchase,
        data: {
          'provider': provider,
          'smart_card_number': smartCardNumber,
          'phone_number': phoneNumber,
          'product_slug': productSlug,
          'amount': amountMinor,
        },
        idempotencyKey: idempotencyKey,
        extraHeaders: authHeaders,
      );
      return _unwrap(res, (data) => BillTransaction.fromJson(_asMap(data)));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  /// Poll for a bill transaction's current status. Use after a `pending`
  /// purchase response — the webhook will eventually push the user a
  /// terminal-state notification, but polling is fine for in-app
  /// foreground updates.
  Future<BillTransaction> fetchTransaction(String reference) async {
    try {
      final res =
          await _dio.get(ApiEndpoints.billsTransactionByReference(reference));
      return _unwrap(res, (data) => BillTransaction.fromJson(_asMap(data)));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  // ---- Internals --------------------------------------------------------

  static List<BillProvider> _parseProviders(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => BillProvider.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  static List<BillProduct> _parseProducts(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => BillProduct.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }
}
