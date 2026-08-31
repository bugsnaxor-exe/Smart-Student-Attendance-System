import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isStudent => _currentUser?.role == 'STUDENT';
  bool get isTeacher => _currentUser?.role == 'TEACHER' || _currentUser?.role == 'ADMIN';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
        notifyListeners();
      } catch (e) {
        await logout();
      }
    }
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.login(identifier, password);
      if (res['user'] != null) {
        _currentUser = UserModel.fromJson(res['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['error'] ?? 'Login failed.';
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
        // Auto-login with credentials
        return await login(email, password);
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    _currentUser = null;
    notifyListeners();
  }
}
