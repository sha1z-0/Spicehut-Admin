import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'logger_service.dart';

enum UserRole { admin, manager, staff }

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _roleKey = 'user_role';
  static const String _locationKey = 'user_location';
  static const String _nameKey = 'user_name';

  String? lastError;

  Future<bool> login(String username, String password) async {
    lastError = null;
    try {
      final response = await ApiService.post('/auth/login', {
        'email': username,
        'password': password,
      });

      if (response != null &&
          response['success'] == true &&
          response.containsKey('admin')) {
        final admin = response['admin'];
        final adminId = admin['adminId'];
        final roleStr = admin['role']?.toString();
        final role = roleStr == 'admin'
          ? UserRole.admin
          : roleStr == 'staff'
            ? UserRole.staff
            : UserRole.manager;
        final location = admin['branch']; // Store branch if present
        final name = admin['name']?.toString();

        // Store JWT token
        final prefs = await SharedPreferences.getInstance();
        final token = response['token'];
        await prefs.setString('jwt_token', token);

        await _saveSession(adminId, role, location, name);
        return true;
      }

      lastError = 'Login failed. Please check your credentials.';
      return false;
    } catch (e) {
      LoggerService.error('Login failed', e, null, 'AuthService');
      lastError = e.toString().replaceAll('Exception: ', '');
      return false;
    }
  }

  Future<void> _saveSession(
      String token, UserRole role, String? location, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_roleKey, role.toString());
    if (location != null) {
      await prefs.setString(_locationKey, location);
    } else {
      await prefs.remove(_locationKey);
    }
    if (name != null && name.isNotEmpty) {
      await prefs.setString(_nameKey, name);
    } else {
      await prefs.remove(_nameKey);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_locationKey);
    await prefs.remove(_nameKey);
  }

  Future<UserRole?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString(_roleKey);
    if (roleStr == UserRole.admin.toString()) return UserRole.admin;
    if (roleStr == UserRole.manager.toString()) return UserRole.manager;
    if (roleStr == UserRole.staff.toString()) return UserRole.staff;
    return null;
  }

  Future<String?> getUserLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_locationKey);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_nameKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final response = await ApiService.get('/auth/me');
      if (response != null && response['success'] == true) {
        final admin = response['admin'];
        final name = admin?['name']?.toString();
        if (name != null && name.isNotEmpty) {
          await prefs.setString(_nameKey, name);
          return name;
        }
      }
    } catch (_) {
      // ignore fetch errors
    }

    return null;
  }
}
