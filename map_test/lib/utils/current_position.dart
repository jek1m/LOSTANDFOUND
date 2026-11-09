import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

Future<Position> getReliableCurrentPosition({
  LocationAccuracy accuracy = LocationAccuracy.high,
  Duration timeLimit = const Duration(seconds: 15),
}) {
  final LocationSettings settings;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    settings = AndroidSettings(
      accuracy: accuracy,
      forceLocationManager: true,
      timeLimit: timeLimit,
    );
  } else {
    settings = LocationSettings(accuracy: accuracy, timeLimit: timeLimit);
  }

  return Geolocator.getCurrentPosition(locationSettings: settings);
}
