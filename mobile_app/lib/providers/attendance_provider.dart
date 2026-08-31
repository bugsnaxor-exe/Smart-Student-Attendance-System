import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:geolocator/geolocator.dart';
import '../core/services/api_service.dart';
import '../core/constants/app_constants.dart';
import '../models/attendance_model.dart';
import '../models/session_model.dart';

class AttendanceProvider extends ChangeNotifier {
  DashboardStats? _dashboardStats;
  List<SubjectAttendanceStats> _subjectStats = [];
  List<SessionModel> _activeStudentSessions = [];
  List<StudentAttendanceCheckIn> _liveTeacherCheckIns = [];
  List<dynamic> _absentStudents = [];

  bool _isLoading = false;
  String? _statusMessage;
  String? _errorMessage;

  WebSocketChannel? _wsChannel;
  Timer? _sessionCountdownTimer;

  DashboardStats? get dashboardStats => _dashboardStats;
  List<SubjectAttendanceStats> get subjectStats => _subjectStats;
  List<SessionModel> get activeStudentSessions => _activeStudentSessions;
  List<StudentAttendanceCheckIn> get liveTeacherCheckIns => _liveTeacherCheckIns;
  List<dynamic> get absentStudents => _absentStudents;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;

  Timer? _studentPollingTimer;

  /// Connects to real-time WebSocket attendance broadcast stream
  void connectRealTimeStream() {
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(AppConstants.defaultWsUrl));
      _wsChannel!.stream.listen(
        (data) {
          try {
            final payload = jsonDecode(data);
            if (payload['type'] == 'STUDENT_CHECK_IN') {
              _liveTeacherCheckIns.insert(
                0,
                StudentAttendanceCheckIn(
                  id: payload['student']['id'],
                  studentName: payload['student']['name'],
                  classRoll: payload['student']['classRoll'],
                  universityRoll: payload['student']['universityRoll'],
                  regNumber: payload['student']['regNumber'],
                  status: payload['status'],
                  time: payload['time'],
                  distanceMeters: (payload['distanceMeters'] as num?)?.toDouble(),
                  syncedToSheet: true,
                ),
              );
              notifyListeners();
            } else if (payload['type'] == 'SESSION_STARTED') {
              // Immediately fetch active sessions when teacher starts a session
              fetchStudentActiveSessions();
            }
          } catch (err) {
            // Ignore parse errors
          }
        },
        onError: (err) {
          print('WebSocket error: $err');
        },
      );
    } catch (e) {
      print('Could not connect to WebSocket: $e');
    }
  }

  /// Start 4-second background poller for live active sessions on student dashboard
  void startStudentSessionPolling() {
    _studentPollingTimer?.cancel();
    fetchStudentActiveSessions();
    _studentPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      fetchStudentActiveSessions();
    });
  }

  void stopStudentSessionPolling() {
    _studentPollingTimer?.cancel();
  }

  /// Student: Fetches aggregate percentage and individual subject stats
  Future<void> fetchStudentDashboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.getStudentDashboard();
      if (res['stats'] != null) {
        _dashboardStats = DashboardStats.fromJson(res['stats']);
      }
      if (res['subjects'] != null) {
        _subjectStats = (res['subjects'] as List)
            .map((item) => SubjectAttendanceStats.fromJson(item))
            .toList();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Student: Fetches currently active 15-min sessions for their semester
  Future<void> fetchStudentActiveSessions() async {
    try {
      final res = await ApiService.getStudentActiveSessions();
      if (res['sessions'] != null) {
        _activeStudentSessions = (res['sessions'] as List)
            .map((item) => SessionModel.fromJson(item))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching active sessions: $e');
    }
  }

  /// Student: Marks full attendance with 50m geofence validation
  Future<bool> markAttendance({
    required String subjectId,
    required Position position,
    bool isMockLocation = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.markAttendance(
        subjectId: subjectId,
        latitude: position.latitude,
        longitude: position.longitude,
        isMockLocation: isMockLocation,
        accuracyMeters: position.accuracy,
      );

      _isLoading = false;
      if (res['status'] != null) {
        _statusMessage = 'Full attendance marked successfully! (${res['formattedTime']})';
        await fetchStudentDashboard();
        await fetchStudentActiveSessions();
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['error'] ?? 'Could not mark attendance.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Teacher: Starts a 15-minute active session
  Future<bool> startSession(String subjectId, {int durationMinutes = 15}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.startTeacherSession(subjectId, durationMinutes: durationMinutes);
      _isLoading = false;
      if (res['session'] != null) {
        _statusMessage = res['message'];
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['error'] ?? 'Could not start session.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Teacher: Fetches checked-in students for a subject
  Future<void> fetchTeacherAttendance(String subjectId, {String? date}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.getTeacherAttendanceRecords(subjectId, date: date);
      if (res['records'] != null) {
        _liveTeacherCheckIns = (res['records'] as List)
            .map((item) => StudentAttendanceCheckIn.fromJson(item))
            .toList();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Teacher: Fetches absent students for manual "Grant Half" override
  Future<void> fetchAbsentStudents(String subjectId, {String? date}) async {
    try {
      final res = await ApiService.getAbsentStudents(subjectId, date: date);
      if (res['absentStudents'] != null) {
        _absentStudents = res['absentStudents'];
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching absent students: $e');
    }
  }

  /// Teacher: Manually grants Half attendance to a late student
  Future<bool> grantHalfAttendance(String subjectId, String studentId, {String? date}) async {
    try {
      final res = await ApiService.grantHalfAttendance(subjectId, studentId, date: date);
      if (res['status'] == 'Half') {
        // Remove from absent list
        _absentStudents.removeWhere((s) => s['id'] == studentId);
        // Refresh live records
        await fetchTeacherAttendance(subjectId, date: date);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    _sessionCountdownTimer?.cancel();
    super.dispose();
  }
}
