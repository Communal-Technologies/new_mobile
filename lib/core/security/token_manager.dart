import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import 'package:communal_mobile/core/utils/app_logger.dart';

/// Owns persistence of the access token + refresh token + expiry data, plus
/// JWT `exp` parsing for proactive refresh decisions.
///
/// Audit M6: previously the access token persisted in secure storage until
/// manual logout or a 401, with no proactive expiry check and no refresh
/// flow. This class is the chokepoint that makes both possible — the
/// [RefreshTokenInterceptor] consults [shouldRefreshSoon] before each
/// request and asks for a new pair via [AuthRepository.refreshTokens] (which
/// calls back into [updateTokens] to persist + advance the in-memory copy).
///
/// Storage keys
/// ------------
/// - `token`              — access token (string). Pre-existing key, kept
///                          for back-compat with installed apps.
/// - `refresh_token`      — refresh token (string). New key.
/// - `access_token_exp`   — Unix epoch seconds (string). Cached so we
///                          don't have to parse the JWT on every request.
@lazySingleton
class TokenManager {
  TokenManager(this._storage);

  final FlutterSecureStorage _storage;

  static const String _kAccessKey = 'token';
  static const String _kRefreshKey = 'refresh_token';
  static const String _kExpKey = 'access_token_exp';
  static const String _kActiveCoopKey = 'active_cooperative_id';
  static const String _kActiveLedgerKey = 'active_ledger_number';

  /// Window before [_accessExpEpochSeconds] expires within which we treat
  /// the token as "about to expire" and refresh proactively. Tuned to be
  /// larger than typical request round-trip so a request fired right at
  /// the boundary doesn't 401 against a token we *could* have refreshed.
  static const Duration refreshLeadTime = Duration(seconds: 60);

  String? _accessToken;
  String? _refreshToken;
  int? _accessExpEpochSeconds;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  int? get accessExpEpochSeconds => _accessExpEpochSeconds;

  /// Loads any previously-persisted tokens from secure storage into memory.
  /// Idempotent. Call from `AppStarted` / DI bootstrap.
  Future<void> hydrate() async {
    _accessToken = await _storage.read(key: _kAccessKey);
    _refreshToken = await _storage.read(key: _kRefreshKey);
    final expRaw = await _storage.read(key: _kExpKey);
    _accessExpEpochSeconds = expRaw != null ? int.tryParse(expRaw) : null;
    if (_accessToken != null && _accessExpEpochSeconds == null) {
      // Pre-M6 tokens have no cached expiry — derive from the JWT now so
      // [shouldRefreshSoon] works on the upgrade-from-old-build path.
      _accessExpEpochSeconds = _decodeJwtExp(_accessToken!);
      if (_accessExpEpochSeconds != null) {
        await _storage.write(
          key: _kExpKey,
          value: _accessExpEpochSeconds!.toString(),
        );
      }
    }
  }

  /// Persists a fresh token pair. [expiresIn] is the access-token lifetime
  /// in seconds (from `/login` / `/refresh-token`); when null, the JWT's
  /// own `exp` claim is consulted.
  ///
  /// [replaceRefreshToken] distinguishes the two callers:
  /// - Refresh rotation (default `false`): the backend may return the same
  ///   refresh token (no rotation), in which case [refreshToken] is null and
  ///   we keep the one we already hold.
  /// - Fresh login (`true`): this is a brand-new user session, so a missing
  ///   refresh token in the response must *clear* any token still held from
  ///   a previous login. Without this, a fresh login that omits a refresh
  ///   token leaves the previous user's refresh token in storage — and the
  ///   next proactive/reactive refresh resurrects that user, which presents
  ///   as the app silently switching accounts on hot restart.
  Future<void> updateTokens({
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
    bool replaceRefreshToken = false,
  }) async {
    _accessToken = accessToken;
    final hasNewRefresh = refreshToken != null && refreshToken.isNotEmpty;
    if (hasNewRefresh) {
      _refreshToken = refreshToken;
    } else if (replaceRefreshToken) {
      _refreshToken = null;
    }
    final exp = expiresIn != null
        ? DateTime.now()
                .add(Duration(seconds: expiresIn))
                .millisecondsSinceEpoch ~/
            1000
        : _decodeJwtExp(accessToken);
    _accessExpEpochSeconds = exp;

    await _storage.write(key: _kAccessKey, value: accessToken);
    if (hasNewRefresh) {
      await _storage.write(key: _kRefreshKey, value: refreshToken);
    } else if (replaceRefreshToken) {
      await _storage.delete(key: _kRefreshKey);
    }
    if (exp != null) {
      await _storage.write(key: _kExpKey, value: exp.toString());
    } else {
      await _storage.delete(key: _kExpKey);
    }
  }

  /// Clears all token state, in memory and on disk. Called on logout and
  /// on a refresh-token rejection (refresh itself returned 401/403).
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _accessExpEpochSeconds = null;
    await _storage.delete(key: _kAccessKey);
    await _storage.delete(key: _kRefreshKey);
    await _storage.delete(key: _kExpKey);
    await _storage.delete(key: _kActiveCoopKey);
    await _storage.delete(key: _kActiveLedgerKey);
  }

  /// Persists the client-side active-cooperative selection so a cooperative
  /// switch survives a cold start (the full [UserModel] is re-fetched, not
  /// restored, so without this the app reverts to the backend's default coop).
  Future<void> setActiveCooperative(
      String cooperativeId, String ledgerNumber) async {
    if (cooperativeId.isEmpty || ledgerNumber.isEmpty) return;
    await _storage.write(key: _kActiveCoopKey, value: cooperativeId);
    await _storage.write(key: _kActiveLedgerKey, value: ledgerNumber);
  }

  /// Returns the persisted active-cooperative selection, or null when none was
  /// set (fresh install / never switched).
  Future<({String cooperativeId, String ledgerNumber})?>
      readActiveCooperative() async {
    final coop = await _storage.read(key: _kActiveCoopKey);
    final ledger = await _storage.read(key: _kActiveLedgerKey);
    if (coop == null || coop.isEmpty || ledger == null || ledger.isEmpty) {
      return null;
    }
    return (cooperativeId: coop, ledgerNumber: ledger);
  }

  /// Clears only the active-cooperative selection (e.g. the member left that
  /// cooperative), without touching tokens.
  Future<void> clearActiveCooperative() async {
    await _storage.delete(key: _kActiveCoopKey);
    await _storage.delete(key: _kActiveLedgerKey);
  }

  /// `true` when the current access token will expire within
  /// [refreshLeadTime]. The interceptor uses this to refresh proactively
  /// before firing the actual request, avoiding the 401-then-retry round
  /// trip on the happy path.
  ///
  /// Returns `false` when there's no expiry information at all (legacy
  /// tokens with no JWT `exp` and no cached value): we fall back to the
  /// reactive 401 handler in that case.
  bool shouldRefreshSoon() {
    final exp = _accessExpEpochSeconds;
    if (exp == null) return false;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return exp - nowSec <= refreshLeadTime.inSeconds;
  }

  /// `true` when we have a refresh token available for either proactive or
  /// reactive refresh. Pure-bearer-no-refresh sessions (old installs that
  /// signed in before M6 shipped) return false — the interceptor then
  /// falls through to the existing 401 → AuthUnauthenticated flow.
  bool get canRefresh => (_refreshToken?.isNotEmpty ?? false);

  /// Parse a JWT's `exp` claim (seconds since epoch). Returns null on any
  /// parse failure — the caller should treat this as "no expiry info" and
  /// rely on reactive refresh.
  static int? _decodeJwtExp(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1];
      // Base64-url with no padding is the JWT spec — pad before decoding.
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
        case 1:
          // Malformed payload length.
          return null;
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final claims = json.decode(decoded);
      if (claims is Map && claims['exp'] is num) {
        return (claims['exp'] as num).toInt();
      }
    } catch (e) {
      AppLogger.warn('TokenManager', 'JWT exp decode failed: $e');
    }
    return null;
  }

  /// Parse a JWT's `sub` claim — the authenticated user id. Returns null on any
  /// parse failure. Used to detect (and refuse) a refresh that would switch the
  /// session to a different user.
  static String? decodeJwtSub(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1];
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
        case 1:
          return null;
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final claims = json.decode(decoded);
      if (claims is Map && claims['sub'] != null) {
        final sub = claims['sub'].toString().trim();
        return sub.isEmpty ? null : sub;
      }
    } catch (e) {
      AppLogger.warn('TokenManager', 'JWT sub decode failed: $e');
    }
    return null;
  }
}
