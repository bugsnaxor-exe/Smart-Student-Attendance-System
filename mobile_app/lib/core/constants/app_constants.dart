class AppConstants {
  // Base URLs - Adjust to your local machine IP / deployed server URL
  static const String defaultApiBaseUrl = 'http://10.0.2.2:4000/api'; // Android Emulator
  static const String defaultWsUrl = 'ws://10.0.2.2:4000/ws';

  // Physical Geofencing Rules
  static const double defaultDeptLatitude = 22.5726;
  static const double defaultDeptLongitude = 88.3639;
  static const double defaultGeofenceRadiusMeters = 50.0;

  // College Timing Rules
  static const int collegeStartHour = 10;
  static const int collegeStartMinute = 15; // 10:15 AM
  static const int collegeEndHour = 17;     // 05:00 PM
  static const int collegeEndMinute = 0;

  // Active Session Duration
  static const int sessionDurationMinutes = 15;
}
