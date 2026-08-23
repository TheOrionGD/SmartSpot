import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/services/auth_service.dart';

void main() {
  group('AuthService Unit Tests', () {
    test('AuthService singleton instance is provided', () {
      expect(AuthService.instance, isNotNull);
    });

    test('AuthException formats exception message correctly', () {
      const ex = AuthException('Invalid email or password');
      expect(ex.toString(), equals('Invalid email or password'));
    });

    test('AuthService baseUrl defaults to valid HTTP endpoint', () {
      expect(AuthService.baseUrl, isNotEmpty);
      expect(AuthService.baseUrl.startsWith('http'), isTrue);
    });
  });
}
