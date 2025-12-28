import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static final baseUrl = dotenv.env['BASE_URL'] ?? 'https://api.communalhq.com/api/v1';
  static const defaultLanguage = 'en';
  static String googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Endpoints //
  static const String configUri = '/fetch-system-settings';
}