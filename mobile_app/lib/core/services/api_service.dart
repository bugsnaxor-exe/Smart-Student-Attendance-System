import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiService {
  static String baseUrl = AppConstants.defaultApiBaseUrl;

  static Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    if (requireAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // --- AUTH ---
  static Future<Map<String, dynamic>> registerStudent(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register-student'),
      headers: await _getHeaders(requireAuth: false),
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> registerTeacher(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register-teacher'),
      headers: await _getHeaders(requireAuth: false),
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _getHeaders(requireAuth: false),
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', body['token']);
      await prefs.setString('user_data', jsonEncode(body['user']));
    }
    return body;
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: await _getHeaders(requireAuth: false),
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', body['token']);
      await prefs.setString('user_data', jsonEncode(body['user']));
    }
    return body;
  }

  static Future<Map<String, dynamic>> resendOtp(String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/resend-otp'),
      headers: await _getHeaders(requireAuth: false),
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  // --- STUDENT ATTENDANCE FLOW ---
  static Future<Map<String, dynamic>> getStudentDashboard() async {
    final res = await http.get(
      Uri.parse('$baseUrl/attendance/student/dashboard'),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getStudentActiveSessions() async {
    final res = await http.get(
      Uri.parse('$baseUrl/sessions/student-active'),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> markAttendance({
    required String subjectId,
    required double latitude,
    required double longitude,
    bool isMockLocation = false,
    double? accuracyMeters,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/attendance/mark'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'subjectId': subjectId,
        'latitude': latitude,
        'longitude': longitude,
        'isMockLocation': isMockLocation,
        'accuracyMeters': accuracyMeters,
      }),
    );
    return jsonDecode(res.body);
  }

  // --- TEACHER ACTIVE SESSION & OVERRIDE FLOW ---
  static Future<Map<String, dynamic>> startTeacherSession(
    String subjectId, {
    int durationMinutes = 15,
    double? latitude,
    double? longitude,
    double? radiusMeters,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/sessions/start'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'subjectId': subjectId,
        'durationMinutes': durationMinutes,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (radiusMeters != null) 'radiusMeters': radiusMeters,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateSessionLocation({
    String? subjectId,
    String? sessionId,
    required double latitude,
    required double longitude,
    double radiusMeters = 50.0,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/sessions/update-location'),
      headers: await _getHeaders(),
      body: jsonEncode({
        if (subjectId != null) 'subjectId': subjectId,
        if (sessionId != null) 'sessionId': sessionId,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getTeacherActiveSession(String subjectId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/sessions/active/$subjectId'),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getTeacherAttendanceRecords(String subjectId, {String? date}) async {
    String url = '$baseUrl/attendance/teacher/$subjectId';
    if (date != null) url += '?date=$date';

    final res = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getAbsentStudents(String subjectId, {String? date, String? sessionId}) async {
    String url = '$baseUrl/override/absent/$subjectId';
    final queryParams = <String>[];
    if (date != null) queryParams.add('date=$date');
    if (sessionId != null) queryParams.add('sessionId=$sessionId');
    if (queryParams.isNotEmpty) url += '?${queryParams.join('&')}';

    final res = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> grantFullAttendance(String subjectId, String studentId, {String? date, String? sessionId}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/override/grant-full'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'subjectId': subjectId,
        'studentId': studentId,
        'date': date,
        if (sessionId != null) 'sessionId': sessionId,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> grantHalfAttendance(String subjectId, String studentId, {String? date, String? sessionId}) =>
      grantFullAttendance(subjectId, studentId, date: date, sessionId: sessionId);

  static Future<Map<String, dynamic>> getTodaySessionCounts() async {
    final res = await http.get(
      Uri.parse('$baseUrl/sessions/counts-today'),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  // --- STUDENT ATTENDANCE HISTORY ---
  static Future<Map<String, dynamic>> getStudentSubjectHistory(String subjectId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/attendance/student/subject-history/$subjectId'),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getStudentsBySemester(int semester, {String? batchYear, String? deptCode}) async {
    final queryParams = <String, String>{};
    if (batchYear != null && batchYear.isNotEmpty) queryParams['batchYear'] = batchYear;
    if (deptCode != null && deptCode.isNotEmpty) queryParams['deptCode'] = deptCode;
    
    final uri = Uri.parse('$baseUrl/override/students/semester/$semester').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final res = await http.get(
      uri,
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> closeSession(String sessionId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/sessions/close/$sessionId'),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> closeSessionBySubject(String subjectId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/sessions/close-subject/$subjectId'),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  // --- GOOGLE SHEETS MANAGEMENT ---
  static Future<Map<String, dynamic>> getActiveSheet() async {
    final res = await http.get(
      Uri.parse('$baseUrl/sheets/active-sheet'),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> linkGlobalSheet(String spreadsheetId, {String? tabName}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/sheets/link-sheet'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'googleSheetId': spreadsheetId,
        'spreadsheetId': spreadsheetId,
        'sheetTabName': tabName ?? 'Attendance',
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getServiceAccountInfo() async {
    final res = await http.get(
      Uri.parse('$baseUrl/sheets/service-account'),
      headers: await _getHeaders(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> linkTeacherSheet(String subjectId, String googleSheetId, {String? tabName}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/sheets/link/$subjectId'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'googleSheetId': googleSheetId,
        'sheetTabName': tabName ?? 'Attendance',
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> testSheetConnection(String spreadsheetId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/sheets/test-connection'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'spreadsheetId': spreadsheetId,
        'save': true,
      }),
    );
    return jsonDecode(res.body);
  }
}
