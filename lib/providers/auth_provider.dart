import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;

  bool _isLoggedIn = false;
  bool _isLoading = true;
  String _name = 'Guest User';
  String _email = 'guest@smartspot.app';
  String _phone = '';
  String _bio = '';
  String _avatarUrl = '';
  String _securityQuestion = '';
  String _createdAt = '';

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String get name => _name;
  String get email => _email;
  String get phone => _phone;
  String get bio => _bio;
  String get avatarUrl => _avatarUrl;
  String get securityQuestion => _securityQuestion;
  String get createdAt => _createdAt;

  AuthProvider() {
    checkAuthState();
  }

  Future<void> checkAuthState() async {
    _isLoading = true;
    notifyListeners();
    try {
      final profile = await _authService.getUserProfile();
      _name = profile['name'] ?? 'Guest User';
      _email = profile['email'] ?? 'guest@smartspot.app';
      _phone = profile['phone'] ?? '';
      _bio = profile['bio'] ?? '';
      _avatarUrl = profile['avatarUrl'] ?? '';
      _securityQuestion = profile['securityQuestion'] ?? '';
      _createdAt = profile['createdAt'] ?? '';
      _isLoggedIn = profile['isGuest'] != 'true';
    } catch (e) {
      _isLoggedIn = false;
      debugPrint('Error checking auth state: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    await _authService.login(email: email, password: password);
    await checkAuthState();
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
    await _authService.register(
      name: name,
      email: email,
      password: password,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      phone: phone,
      bio: bio,
      avatarUrl: avatarUrl,
    );
    await checkAuthState();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    String? phone,
    String? bio,
    String? avatarUrl,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    await _authService.updateUserProfile(
      name: name,
      email: email,
      phone: phone,
      bio: bio,
      avatarUrl: avatarUrl,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    );
    await checkAuthState();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> logout() async {
    await _authService.signOut();
    await checkAuthState();
  }
}
