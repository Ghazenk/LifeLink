import 'package:flutter/material.dart';

/// Figma's navy identity with the quiet surfaces in apple-DESIGN.md.
class AppTheme {
  static const primaryBlue = Color(0xFF0066CC);
  static const primaryFocus = Color(0xFF0071E3);
  static const navy = Color(0xFF1B3B5D);
  static const ink = Color(0xFF1D1D1F);
  static const canvas = Colors.white;
  static const canvasParchment = Color(0xFFF5F5F7);
  static const darkTile1 = Color(0xFF272729);
  static const darkTile2 = Color(0xFF2A2A2C);
  static const darkSurface = Color(0xFF141619);

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? darkTile1 : canvas;
    final border = dark ? const Color(0xFF41454B) : const Color(0xFFDFE5ED);
    final muted = dark ? const Color(0xFFB4BEC9) : const Color(0xFF65758A);
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: brightness,
      primary: dark ? const Color(0xFF75B6FF) : primaryBlue,
      onPrimary: dark ? darkSurface : Colors.white,
      surface: surface,
      onSurface: dark ? Colors.white : ink,
      onSurfaceVariant: muted,
      outlineVariant: border,
      primaryContainer: dark ? navy : const Color(0xFFEAF2FC),
      onPrimaryContainer: dark ? Colors.white : navy,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'LifeLinkRoboto',
      fontFamilyFallback: const ['Arial'],
    );
    final text = base.textTheme.copyWith(
      headlineLarge: TextStyle(
        fontSize: 34,
        height: 1.15,
        letterSpacing: -0.8,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.2,
        letterSpacing: -0.6,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        height: 1.3,
        letterSpacing: -0.3,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 1.47, color: scheme.onSurface),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.47,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: muted),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide(color: border),
    );
    final button = FilledButton.styleFrom(
      minimumSize: const Size(44, 48),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontFamily: 'LifeLinkRoboto',
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
    return base.copyWith(
      textTheme: text.apply(fontFamily: 'Segoe UI'),
      scaffoldBackgroundColor: dark ? darkSurface : canvasParchment,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: TextStyle(color: muted),
        prefixIconColor: muted,
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: button.copyWith(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(scheme.primary),
          foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        height: 76,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: muted),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: text.labelSmall,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        iconColor: scheme.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(scheme.primaryContainer),
        headingTextStyle: text.labelLarge,
        dataRowMinHeight: 56,
        dataRowMaxHeight: 80,
        dividerThickness: 0.5,
      ),
    );
  }
}
