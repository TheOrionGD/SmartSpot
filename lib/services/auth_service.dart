import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const _tokenKey = 'auth_token';
  // Production URL (commented out for system testing)
  // static const _defaultBaseUrl = 'https://smartspot-backend-55n9.onrender.com';
  // Localhost URL for system testing
  static const _defaultBaseUrl = 'http://localhost:3000';
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  Future<void> login({required String email, required String password}) async {
    await _authenticate('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    await _authenticate('/api/auth/register', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'securityQuestion': securityQuestion.trim(),
      'securityAnswer': securityAnswer.trim(),
    });
  }

  Future<String> getSecurityQuestion(String email) async {
    final data = await _request('/api/auth/security-question', {
      'email': email.trim(),
    });
    return data['securityQuestion'] as String;
  }

  Future<void> resetPassword({
    required String email,
    required String securityAnswer,
    required String newPassword,
  }) async {
    await _request('/api/auth/reset-password', {
      'email': email.trim(),
      'securityAnswer': securityAnswer.trim(),
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Not authenticated');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 12));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(data['error'] as String? ?? 'Failed to fetch user profile');
    }
    return data['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({String? name, String? email}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Not authenticated');
    }
    final body = <String, String>{};
    if (name != null && name.trim().isNotEmpty) body['name'] = name.trim();
    if (email != null && email.trim().isNotEmpty) body['email'] = email.trim();

    final response = await http.put(
      Uri.parse('$baseUrl/api/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 12));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(data['error'] as String? ?? 'Failed to update profile');
    }
    return data['user'] as Map<String, dynamic>;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Not authenticated');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    ).timeout(const Duration(seconds: 12));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(data['error'] as String? ?? 'Failed to change password');
    }
  }

  Future<void> _authenticate(String path, Map<String, String> body) async {
    final data = await _request(path, body);
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const AuthException('The server returned no authentication token');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }

  Future<Map<String, dynamic>> _request(String path, Map<String, String> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(data['error'] as String? ?? 'Authentication failed');
      }

      return data;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Unable to connect to SmartSpot. Check your internet connection and API URL.',
      );
    }
  }

  Future<String?> getToken() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_tokenKey);
  }

  Future<void> signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }
}