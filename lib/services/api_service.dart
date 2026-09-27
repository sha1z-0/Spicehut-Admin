import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

class ApiService {
  // Backend Configuration - Hardcoded Production URLs
  static const String baseUrl = 'https://spicehut-admin.vercel.app/api';
  static const String socketUrl = 'https://spicehut-admin.vercel.app';

  // Get JWT token from SharedPreferences
  static Future<String?> _getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Build headers with JWT token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getJwtToken();
    final headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> post(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        // Handle specific status codes with user-friendly messages
        if (response.statusCode == 401) {
          // Try to get message from response, fallback to user-friendly message
          try {
            final errorData = jsonDecode(response.body);
            final errorMessage = errorData['message'] ?? 'Wrong email or password';
            throw Exception(errorMessage);
          } catch (e) {
            if (e is Exception && e.toString().contains('Wrong')) {
              rethrow;
            }
            throw Exception('Wrong email or password');
          }
        }
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Request failed';
          throw Exception(errorMessage);
        } catch (e) {
          if (e is Exception && !e.toString().contains('FormatException')) {
            rethrow;
          }
          throw Exception('Request failed with status: ${response.statusCode}');
        }
      }
    } catch (e) {
      LoggerService.error('POST request failed for $endpoint', e, null, 'ApiService');
      rethrow;
    }
  }

  static Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.error('GET request failed for $endpoint', e, null, 'ApiService');
      rethrow;
    }
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.error('PUT request failed for $endpoint', e, null, 'ApiService');
      rethrow;
    }
  }

  static Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      LoggerService.debug('PATCH $baseUrl$endpoint', 'ApiService');
      LoggerService.debug('Headers: ${headers.keys.join(', ')}', 'ApiService');
      LoggerService.debug('Body keys: ${body.keys.join(', ')}', 'ApiService');
      
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );

      LoggerService.debug('Response status: ${response.statusCode}', 'ApiService');
      LoggerService.debug('Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}', 'ApiService');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        // Try to parse error message from response body
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Failed to update: ${response.statusCode}';
          LoggerService.debug('Backend error: $errorMessage', 'ApiService');
          throw Exception(errorMessage);
        } catch (e) {
          if (e.toString().contains('message')) {
            rethrow;
          }
          throw Exception('Failed to update: ${response.statusCode}');
        }
      }
    } catch (e) {
      LoggerService.error('PATCH request failed for $endpoint', e, null, 'ApiService');
      rethrow;
    }
  }

  static Future<void> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      } else {
        throw Exception('Failed to delete: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.error('DELETE request failed for $endpoint', e, null, 'ApiService');
      rethrow;
    }
  }
}
