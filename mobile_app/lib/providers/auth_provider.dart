import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import '../models/user_model.dart';

class LoginResult {
  final bool success;
  final bool requiresOtp;
  final String? email;
  final String? error;

  LoginResult({
    required this.success,
    this.requiresOtp = false,
    this.email,
    this.error,
  });
}

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null && _token != null && (_currentUser?.role != 'TEACHER' || _currentUser?.teacher?.isApproved == true || _currentUser?.role == 'ADMIN');
  bool get isStudent => _currentUser?.role == 'STUDENT';
  bool get isTeacher => _currentUser?.role == 'TEACHER' || _currentUser?.role == 'ADMIN';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');
      final token = prefs.getString('auth_token');

      if (userJson != null && token != null && token.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(userJson);
        final user = UserModel.fromJson(decoded);
        if (user.role == 'ADMIN' || user.role == 'STUDENT' || user.teacher?.isApproved == true) {
          _currentUser = user;
          _token = token;
          notifyListeners();
        } else {
          await prefs.remove('auth_token');
          await prefs.remove('user_data');
          _currentUser = null;
          _token = null;
        }
      }
    } catch (e) {
      debugPrint('Session restore note: $e');
    }
  }

  Future<LoginResult> login(String identifier, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.login(identifier, password);
      _isLoading = false;

      if (res['requiresOtp'] == true) {
        notifyListeners();
        return LoginResult(
          success: false,
          requiresOtp: true,
          email: res['email'] ?? identifier,
        );
      }

      if (res['user'] != null) {
        final user = UserModel.fromJson(res['user']);
        final isApproved = user.role == 'ADMIN' || user.role == 'STUDENT' || user.teacher?.isApproved == true;
        final token = res['token'] as String?;

        if (isApproved && token != null) {
          _currentUser = user;
          _token = token;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_data', jsonEncode(res['user']));
          notifyListeners();
          return LoginResult(success: true);
        } else {
          _currentUser = null;
          _token = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          await prefs.remove('user_data');
          _errorMessage = 'Your faculty registration is pending verification and approval by the Administrator.';
          notifyListeners();
          return LoginResult(success: false, error: _errorMessage);
        }
      } else {
        _errorMessage = res['error'] ?? 'Login failed.';
        notifyListeners();
        return LoginResult(success: false, error: _errorMessage);
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return LoginResult(success: false, error: _errorMessage);
    }
  }

  Future<bool> verifyFacultyOtp(String email, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.verifyOtp(email, otp);
      _isLoading = false;

      if (res['user'] != null) {
        final user = UserModel.fromJson(res['user']);
        final isApproved = user.role == 'ADMIN' || user.teacher?.isApproved == true;
        final token = res['token'] as String?;

        if (isApproved && token != null) {
          _currentUser = user;
          _token = token;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_data', jsonEncode(res['user']));
          notifyListeners();
          return true;
        } else {
          _currentUser = null;
          _token = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          await prefs.remove('user_data');
          _errorMessage = 'Your faculty registration is pending verification and approval by the Administrator.';
          notifyListeners();
          return false;
        }
      } else {
        _errorMessage = res['error'] ?? 'Invalid or expired OTP.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendFacultyOtp(String email) async {
    try {
      final res = await ApiService.resendOtp(email);
      return res['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> registerStudent({
    required String name,
    required String email,
    required String password,
    required String classRoll,
    required String universityRoll,
    required String regNumber,
    required String departmentCode,
    required int semester,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.registerStudent({
        'name': name,
        'email': email,
        'password': password,
        'classRoll': classRoll,
        'universityRoll': universityRoll,
        'regNumber': regNumber,
        'departmentCode': departmentCode,
        'semester': semester,
      });

      if (res['user'] != null) {
        final loginRes = await login(universityRoll, password);
        return loginRes.success;
      } else {
        _errorMessage = res['error'] ?? 'Registration failed.';
        _isLoading = false;
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

  Future<bool> registerTeacher({
    required String name,
    required String email,
    required String password,
    String departmentCode = 'MCA',
    int? semester,
    String? subjectCode,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.registerTeacher({
        'name': name,
        'email': email,
        'password': password,
        'departmentCode': departmentCode,
        if (semester != null) 'semester': semester,
        if (subjectCode != null) 'subjectCode': subjectCode,
      });

      _isLoading = false;
      if (res['user'] != null) {
        final isApproved = res['isApproved'] == true;
        final token = res['token'] as String?;

        if (isApproved && token != null) {
          _currentUser = UserModel.fromJson(res['user']);
          _token = token;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_data', jsonEncode(res['user']));
          notifyListeners();
          return true;
        } else {
          _currentUser = null;
          _token = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          await prefs.remove('user_data');
          _errorMessage = res['message'] ?? 'Faculty registration submitted! Awaiting Administrator approval before login.';
          notifyListeners();
          return true;
        }
      } else {
        _errorMessage = res['error'] ?? 'Faculty registration failed.';
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    _currentUser = null;
    _token = null;
    notifyListeners();
  }
}
