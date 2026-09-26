import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/core/theme/app_colors.dart';
import 'package:saeta_ciudadano_v2/features/profile/presentation/utils/account_state_label.dart';

void main() {
  group('accountStateLabel', () {
    test('HABILITADO (case-insensitive, trimmed) maps to the enabled label '
        'and the resuelta palette', () {
      expect(
        accountStateLabel('HABILITADO'),
        const AccountStateLabel(
          text: 'Cuenta habilitada',
          palette: AppColors.resuelta,
        ),
      );
      expect(
        accountStateLabel(' habilitado '),
        const AccountStateLabel(
          text: 'Cuenta habilitada',
          palette: AppColors.resuelta,
        ),
      );
    });

    test('any other value maps to the disabled label and the cancelada '
        'palette (including a value that merely contains "HABILITADO", e.g. '
        '"DESHABILITADO")', () {
      expect(
        accountStateLabel('DESHABILITADO'),
        const AccountStateLabel(
          text: 'Cuenta deshabilitada',
          palette: AppColors.cancelada,
        ),
      );
      expect(
        accountStateLabel(''),
        const AccountStateLabel(
          text: 'Cuenta deshabilitada',
          palette: AppColors.cancelada,
        ),
      );
    });
  });
}
