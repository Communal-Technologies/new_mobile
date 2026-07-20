import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/bills/bill_customer.dart';
import 'package:communal_mobile/data/models/bills/bill_product.dart';
import 'package:communal_mobile/data/models/bills/bill_provider.dart';
import 'package:communal_mobile/data/models/bills/bill_transaction.dart';
import 'package:dio/dio.dart';

/// Talks to the bills micro-service at `/api/bills/v2/…`. Endpoints are
/// absolute URLs (see [ApiEndpoints]) because the service runs at a different
/// path prefix from the monolith.
///
/// Amount convention: callers pass amounts in **kobo** (minor units).
/// The bills service expects **naira**, so this repository divides by 100
/// before sending. Responses come back in naira and [BillTransaction.fromJson]
/// multiplies back to kobo.
///
/// Security PIN: the service reads `security_pin` from the JSON body.
/// Callers pass `authHeaders` containing `X-Security-Pin`; this repository
/// extracts the value and includes it in the request body.
class BillsRepository {
  BillsRepository(this._dio);

  final DioClient _dio;

  T _unwrap<T>(Response res, T Function(dynamic data) parse) {
    final body = res.data;
    if (body is Map && body['status'] == false) {
      final msg = body['message']?.toString() ?? 'Request failed';
      throw Exception(msg);
    }
    final data = body is Map ? body['data'] : null;
    return parse(data);
  }

  Never _throwForDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      throw Exception(data['message'].toString());
    }
    throw Exception(e.message ?? 'Network error');
  }

  // ── Provider catalogue ────────────────────────────────────────────────────

  Future<List<BillProvider>> fetchAirtimeProviders() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.billsBillers,
        queryParameters: {'category': 'AIRTIME'},
      );
      return _unwrap(res, (data) => _parseProviders(data));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  Future<List<BillProvider>> fetchDataProviders() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.billsBillers,
        queryParameters: {'category': 'DATA'},
      );
      return _unwrap(res, (data) => _parseProviders(data));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  Future<List<BillProvider>> fetchElectricityProviders() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.billsBillers,
        queryParameters: {'category': 'ELECTRICITY'},
      );
      return _unwrap(res, (data) => _parseProviders(data));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  Future<List<BillProvider>> fetchTelevisionProviders() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.billsBillers,
        queryParameters: {'category': 'TELEVISION'},
      );
      return _unwrap(res, (data) => _parseProviders(data));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  /// [productSlug] must be a *product* slug (from [BillProduct.slug]), not the
  /// biller slug — Anchor's customer-validation endpoint is product-scoped.
  /// Any product belonging to the biller works; the chosen plan is picked
  /// separately afterward.
  Future<BillCustomer> validateCustomer({
    required String productSlug,
    required String accountNumber,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.billsCustomerValidation(productSlug, accountNumber),
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

  // ── Purchase endpoints ────────────────────────────────────────────────────

  /// Airtime purchase. [billerCode] is the network slug (mtn, glo, airtel,
  /// 9mobile, ntel) — Anchor requires it as `provider`.
  Future<BillTransaction> purchaseAirtime({
    required String billerCode,
    required String phoneNumber,
    required int amountMinor,
    required String idempotencyKey,
    required Map<String, String> authHeaders,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.billsAirtimePurchase,
        data: {
          'phone_number': phoneNumber,
          'amount': _koboToNaira(amountMinor),
          'biller_code': billerCode,
          'security_pin': _extractPin(authHeaders),
        },
        idempotencyKey: idempotencyKey,
        extraHeaders: authHeaders,
      );
      return _unwrap(res, (data) => BillTransaction.fromJson(_asMap(data)));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  /// Data bundle purchase. [billerCode] comes from [BillProvider.billerCode];
  /// [productCode] comes from [BillProduct.slug] (which is actually the `code`
  /// field from the billsvc products response).
  Future<BillTransaction> purchaseData({
    required String billerCode,
    required String phoneNumber,
    required String productCode,
    required int amountMinor,
    required String idempotencyKey,
    required Map<String, String> authHeaders,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.billsDataPurchase,
        data: {
          'phone_number': phoneNumber,
          'amount': _koboToNaira(amountMinor),
          'biller_code': billerCode,
          'product_code': productCode,
          'security_pin': _extractPin(authHeaders),
        },
        idempotencyKey: idempotencyKey,
        extraHeaders: authHeaders,
      );
      return _unwrap(res, (data) => BillTransaction.fromJson(_asMap(data)));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  /// Electricity purchase. [meterType] must be `'prepaid'` or `'postpaid'`;
  /// derive from the provider slug if not shown to the user (e.g.
  /// `ikeja_electric_postpaid` → `'postpaid'`). [productCode] comes from
  /// [BillProduct.slug] — required by Anchor as `productSlug`.
  Future<BillTransaction> purchaseElectricity({
    required String billerCode,
    required String meterNumber,
    required String phoneNumber,
    required String productCode,
    required String meterType,
    required int amountMinor,
    required String idempotencyKey,
    required Map<String, String> authHeaders,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.billsElectricityPurchase,
        data: {
          'meter_number': meterNumber,
          'phone_number': phoneNumber,
          'amount': _koboToNaira(amountMinor),
          'biller_code': billerCode,
          'product_code': productCode,
          'meter_type': meterType,
          'security_pin': _extractPin(authHeaders),
        },
        idempotencyKey: idempotencyKey,
        extraHeaders: authHeaders,
      );
      return _unwrap(res, (data) => BillTransaction.fromJson(_asMap(data)));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  /// Cable TV purchase. [productCode] comes from [BillProduct.slug].
  Future<BillTransaction> purchaseTelevision({
    required String billerCode,
    required String smartCardNumber,
    required String phoneNumber,
    required String productCode,
    required int amountMinor,
    required String idempotencyKey,
    required Map<String, String> authHeaders,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.billsTelevisionPurchase,
        data: {
          'smart_card_number': smartCardNumber,
          'phone_number': phoneNumber,
          'amount': _koboToNaira(amountMinor),
          'biller_code': billerCode,
          'product_code': productCode,
          'security_pin': _extractPin(authHeaders),
        },
        idempotencyKey: idempotencyKey,
        extraHeaders: authHeaders,
      );
      return _unwrap(res, (data) => BillTransaction.fromJson(_asMap(data)));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  Future<BillTransaction> fetchTransaction(String reference) async {
    try {
      final res =
          await _dio.get(ApiEndpoints.billsTransactionByReference(reference));
      return _unwrap(res, (data) => BillTransaction.fromJson(_asMap(data)));
    } on DioException catch (e) {
      _throwForDioError(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Converts kobo minor units to naira (the amount unit the billsvc expects).
  static int _koboToNaira(int amountMinor) => amountMinor ~/ 100;

  /// Extracts the transaction PIN from [authHeaders] (`X-Security-Pin`).
  /// Returns an empty string when biometric headers are used instead of PIN;
  /// the service will reject the request with ErrPinRequired if a PIN is
  /// configured for the user (biometric bill auth is not yet supported).
  static String _extractPin(Map<String, String> headers) =>
      headers['X-Security-Pin'] ?? '';

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
