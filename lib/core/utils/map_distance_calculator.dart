import 'package:gmaps_by_road_distance_calculator/gmaps_by_road_distance_calculator.dart';
import 'package:latlong2/latlong.dart';

Future<String> getDist({
  required double startLatitude,
  required double startLongitude,
  required double destinationLatitude,
  required double destinationLongitude,
}) async {
  final distanceApi = ByRoadDistanceCalculator();

  final points = [
    LatLng(startLatitude, startLongitude),
    LatLng(destinationLatitude, destinationLongitude),
  ];

  // Only pass the single expected argument
  final distance = distanceApi.calculateDistance(points);

  return distance.toString();
}
