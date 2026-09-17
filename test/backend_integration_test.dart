import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Backend Integration Tests', () {
    test('JWT Token Storage', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Simulate storing JWT token after login
        const token =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhZG1pbklkIjoiNjk2YjlmNTg2NTE1MTQxYWIyNWVjMDFiIiwiZW1haWwiOiJhZG1pbi5jb21veEBzcGljZWh1dC5jb20iLCJyb2xlIjoiYnJhbmNoQWRtaW4iLCJicmFuY2giOiJDb21veCIsImJyYW5jaGVzIjpbXSwiaWF0IjoxNzY4NjYxMDQ0LCJleHAiOjE3Njg3NDc0NDR9.cCAIrpIbONOedEAbJ7idU5o5iR-Gh-FSvI9Pc3A-Ii4';
      await prefs.setString('jwt_token', token);

      // Verify token is stored
      expect(prefs.getString('jwt_token'), equals(token));
    });

    test('Location Storage', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Simulate storing user location (branch)
      await prefs.setString('user_location', 'Comox');

      // Verify location is stored
      expect(prefs.getString('user_location'), equals('Comox'));
    });

    test('Admin Role Storage', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Simulate storing user role
      await prefs.setString('user_role', 'UserRole.manager');

      // Verify role is stored
      expect(prefs.getString('user_role'), equals('UserRole.manager'));
    });
  });
}
