import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/services/location_service.dart';
import '../core/constants/app_constants.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  double _distanceToDept = 0.0;
  bool _isInsideGeofence = false;
  bool _isChecking = false;
  bool _isMockDetected = false;
  String? _errorMessage;

  Position? get currentPosition => _currentPosition;
  double get distanceToDept => _distanceToDept;
  bool get isInsideGeofence => _isInsideGeofence;
  bool get isChecking => _isChecking;
  bool get isMockDetected => _isMockDetected;
  String? get errorMessage => _errorMessage;

  Future<void> refreshLocation({
    double deptLat = AppConstants.defaultDeptLatitude,
    double deptLon = AppConstants.defaultDeptLongitude,
    double radiusMeters = AppConstants.defaultGeofenceRadiusMeters,
  }) async {
    _isChecking = true;
    _errorMessage = null;
    _isMockDetected = false;
    notifyListeners();

    final result = await LocationService.getSmoothedLocation(
      targetDeptLat: deptLat,
      targetDeptLon: deptLon,
      allowedRadiusMeters: radiusMeters,
    );

    _isChecking = false;
    if (result.isSuccess) {
      _currentPosition = result.position;
      _distanceToDept = result.distanceMeters;
      _isInsideGeofence = result.isInsideGeofence;
      _isMockDetected = false;
      _errorMessage = null;
    } else {
      _isMockDetected = result.isMock;
      _errorMessage = result.errorMessage;
    }

    notifyListeners();
  }
}
