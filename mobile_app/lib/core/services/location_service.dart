import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../security/mock_location_detector.dart';

class LocationResult {
  final bool isSuccess;
  final Position? position;
  final double distanceMeters;
  final bool isInsideGeofence;
  final bool isMock;
  final String? errorMessage;

  LocationResult({
    required this.isSuccess,
    this.position,
    this.distanceMeters = 0.0,
    this.isInsideGeofence = false,
    this.isMock = false,
    this.errorMessage,
  });
}

class LocationService {
  /// Request GPS Location Permissions
  static Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Calculates Haversine distance in meters between two coordinates
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Multi-Sample GPS Averaging (Takes 3 high-accuracy samples to eliminate indoor building drift)
  static Future<LocationResult> getSmoothedLocation({
    required double targetDeptLat,
    required double targetDeptLon,
    double allowedRadiusMeters = 50.0,
    int samplesCount = 3,
  }) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      return LocationResult(
        isSuccess: false,
        errorMessage: 'Location permissions are required to verify attendance.',
      );
    }

    List<Position> collectedPositions = [];

    try {
      for (int i = 0; i < samplesCount; i++) {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 8),
        );

        // Anti-Spoof check
        if (MockLocationDetector.isMockPosition(pos)) {
          return LocationResult(
            isSuccess: false,
            isMock: true,
            errorMessage: 'Mock/Fake GPS app detected. Attendance rejected.',
          );
        }

        collectedPositions.add(pos);
        if (i < samplesCount - 1) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }

      if (collectedPositions.isEmpty) {
        return LocationResult(
          isSuccess: false,
          errorMessage: 'Unable to obtain GPS lock. Please move near a window or open area.',
        );
      }

      // Compute average latitude & longitude
      double avgLat = collectedPositions.map((p) => p.latitude).reduce((a, b) => a + b) / collectedPositions.length;
      double avgLon = collectedPositions.map((p) => p.longitude).reduce((a, b) => a + b) / collectedPositions.length;
      double avgAccuracy = collectedPositions.map((p) => p.accuracy).reduce((a, b) => a + b) / collectedPositions.length;

      double distance = calculateDistance(avgLat, avgLon, targetDeptLat, targetDeptLon);
      bool isInside = distance <= allowedRadiusMeters;

      Position finalPos = Position(
        latitude: avgLat,
        longitude: avgLon,
        timestamp: DateTime.now(),
        accuracy: avgAccuracy,
        altitude: collectedPositions.last.altitude,
        altitudeAccuracy: collectedPositions.last.altitudeAccuracy,
        heading: collectedPositions.last.heading,
        headingAccuracy: collectedPositions.last.headingAccuracy,
        speed: collectedPositions.last.speed,
        speedAccuracy: collectedPositions.last.speedAccuracy,
        isMocked: false,
      );

      return LocationResult(
        isSuccess: true,
        position: finalPos,
        distanceMeters: (distance * 10).round() / 10,
        isInsideGeofence: isInside,
        isMock: false,
      );
    } catch (e) {
      return LocationResult(
        isSuccess: false,
        errorMessage: 'GPS Error: ${e.toString()}',
      );
    }
  }
}
