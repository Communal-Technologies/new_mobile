import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:location_geocoder/location_geocoder.dart';

import '../constants/constants.dart';

Future<String> getAddressFromCoordinates({required double long, required double lat}) async {
  var apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

  final LocatitonGeocoder geocoder = LocatitonGeocoder(AppConstants.googleMapsApiKey);
  final address = await geocoder.findAddressesFromCoordinates(Coordinates(lat, long));

  return address.first.addressLine ?? '';
}
//TODO - MAKE ONE CLASS
Future<String> getCityFromCoordinates(double latitude, double longitude) async {
  var apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

  final LocatitonGeocoder geocoder =
      LocatitonGeocoder(AppConstants.googleMapsApiKey);
  final address = await geocoder
      .findAddressesFromCoordinates(Coordinates(latitude, longitude));


  return address.first.locality ?? '';
}
