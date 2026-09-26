import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/profile/presentation/utils/user_initials.dart';

const _user = UserEntity(
  id: 'u1',
  name: 'Ana',
  lastname: 'Lopez',
  dni: '12345678',
  phone: '987654321',
  email: 'ana@test.com',
  image: '',
  role: 'CIUDADANO',
  stateAccount: 'HABILITADO',
  averageScore: 0.0,
  alertsAttended: 0,
);

void main() {
  group('userInitials', () {
    test('returns the first letter of name + lastname, uppercased', () {
      expect(userInitials(_user), 'AL');
    });

    test('falls back to "CS" for a null user', () {
      expect(userInitials(null), 'CS');
    });

    test('accepts a custom fallback', () {
      expect(userInitials(null, fallback: 'U'), 'U');
    });
  });
}
