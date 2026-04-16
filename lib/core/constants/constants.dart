import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment-driven API base URLs.
///
/// - **Development** — always read from `.env` as `BASE_URL` (required when
///   `APP_ENV` is `development`).
/// - **Staging / production** — fixed app URLs; pick which applies via
///   `APP_ENV=staging` or `APP_ENV=production` in `.env` (or your CI/build).
class AppConstants {
  AppConstants._();

  static const String defaultLanguage = 'en';
  static const String configUri = '/fetch-system-settings';

  /// Staging API (used when `APP_ENV` is `staging`).
  static const String stagingApiBaseUrl =
      'https://api-staging.communalhq.com/api/v1';

  /// Production API (used when `APP_ENV` is `production`).
  static const String productionApiBaseUrl =
      'https://api.communalhq.com/api/v1';

  /// Development API from `.env` only (`BASE_URL`). Not used as [baseUrl]
  /// until `APP_ENV` is development.
  static String get developmentApiBaseUrl {
    final raw = dotenv.env['BASE_URL'];
    if (raw == null || raw.trim().isEmpty) return '';
    return _stripOptionalQuotes(raw.trim());
  }

  static String get googleMapsApiKey =>
      _stripOptionalQuotes(dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '');

  /// Current `APP_ENV` from `.env` (missing or blank → `development`).
  static String get appEnvironment {
    final raw = dotenv.env['APP_ENV'];
    if (raw == null || raw.trim().isEmpty) return 'development';
    return raw.trim().toLowerCase();
  }

  /// Resolved API base for [appEnvironment].
  static String get baseUrl {
    switch (appEnvironment) {
      case 'development':
      case 'dev':
        final url = developmentApiBaseUrl;
        if (url.isEmpty) {
          throw StateError(
            'BASE_URL must be set in .env when APP_ENV is development.',
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
          'Unknown APP_ENV "${dotenv.env['APP_ENV']}". '
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
