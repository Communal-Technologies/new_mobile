/// Build-time configuration.
///
/// Values come from `--dart-define` flags (or `--dart-define-from-file`),
/// not from a bundled `.env` asset — bundling secrets into the APK was M2 in
/// the audit. Use `tool/dart_defines.example.json` as a template:
///
///     flutter run --dart-define-from-file=tool/dart_defines.json
///
/// `BASE_URL` is only consulted when `APP_ENV` is `development` / `dev`;
/// staging and production hit the fixed URLs below.
class AppConstants {
  AppConstants._();

  static const String defaultLanguage = 'en';
  static const String configUri = '/fetch-system-settings';

  /// Audit M25: OTP length used by the verify-reset, session-takeover, and
  /// phone-verification screens. Backend issues 6-digit codes today; bumping
  /// this constant is the only mobile change required if it ever changes.
  static const int otpLength = 6;

  /// Staging API (used when `APP_ENV` is `staging`).
  static const String stagingApiBaseUrl =
      'https://api-staging.communalhq.com/api/v1';

  /// Production API (used when `APP_ENV` is `production`).
  static const String productionApiBaseUrl =
      'https://api.communalhq.com/api/v1';

  static const String _baseUrlDefine =
      String.fromEnvironment('BASE_URL');
  static const String _googleMapsApiKeyDefine =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String _appEnvDefine =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');

  /// Development API from `--dart-define=BASE_URL=...`. Not used as [baseUrl]
  /// until `APP_ENV` is development.
  static String get developmentApiBaseUrl {
    final raw = _baseUrlDefine.trim();
    if (raw.isEmpty) return '';
    return _stripOptionalQuotes(raw);
  }

  static String get googleMapsApiKey =>
      _stripOptionalQuotes(_googleMapsApiKeyDefine.trim());

  /// Current `APP_ENV` (missing or blank → `development`).
  static String get appEnvironment {
    final raw = _appEnvDefine.trim();
    if (raw.isEmpty) return 'development';
    return raw.toLowerCase();
  }

  /// Resolved API base for [appEnvironment].
  static String get baseUrl {
    switch (appEnvironment) {
      case 'development':
      case 'dev':
        final url = developmentApiBaseUrl;
        if (url.isEmpty) {
          throw StateError(
            'BASE_URL must be passed via --dart-define when APP_ENV is development.',
          );
        }
        return url;
      case 'staging':
        return stagingApiBaseUrl;
      case 'production':
      case 'prod':
        return productionApiBaseUrl;
      default:
        throw StateError(
          'Unknown APP_ENV "$_appEnvDefine". '
          'Use development, staging, or production.',
        );
    }
  }

  static String _stripOptionalQuotes(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == "'" && last == "'") || (first == '"' && last == '"')) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }
}
