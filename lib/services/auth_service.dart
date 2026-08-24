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
  static const _defaultBaseUrl = 'https://smartspot-backend-55n9.onrender.com';
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static const _userNameKey = 'auth_user_name';
  static const _userEmailKey = 'auth_user_email';
  static const _userPhoneKey = 'auth_user_phone';
  static const _userBioKey = 'auth_user_bio';
  static const _userAvatarKey = 'auth_user_avatar';
  static const _userSecurityQuestionKey = 'auth_user_security_question';
  static const _userCreatedAtKey = 'auth_user_created_at';

  static const _guestNameKey = 'guest_user_name';
  static const _guestEmailKey = 'guest_user_email';
  static const _guestPhoneKey = 'guest_user_phone';
  static const _guestBioKey = 'guest_user_bio';
  static const _guestAvatarKey = 'guest_user_avatar';

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
    String? phone,
    String? bio,
    String? avatarUrl,
  }) async {
    final body = <String, String>{
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'securityQuestion': securityQuestion.trim(),
      'securityAnswer': securityAnswer.trim(),
    };
    if (phone != null && phone.trim().isNotEmpty) body['phone'] = phone.trim();
    if (bio != null && bio.trim().isNotEmpty) body['bio'] = bio.trim();
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) body['avatarUrl'] = avatarUrl.trim();

    await _authenticate('/api/auth/register', body);
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

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? bio,
    String? avatarUrl,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Not authenticated');
    }
    final body = <String, String>{};
    if (name != null && name.trim().isNotEmpty) body['name'] = name.trim();
    if (email != null && email.trim().isNotEmpty) body['email'] = email.trim();
    if (phone != null) body['phone'] = phone.trim();
    if (bio != null) body['bio'] = bio.trim();
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl.trim();
    if (securityQuestion != null && securityQuestion.trim().isNotEmpty) {
      body['securityQuestion'] = securityQuestion.trim();
    }
    if (securityAnswer != null && securityAnswer.trim().isNotEmpty) {
      body['securityAnswer'] = securityAnswer.trim();
    }

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

    if (data.containsKey('user') && data['user'] is Map) {
      final user = data['user'] as Map<String, dynamic>;
      if (user['name'] != null) {
        await preferences.setString(_userNameKey, user['name'].toString());
      }
      if (user['email'] != null) {
        await preferences.setString(_userEmailKey, user['email'].toString());
      }
      if (user['phone'] != null) {
        await preferences.setString(_userPhoneKey, user['phone'].toString());
      }
      if (user['bio'] != null) {
        await preferences.setString(_userBioKey, user['bio'].toString());
      }
      if (user['avatarUrl'] != null) {
        await preferences.setString(_userAvatarKey, user['avatarUrl'].toString());
      }
      if (user['securityQuestion'] != null) {
        await preferences.setString(_userSecurityQuestionKey, user['securityQuestion'].toString());
      }
      if (user['createdAt'] != null) {
        await preferences.setString(_userCreatedAtKey, user['createdAt'].toString());
      }
    }
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

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, String>> getUserProfile() async {
    final token = await getToken();
    final prefs = await SharedPreferences.getInstance();
    if (token != null && token.isNotEmpty) {
      final cachedName = prefs.getString(_userNameKey);
      final cachedEmail = prefs.getString(_userEmailKey);
      final cachedPhone = prefs.getString(_userPhoneKey) ?? '';
      final cachedBio = prefs.getString(_userBioKey) ?? '';
      final cachedAvatar = prefs.getString(_userAvatarKey) ?? '';
      final cachedSecQuestion = prefs.getString(_userSecurityQuestionKey) ?? '';
      final cachedCreatedAt = prefs.getString(_userCreatedAtKey) ?? '';

      try {
        final profile = await getProfile();
        final name = (profile['name'] as String?)?.trim();
        final email = (profile['email'] as String?)?.trim();
        final phone = profile['phone'] as String? ?? '';
        final bio = profile['bio'] as String? ?? '';
        final avatarUrl = profile['avatarUrl'] as String? ?? '';
        final securityQuestion = profile['securityQuestion'] as String? ?? '';
        final createdAt = profile['createdAt'] as String? ?? '';

        final finalName = (name != null && name.isNotEmpty) ? name : (cachedName ?? 'SmartSpot User');
        final finalEmail = (email != null && email.isNotEmpty) ? email : (cachedEmail ?? 'user@smartspot.app');

        await prefs.setString(_userNameKey, finalName);
        await prefs.setString(_userEmailKey, finalEmail);
        await prefs.setString(_userPhoneKey, phone);
        await prefs.setString(_userBioKey, bio);
        await prefs.setString(_userAvatarKey, avatarUrl);
        await prefs.setString(_userSecurityQuestionKey, securityQuestion);
        if (createdAt.isNotEmpty) await prefs.setString(_userCreatedAtKey, createdAt);

        return {
          'name': finalName,
          'email': finalEmail,
          'phone': phone,
          'bio': bio,
          'avatarUrl': avatarUrl,
          'securityQuestion': securityQuestion,
          'createdAt': createdAt,
          'isGuest': 'false',
        };
      } catch (_) {
        return {
          'name': cachedName ?? 'SmartSpot User',
          'email': cachedEmail ?? 'user@smartspot.app',
          'phone': cachedPhone,
          'bio': cachedBio,
          'avatarUrl': cachedAvatar,
          'securityQuestion': cachedSecQuestion,
          'createdAt': cachedCreatedAt,
          'isGuest': 'false',
        };
      }
    }
    return {
      'name': prefs.getString(_guestNameKey) ?? 'Guest User',
      'email': prefs.getString(_guestEmailKey) ?? 'guest@smartspot.app',
      'phone': prefs.getString(_guestPhoneKey) ?? '',
      'bio': prefs.getString(_guestBioKey) ?? '',
      'avatarUrl': prefs.getString(_guestAvatarKey) ?? '',
      'securityQuestion': '',
      'createdAt': '',
      'isGuest': 'true',
    };
  }

  Future<void> updateUserProfile({
    required String name,
    required String email,
    String? phone,
    String? bio,
    String? avatarUrl,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    final token = await getToken();
    final prefs = await SharedPreferences.getInstance();
    if (token != null && token.isNotEmpty) {
      final updatedUser = await updateProfile(
        name: name,
        email: email,
        phone: phone,
        bio: bio,
        avatarUrl: avatarUrl,
        securityQuestion: securityQuestion,
        securityAnswer: securityAnswer,
      );
      final newName = updatedUser['name'] as String? ?? name.trim();
      final newEmail = updatedUser['email'] as String? ?? email.trim();
      final newPhone = updatedUser['phone'] as String? ?? (phone ?? '').trim();
      final newBio = updatedUser['bio'] as String? ?? (bio ?? '').trim();
      final newAvatar = updatedUser['avatarUrl'] as String? ?? (avatarUrl ?? '').trim();
      final newSecQ = updatedUser['securityQuestion'] as String? ?? (securityQuestion ?? '').trim();

      await prefs.setString(_userNameKey, newName);
      await prefs.setString(_userEmailKey, newEmail);
      await prefs.setString(_userPhoneKey, newPhone);
      await prefs.setString(_userBioKey, newBio);
      await prefs.setString(_userAvatarKey, newAvatar);
      await prefs.setString(_userSecurityQuestionKey, newSecQ);
    } else {
      await prefs.setString(_guestNameKey, name.trim());
      await prefs.setString(_guestEmailKey, email.trim());
      if (phone != null) await prefs.setString(_guestPhoneKey, phone.trim());
      if (bio != null) await prefs.setString(_guestBioKey, bio.trim());
      if (avatarUrl != null) await prefs.setString(_guestAvatarKey, avatarUrl.trim());
    }
  }

  Future<void> signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_userNameKey);
    await preferences.remove(_userEmailKey);
    await preferences.remove(_userPhoneKey);
    await preferences.remove(_userBioKey);
    await preferences.remove(_userAvatarKey);
    await preferences.remove(_userSecurityQuestionKey);
    await preferences.remove(_userCreatedAtKey);
  }
}