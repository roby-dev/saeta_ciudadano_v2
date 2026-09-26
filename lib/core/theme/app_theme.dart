import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Corner radii from the approved redesign canvas.
class AppRadii {
  const AppRadii._();

  /// Regular cards (`SectionCard`, `AlertCard`, list tiles).
  static const double card = 12.0;

  /// Hero cards (SOS circle container, summary cards) with the soft shadow
  /// `0 4 16 rgba(43,53,79,.10)`.
  static const double heroCard = 16.0;

  /// Buttons and inputs.
  static const double control = 10.0;
}

/// Fixed sizes from the approved redesign canvas.
class AppDimens {
  const AppDimens._();

  /// Buttons/inputs height.
  static const double controlHeight = 48.0;

  /// Minimum touch target (accessibility floor for tappable controls).
  static const double minTouchTarget = 44.0;

  /// Bottom navigation bar height and its active-item top indicator bar.
  static const double bottomNavHeight = 64.0;
  static const double bottomNavIndicatorThickness = 3.0;
}

/// Bundled font families (see `assets/fonts/`, declared in `pubspec.yaml`).
class AppFonts {
  const AppFonts._();

  /// UI copy (headings, body, buttons, inputs).
  static const String sans = 'IBM Plex Sans';

  /// Coordinates, phone numbers and IDs.
  static const String mono = 'IBM Plex Mono';

  /// Convenience style for [mono] text; `ThemeData.textTheme` only carries
  /// one default font family ([sans]), so callers apply this explicitly on
  /// the specific coordinate/phone/ID text.
  static const TextStyle monoLabel = TextStyle(
    fontFamily: mono,
    fontWeight: FontWeight.w500,
  );
}

/// `ThemeData` for the approved redesign canvas ("Frontend v2 palette, pro
/// look"). Material 3; colors/typography/radii come from [AppColors],
/// [AppRadii] and [AppFonts] so every screen restyle reuses the same tokens.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryTint,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.primaryDark,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerTint,
      onErrorContainer: AppColors.danger,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      outline: AppColors.border,
      outlineVariant: AppColors.secondaryBorder,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
      borderSide: const BorderSide(color: AppColors.secondaryBorder),
    );

    const buttonMinimumSize = Size.fromHeight(AppDimens.controlHeight);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    );
    const buttonTextStyle = TextStyle(fontWeight: FontWeight.w600);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppFonts.sans,
      textTheme: _textTheme,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.muted,
          minimumSize: buttonMinimumSize,
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.muted,
          minimumSize: buttonMinimumSize,
          shape: buttonShape,
          elevation: 0,
          textStyle: buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: buttonMinimumSize,
          shape: buttonShape,
          side: const BorderSide(color: AppColors.secondaryBorder),
          textStyle: buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: buttonMinimumSize,
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.background,
        labelStyle: TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: AppColors.border),
        shape: StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryTint;
          }
          return AppColors.border;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: AppDimens.bottomNavHeight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.muted,
          );
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.heading,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.heading,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 14,
          color: AppColors.text,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.heroCard),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static const TextTheme _textTheme = TextTheme(
    headlineSmall: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.heading,
    ),
    titleLarge: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.heading,
    ),
    titleMedium: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.heading,
    ),
    titleSmall: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.heading,
    ),
    bodyLarge: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 15,
      color: AppColors.text,
    ),
    bodyMedium: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 14,
      color: AppColors.text,
    ),
    bodySmall: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 13,
      color: AppColors.muted,
    ),
    labelLarge: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    ),
    labelMedium: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 13,
      color: AppColors.muted,
    ),
    labelSmall: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 12,
      color: AppColors.muted,
    ),
  );
}
