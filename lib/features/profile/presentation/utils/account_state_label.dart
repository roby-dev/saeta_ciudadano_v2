import 'package:flutter/foundation.dart';
import '../../../../core/theme/app_colors.dart';

/// "Mi perfil" identity card account-state pill: text + the [AlertStatePalette]
/// to render it with, derived from `UserEntity.stateAccount`.
@immutable
class AccountStateLabel {
  const AccountStateLabel({required this.text, required this.palette});

  final String text;
  final AlertStatePalette palette;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountStateLabel &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          palette == other.palette;

  @override
  int get hashCode => Object.hash(text, palette);
}

/// Maps a raw `stateAccount` (e.g. `HABILITADO`/`DESHABILITADO`) to its
/// pill label/palette. Matches the exact enabled value
/// (case-insensitive, trimmed) rather than a substring check, since
/// `DESHABILITADO` itself contains `HABILITADO`.
AccountStateLabel accountStateLabel(String stateAccount) {
  final enabled = stateAccount.trim().toUpperCase() == 'HABILITADO';
  return enabled
      ? const AccountStateLabel(
          text: 'Cuenta habilitada',
          palette: AppColors.resuelta,
        )
      : const AccountStateLabel(
          text: 'Cuenta deshabilitada',
          palette: AppColors.cancelada,
        );
}
