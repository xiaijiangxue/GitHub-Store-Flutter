import 'package:flutter/material.dart';

/// Enum for all available color schemes in the app.
enum ColorSchemeType {
  github,
  ocean,
  forest,
  sunset,
  lavender,
  rose,
  ;

  /// Display name for the UI.
  String get displayName => switch (this) {
        ColorSchemeType.github => 'GitHub',
        ColorSchemeType.ocean => 'Ocean',
        ColorSchemeType.forest => 'Forest',
        ColorSchemeType.sunset => 'Sunset',
        ColorSchemeType.lavender => 'Lavender',
        ColorSchemeType.rose => 'Rose',
      };

  /// Color preview swatch for settings.
  Color get previewColor => switch (this) {
        ColorSchemeType.github => const Color(0xFF238636),
        ColorSchemeType.ocean => const Color(0xFF0969DA),
        ColorSchemeType.forest => const Color(0xFF1A7F37),
        ColorSchemeType.sunset => const Color(0xFFD29922),
        ColorSchemeType.lavender => const Color(0xFF8B5CF6),
        ColorSchemeType.rose => const Color(0xFFE85D75),
      };

}

/// Complete theme system for GitHub Store with 6 color schemes × 3 modes.
class AppTheme {
  AppTheme._();

  // ── Light Themes ───────────────────────────────────────────────────────

  static ThemeData lightTheme(int colorSchemeIndex) {
    final scheme = ColorSchemeType.values[colorSchemeIndex.clamp(0, 5)];
    return _buildTheme(scheme, _Mode.light);
  }

  // ── Dark Themes ────────────────────────────────────────────────────────

  static ThemeData darkTheme(int colorSchemeIndex) {
    final scheme = ColorSchemeType.values[colorSchemeIndex.clamp(0, 5)];
    return _buildTheme(scheme, _Mode.dark);
  }

  // ── AMOLED Themes ──────────────────────────────────────────────────────

  static ThemeData amoledTheme(int colorSchemeIndex) {
    final scheme = ColorSchemeType.values[colorSchemeIndex.clamp(0, 5)];
    return _buildTheme(scheme, _Mode.amoled);
  }

  // ── Builder ────────────────────────────────────────────────────────────

  static ThemeData _buildTheme(ColorSchemeType scheme, _Mode mode) {
    final colors = _ColorPalettes.get(scheme, mode);
    final isDark = mode != _Mode.light;
    final isAmoled = mode == _Mode.amoled;

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.onPrimaryContainer,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      secondaryContainer: colors.secondaryContainer,
      onSecondaryContainer: colors.onSecondaryContainer,
      tertiary: colors.tertiary,
      onTertiary: colors.onTertiary,
      tertiaryContainer: colors.tertiaryContainer,
      onTertiaryContainer: colors.onTertiaryContainer,
      error: colors.error,
      onError: colors.onError,
      errorContainer: colors.errorContainer,
      onErrorContainer: colors.onErrorContainer,
      surface: colors.surface,
      onSurface: colors.onSurface,
      surfaceContainerHighest: colors.surfaceVariant,
      outline: colors.outline,
      outlineVariant: colors.outlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.surface,
      cardColor: colors.card,
      dividerColor: colors.outlineVariant,

      // ── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        backgroundColor: isAmoled
            ? const Color(0xFF000000)
            : isDark
                ? const Color(0xFF161B22)
                : Colors.white,
        foregroundColor: colors.onSurface,
        surfaceTintColor: colors.primary.withOpacity( 0.08),
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: colors.onSurface, size: 24),
      ),

      // ── Card ───────────────────────────────────────────────────────────
      cardTheme: CardTheme(
        elevation: 0,
        color: colors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant.withOpacity( 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Elevated Button ────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Text Button ────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── Outlined Button ────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide(color: colors.outline),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── Filled Button ──────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Icon Button ────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // ── Input / Text Field ─────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isAmoled
            ? const Color(0xFF0D0D0D)
            : isDark
                ? const Color(0xFF0D1117)
                : const Color(0xFFF6F8FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCF222E)),
        ),
        hintStyle: TextStyle(
          color: colors.outline,
          fontSize: 14,
        ),
      ),

      // ── Bottom Navigation Bar ──────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: isAmoled
            ? const Color(0xFF0A0A0A)
            : isDark
                ? const Color(0xFF0D1117)
                : Colors.white,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.outline,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        elevation: 8,
      ),

      // ── Navigation Rail ────────────────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isAmoled
            ? const Color(0xFF0A0A0A)
            : isDark
                ? const Color(0xFF0D1117)
                : Colors.white,
        selectedIconTheme: IconThemeData(color: colors.primary, size: 24),
        unselectedIconTheme: IconThemeData(color: colors.outline, size: 24),
        selectedLabelTextStyle: TextStyle(
          color: colors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colors.outline,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        useIndicator: true,
        indicatorColor: colors.primary.withOpacity( 0.12),
      ),

      // ── Chip ───────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isAmoled
            ? const Color(0xFF1A1A1A)
            : isDark
                ? const Color(0xFF21262D)
                : const Color(0xFFF6F8FA),
        labelStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // ── Dialog ─────────────────────────────────────────────────────────
      dialogTheme: DialogTheme(
        backgroundColor: isAmoled
            ? const Color(0xFF0D0D0D)
            : isDark
                ? const Color(0xFF161B22)
                : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 14,
        ),
      ),

      // ── Bottom Sheet ───────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isAmoled
            ? const Color(0xFF0D0D0D)
            : isDark
                ? const Color(0xFF161B22)
                : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // ── Tooltip ────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D333B) : const Color(0xFF1F2328),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),

      // ── Divider ────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Snackbar ───────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2D333B) : const Color(0xFF1F2328),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      ),

      // ── Tab Bar ────────────────────────────────────────────────────────
      tabBarTheme: TabBarTheme(
        labelColor: colors.primary,
        unselectedLabelColor: colors.outline,
        indicatorColor: colors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      ),

      // ── Floating Action Button ─────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Progress Indicator ─────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.outlineVariant,
      ),

      // ── Switch ─────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return isDark ? const Color(0xFF8B949E) : const Color(0xFF8B949E);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary.withOpacity( 0.5);
          }
          return isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);
        }),
      ),

      // ── Checkbox ───────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Radio ──────────────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return isDark ? const Color(0xFF8B949E) : const Color(0xFF8B949E);
        }),
      ),

      // ── Slider ─────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.outlineVariant,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withOpacity( 0.12),
      ),

      // ── Scrollbar ──────────────────────────────────────────────────────
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(colors.outline.withOpacity( 0.4)),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(6),
        thickness: WidgetStateProperty.all(8),
        thumbVisibility: WidgetStateProperty.all(true),
      ),

      // ── Text Theme ─────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: colors.onSurface,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: colors.onSurface,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        displaySmall: TextStyle(
          color: colors.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: TextStyle(
          color: colors.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        headlineMedium: TextStyle(
          color: colors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: colors.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: colors.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: colors.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: colors.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: colors.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: colors.outline,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: colors.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(
          color: colors.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: colors.outline,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Color Palette Definitions ────────────────────────────────────────────

enum _Mode { light, dark, amoled }

class _ColorPalettes {
  _ColorPalettes._();

  static _Palette get(ColorSchemeType scheme, _Mode mode) {
    return switch (scheme) {
      ColorSchemeType.github => mode == _Mode.light
          ? _githubLight
          : mode == _Mode.dark
              ? _githubDark
              : _githubAmoled,
      ColorSchemeType.ocean => mode == _Mode.light
          ? _oceanLight
          : mode == _Mode.dark
              ? _oceanDark
              : _oceanAmoled,
      ColorSchemeType.forest => mode == _Mode.light
          ? _forestLight
          : mode == _Mode.dark
              ? _forestDark
              : _forestAmoled,
      ColorSchemeType.sunset => mode == _Mode.light
          ? _sunsetLight
          : mode == _Mode.dark
              ? _sunsetDark
              : _sunsetAmoled,
      ColorSchemeType.lavender => mode == _Mode.light
          ? _lavenderLight
          : mode == _Mode.dark
              ? _lavenderDark
              : _lavenderAmoled,
      ColorSchemeType.rose => mode == _Mode.light
          ? _roseLight
          : mode == _Mode.dark
              ? _roseDark
              : _roseAmoled,
    };
  }

  // ── GitHub ─────────────────────────────────────────────────────────────
  static final _githubLight = _Palette(
    background: const Color(0xFFFFFFFF),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFFFFFFF),
    primary: const Color(0xFF238636),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFDFF5E2),
    onPrimaryContainer: const Color(0xFF052E12),
    secondary: const Color(0xFF1F6FEB),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFFD2E8FF),
    onSecondaryContainer: const Color(0xFF002D64),
    tertiary: const Color(0xFF6E40C9),
    onTertiary: const Color(0xFFFFFFFF),
    tertiaryContainer: const Color(0xFFE9DFFF),
    onTertiaryContainer: const Color(0xFF280055),
    error: const Color(0xFFCF222E),
    onError: const Color(0xFFFFFFFF),
    errorContainer: const Color(0xFFFFD8DA),
    onErrorContainer: const Color(0xFF410002),
    onSurface: const Color(0xFF1F2328),
    onSurfaceVariant: const Color(0xFF656D76),
    surfaceVariant: const Color(0xFFF6F8FA),
    outline: const Color(0xFF8B949E),
    outlineVariant: const Color(0xFFD0D7DE),
  );

  static final _githubDark = _Palette(
    background: const Color(0xFF0D1117),
    surface: const Color(0xFF161B22),
    card: const Color(0xFF161B22),
    primary: const Color(0xFF3FB950),
    onPrimary: const Color(0xFF052E12),
    primaryContainer: const Color(0xFF0A2E17),
    onPrimaryContainer: const Color(0xFFDFF5E2),
    secondary: const Color(0xFF58A6FF),
    onSecondary: const Color(0xFF002D64),
    secondaryContainer: const Color(0xFF0C2D6B),
    onSecondaryContainer: const Color(0xFFD2E8FF),
    tertiary: const Color(0xFFBC8CFF),
    onTertiary: const Color(0xFF280055),
    tertiaryContainer: const Color(0xFF3B1677),
    onTertiaryContainer: const Color(0xFFE9DFFF),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF410002),
    errorContainer: const Color(0xFF5F1A1E),
    onErrorContainer: const Color(0xFFFFD8DA),
    onSurface: const Color(0xFFE6EDF3),
    onSurfaceVariant: const Color(0xFF8B949E),
    surfaceVariant: const Color(0xFF21262D),
    outline: const Color(0xFF8B949E),
    outlineVariant: const Color(0xFF30363D),
  );

  static final _githubAmoled = _Palette(
    background: const Color(0xFF000000),
    surface: const Color(0xFF0A0A0A),
    card: const Color(0xFF0D0D0D),
    primary: const Color(0xFF3FB950),
    onPrimary: const Color(0xFF000000),
    primaryContainer: const Color(0xFF0A2E17),
    onPrimaryContainer: const Color(0xFF3FB950),
    secondary: const Color(0xFF58A6FF),
    onSecondary: const Color(0xFF000000),
    secondaryContainer: const Color(0xFF0C2D6B),
    onSecondaryContainer: const Color(0xFF58A6FF),
    tertiary: const Color(0xFFBC8CFF),
    onTertiary: const Color(0xFF000000),
    tertiaryContainer: const Color(0xFF3B1677),
    onTertiaryContainer: const Color(0xFFBC8CFF),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF000000),
    errorContainer: const Color(0xFF3D0A0C),
    onErrorContainer: const Color(0xFFFF7B72),
    onSurface: const Color(0xFFE6EDF3),
    onSurfaceVariant: const Color(0xFF8B949E),
    surfaceVariant: const Color(0xFF1A1A1A),
    outline: const Color(0xFF555555),
    outlineVariant: const Color(0xFF2A2A2A),
  );

  // ── Ocean ──────────────────────────────────────────────────────────────
  static final _oceanLight = _Palette(
    background: const Color(0xFFF8FAFC),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFFFFFFF),
    primary: const Color(0xFF0969DA),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFD1E4FF),
    onPrimaryContainer: const Color(0xFF062E6E),
    secondary: const Color(0xFF0065A9),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFFC9E6FF),
    onSecondaryContainer: const Color(0xFF001D35),
    tertiary: const Color(0xFF006B5F),
    onTertiary: const Color(0xFFFFFFFF),
    tertiaryContainer: const Color(0xFF7CF8DE),
    onTertiaryContainer: const Color(0xFF00201B),
    error: const Color(0xFFCF222E),
    onError: const Color(0xFFFFFFFF),
    errorContainer: const Color(0xFFFFD8DA),
    onErrorContainer: const Color(0xFF410002),
    onSurface: const Color(0xFF1A1C1E),
    onSurfaceVariant: const Color(0xFF43474E),
    surfaceVariant: const Color(0xFFE2E5EA),
    outline: const Color(0xFF73777F),
    outlineVariant: const Color(0xFFC3C6CF),
  );

  static final _oceanDark = _Palette(
    background: const Color(0xFF0C1929),
    surface: const Color(0xFF121E30),
    card: const Color(0xFF121E30),
    primary: const Color(0xFF47A5F5),
    onPrimary: const Color(0xFF062E6E),
    primaryContainer: const Color(0xFF08427A),
    onPrimaryContainer: const Color(0xFFD1E4FF),
    secondary: const Color(0xFF88CDFF),
    onSecondary: const Color(0xFF001D35),
    secondaryContainer: const Color(0xFF004B6E),
    onSecondaryContainer: const Color(0xFFC9E6FF),
    tertiary: const Color(0xFF5CDBC3),
    onTertiary: const Color(0xFF00201B),
    tertiaryContainer: const Color(0xFF005046),
    onTertiaryContainer: const Color(0xFF7CF8DE),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF410002),
    errorContainer: const Color(0xFF5F1A1E),
    onErrorContainer: const Color(0xFFFFD8DA),
    onSurface: const Color(0xFFDEE3EA),
    onSurfaceVariant: const Color(0xFFC3C6CF),
    surfaceVariant: const Color(0xFF2A3140),
    outline: const Color(0xFF8D919A),
    outlineVariant: const Color(0xFF43474E),
  );

  static final _oceanAmoled = _Palette(
    background: const Color(0xFF000000),
    surface: const Color(0xFF080E16),
    card: const Color(0xFF0A1119),
    primary: const Color(0xFF47A5F5),
    onPrimary: const Color(0xFF000000),
    primaryContainer: const Color(0xFF08427A),
    onPrimaryContainer: const Color(0xFF47A5F5),
    secondary: const Color(0xFF88CDFF),
    onSecondary: const Color(0xFF000000),
    secondaryContainer: const Color(0xFF004B6E),
    onSecondaryContainer: const Color(0xFF88CDFF),
    tertiary: const Color(0xFF5CDBC3),
    onTertiary: const Color(0xFF000000),
    tertiaryContainer: const Color(0xFF005046),
    onTertiaryContainer: const Color(0xFF5CDBC3),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF000000),
    errorContainer: const Color(0xFF3D0A0C),
    onErrorContainer: const Color(0xFFFF7B72),
    onSurface: const Color(0xFFDEE3EA),
    onSurfaceVariant: const Color(0xFF8D919A),
    surfaceVariant: const Color(0xFF161C26),
    outline: const Color(0xFF444C58),
    outlineVariant: const Color(0xFF222A34),
  );

  // ── Forest ─────────────────────────────────────────────────────────────
  static final _forestLight = _Palette(
    background: const Color(0xFFF6FBF4),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFFFFFFF),
    primary: const Color(0xFF1A7F37),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFC2F0CE),
    onPrimaryContainer: const Color(0xFF052E12),
    secondary: const Color(0xFF4F6354),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFFD2E8D5),
    onSecondaryContainer: const Color(0xFF0D1F12),
    tertiary: const Color(0xFF3A6470),
    onTertiary: const Color(0xFFFFFFFF),
    tertiaryContainer: const Color(0xFFBDEAF8),
    onTertiaryContainer: const Color(0xFF001F27),
    error: const Color(0xFFCF222E),
    onError: const Color(0xFFFFFFFF),
    errorContainer: const Color(0xFFFFD8DA),
    onErrorContainer: const Color(0xFF410002),
    onSurface: const Color(0xFF191D19),
    onSurfaceVariant: const Color(0xFF414941),
    surfaceVariant: const Color(0xFFDFE4D9),
    outline: const Color(0xFF707971),
    outlineVariant: const Color(0xFFC1C8BD),
  );

  static final _forestDark = _Palette(
    background: const Color(0xFF0D1F12),
    surface: const Color(0xFF131F15),
    card: const Color(0xFF131F15),
    primary: const Color(0xFF5EDB84),
    onPrimary: const Color(0xFF052E12),
    primaryContainer: const Color(0xFF0E3D1E),
    onPrimaryContainer: const Color(0xFFC2F0CE),
    secondary: const Color(0xFFB7CCB9),
    onSecondary: const Color(0xFF0D1F12),
    secondaryContainer: const Color(0xFF384B3E),
    onSecondaryContainer: const Color(0xFFD2E8D5),
    tertiary: const Color(0xFFA1CED9),
    onTertiary: const Color(0xFF001F27),
    tertiaryContainer: const Color(0xFF224B56),
    onTertiaryContainer: const Color(0xFFBDEAF8),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF410002),
    errorContainer: const Color(0xFF5F1A1E),
    onErrorContainer: const Color(0xFFFFD8DA),
    onSurface: const Color(0xFFE1E3DD),
    onSurfaceVariant: const Color(0xFFC1C8BD),
    surfaceVariant: const Color(0xFF313831),
    outline: const Color(0xFF8B938A),
    outlineVariant: const Color(0xFF414941),
  );

  static final _forestAmoled = _Palette(
    background: const Color(0xFF000000),
    surface: const Color(0xFF0A0F0B),
    card: const Color(0xFF0C120E),
    primary: const Color(0xFF5EDB84),
    onPrimary: const Color(0xFF000000),
    primaryContainer: const Color(0xFF0E3D1E),
    onPrimaryContainer: const Color(0xFF5EDB84),
    secondary: const Color(0xFFB7CCB9),
    onSecondary: const Color(0xFF000000),
    secondaryContainer: const Color(0xFF384B3E),
    onSecondaryContainer: const Color(0xFFB7CCB9),
    tertiary: const Color(0xFFA1CED9),
    onTertiary: const Color(0xFF000000),
    tertiaryContainer: const Color(0xFF224B56),
    onTertiaryContainer: const Color(0xFFA1CED9),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF000000),
    errorContainer: const Color(0xFF3D0A0C),
    onErrorContainer: const Color(0xFFFF7B72),
    onSurface: const Color(0xFFE1E3DD),
    onSurfaceVariant: const Color(0xFF8B938A),
    surfaceVariant: const Color(0xFF181E19),
    outline: const Color(0xFF454D46),
    outlineVariant: const Color(0xFF232A24),
  );

  // ── Sunset ─────────────────────────────────────────────────────────────
  static final _sunsetLight = _Palette(
    background: const Color(0xFFFFFBF8),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFFFFFFF),
    primary: const Color(0xFFBF5B04),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFFFDCC4),
    onPrimaryContainer: const Color(0xFF3C1500),
    secondary: const Color(0xFF9C4239),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFFFFDAD5),
    onSecondaryContainer: const Color(0xFF3B0908),
    tertiary: const Color(0xFF8B5711),
    onTertiary: const Color(0xFFFFFFFF),
    tertiaryContainer: const Color(0xFFFFDCA4),
    onTertiaryContainer: const Color(0xFF2C1800),
    error: const Color(0xFFCF222E),
    onError: const Color(0xFFFFFFFF),
    errorContainer: const Color(0xFFFFD8DA),
    onErrorContainer: const Color(0xFF410002),
    onSurface: const Color(0xFF201A17),
    onSurfaceVariant: const Color(0xFF53443E),
    surfaceVariant: const Color(0xFFF5DED5),
    outline: const Color(0xFF85736C),
    outlineVariant: const Color(0xFFD8C2BA),
  );

  static final _sunsetDark = _Palette(
    background: const Color(0xFF1A110C),
    surface: const Color(0xFF211812),
    card: const Color(0xFF211812),
    primary: const Color(0xFFFFB778),
    onPrimary: const Color(0xFF3C1500),
    primaryContainer: const Color(0xFF5A2A00),
    onPrimaryContainer: const Color(0xFFFFDCC4),
    secondary: const Color(0xFFFFB3AC),
    onSecondary: const Color(0xFF3B0908),
    secondaryContainer: const Color(0xFF7C2F27),
    onSecondaryContainer: const Color(0xFFFFDAD5),
    tertiary: const Color(0xFFFFB86C),
    onTertiary: const Color(0xFF2C1800),
    tertiaryContainer: const Color(0xFF633E00),
    onTertiaryContainer: const Color(0xFFFFDCA4),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF410002),
    errorContainer: const Color(0xFF5F1A1E),
    onErrorContainer: const Color(0xFFFFD8DA),
    onSurface: const Color(0xFFEDE0D9),
    onSurfaceVariant: const Color(0xFFD8C2BA),
    surfaceVariant: const Color(0xFF44372F),
    outline: const Color(0xFFA08C84),
    outlineVariant: const Color(0xFF53443E),
  );

  static final _sunsetAmoled = _Palette(
    background: const Color(0xFF000000),
    surface: const Color(0xFF110B07),
    card: const Color(0xFF140D08),
    primary: const Color(0xFFFFB778),
    onPrimary: const Color(0xFF000000),
    primaryContainer: const Color(0xFF5A2A00),
    onPrimaryContainer: const Color(0xFFFFB778),
    secondary: const Color(0xFFFFB3AC),
    onSecondary: const Color(0xFF000000),
    secondaryContainer: const Color(0xFF7C2F27),
    onSecondaryContainer: const Color(0xFFFFB3AC),
    tertiary: const Color(0xFFFFB86C),
    onTertiary: const Color(0xFF000000),
    tertiaryContainer: const Color(0xFF633E00),
    onTertiaryContainer: const Color(0xFFFFB86C),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF000000),
    errorContainer: const Color(0xFF3D0A0C),
    onErrorContainer: const Color(0xFFFF7B72),
    onSurface: const Color(0xFFEDE0D9),
    onSurfaceVariant: const Color(0xFFA08C84),
    surfaceVariant: const Color(0xFF1E1610),
    outline: const Color(0xFF5A4A42),
    outlineVariant: const Color(0xFF2C221B),
  );

  // ── Lavender ───────────────────────────────────────────────────────────
  static final _lavenderLight = _Palette(
    background: const Color(0xFFFDF8FF),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFFFFFFF),
    primary: const Color(0xFF6750A4),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFEADDFF),
    onPrimaryContainer: const Color(0xFF21005D),
    secondary: const Color(0xFF625B71),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFFE8DEF8),
    onSecondaryContainer: const Color(0xFF1D192B),
    tertiary: const Color(0xFF7D5260),
    onTertiary: const Color(0xFFFFFFFF),
    tertiaryContainer: const Color(0xFFFFD8E4),
    onTertiaryContainer: const Color(0xFF31111D),
    error: const Color(0xFFCF222E),
    onError: const Color(0xFFFFFFFF),
    errorContainer: const Color(0xFFFFD8DA),
    onErrorContainer: const Color(0xFF410002),
    onSurface: const Color(0xFF1C1B1F),
    onSurfaceVariant: const Color(0xFF49454F),
    surfaceVariant: const Color(0xFFE7E0EC),
    outline: const Color(0xFF79747E),
    outlineVariant: const Color(0xFFCAC4D0),
  );

  static final _lavenderDark = _Palette(
    background: const Color(0xFF141218),
    surface: const Color(0xFF1D1B20),
    card: const Color(0xFF1D1B20),
    primary: const Color(0xFFD0BCFF),
    onPrimary: const Color(0xFF381E72),
    primaryContainer: const Color(0xFF4F378B),
    onPrimaryContainer: const Color(0xFFEADDFF),
    secondary: const Color(0xFFCCC2DC),
    onSecondary: const Color(0xFF332D41),
    secondaryContainer: const Color(0xFF4A4458),
    onSecondaryContainer: const Color(0xFFE8DEF8),
    tertiary: const Color(0xFFEFB8C8),
    onTertiary: const Color(0xFF492532),
    tertiaryContainer: const Color(0xFF633B48),
    onTertiaryContainer: const Color(0xFFFFD8E4),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF410002),
    errorContainer: const Color(0xFF5F1A1E),
    onErrorContainer: const Color(0xFFFFD8DA),
    onSurface: const Color(0xFFE6E0E9),
    onSurfaceVariant: const Color(0xFFCAC4D0),
    surfaceVariant: const Color(0xFF2B2930),
    outline: const Color(0xFF938F99),
    outlineVariant: const Color(0xFF49454F),
  );

  static final _lavenderAmoled = _Palette(
    background: const Color(0xFF000000),
    surface: const Color(0xFF0C0B0F),
    card: const Color(0xFF0E0D12),
    primary: const Color(0xFFD0BCFF),
    onPrimary: const Color(0xFF000000),
    primaryContainer: const Color(0xFF4F378B),
    onPrimaryContainer: const Color(0xFFD0BCFF),
    secondary: const Color(0xFFCCC2DC),
    onSecondary: const Color(0xFF000000),
    secondaryContainer: const Color(0xFF4A4458),
    onSecondaryContainer: const Color(0xFFCCC2DC),
    tertiary: const Color(0xFFEFB8C8),
    onTertiary: const Color(0xFF000000),
    tertiaryContainer: const Color(0xFF633B48),
    onTertiaryContainer: const Color(0xFFEFB8C8),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF000000),
    errorContainer: const Color(0xFF3D0A0C),
    onErrorContainer: const Color(0xFFFF7B72),
    onSurface: const Color(0xFFE6E0E9),
    onSurfaceVariant: const Color(0xFF938F99),
    surfaceVariant: const Color(0xFF18161C),
    outline: const Color(0xFF4A4650),
    outlineVariant: const Color(0xFF28262C),
  );

  // ── Rose ───────────────────────────────────────────────────────────────
  static final _roseLight = _Palette(
    background: const Color(0xFFFFF8F8),
    surface: const Color(0xFFFFFFFF),
    card: const Color(0xFFFFFFFF),
    primary: const Color(0xFFE85D75),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFFFD9E0),
    onPrimaryContainer: const Color(0xFF3E001D),
    secondary: const Color(0xFFB24080),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFFFFD9E5),
    onSecondaryContainer: const Color(0xFF3E0020),
    tertiary: const Color(0xFFC15832),
    onTertiary: const Color(0xFFFFFFFF),
    tertiaryContainer: const Color(0xFFFFDBC8),
    onTertiaryContainer: const Color(0xFF4E1500),
    error: const Color(0xFFCF222E),
    onError: const Color(0xFFFFFFFF),
    errorContainer: const Color(0xFFFFD8DA),
    onErrorContainer: const Color(0xFF410002),
    onSurface: const Color(0xFF201A1B),
    onSurfaceVariant: const Color(0xFF534345),
    surfaceVariant: const Color(0xFFF8DEE2),
    outline: const Color(0xFF857376),
    outlineVariant: const Color(0xFFD8C2C6),
  );

  static final _roseDark = _Palette(
    background: const Color(0xFF1A1112),
    surface: const Color(0xFF201A1B),
    card: const Color(0xFF201A1B),
    primary: const Color(0xFFFFB1C0),
    onPrimary: const Color(0xFF650033),
    primaryContainer: const Color(0xFF8F1249),
    onPrimaryContainer: const Color(0xFFFFD9E0),
    secondary: const Color(0xFFFFB0C8),
    onSecondary: const Color(0xFF650038),
    secondaryContainer: const Color(0xFF8A165C),
    onSecondaryContainer: const Color(0xFFFFD9E5),
    tertiary: const Color(0xFFFFB59B),
    onTertiary: const Color(0xFF4E1500),
    tertiaryContainer: const Color(0xFF9E2C0D),
    onTertiaryContainer: const Color(0xFFFFDBC8),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF410002),
    errorContainer: const Color(0xFF5F1A1E),
    onErrorContainer: const Color(0xFFFFD8DA),
    onSurface: const Color(0xFFEDE0E1),
    onSurfaceVariant: const Color(0xFFD8C2C6),
    surfaceVariant: const Color(0xFF44373A),
    outline: const Color(0xFFA08C90),
    outlineVariant: const Color(0xFF534345),
  );

  static final _roseAmoled = _Palette(
    background: const Color(0xFF000000),
    surface: const Color(0xFF0E0A0B),
    card: const Color(0xFF110D0E),
    primary: const Color(0xFFFFB1C0),
    onPrimary: const Color(0xFF000000),
    primaryContainer: const Color(0xFF8F1249),
    onPrimaryContainer: const Color(0xFFFFB1C0),
    secondary: const Color(0xFFFFB0C8),
    onSecondary: const Color(0xFF000000),
    secondaryContainer: const Color(0xFF8A165C),
    onSecondaryContainer: const Color(0xFFFFB0C8),
    tertiary: const Color(0xFFFFB59B),
    onTertiary: const Color(0xFF000000),
    tertiaryContainer: const Color(0xFF9E2C0D),
    onTertiaryContainer: const Color(0xFFFFB59B),
    error: const Color(0xFFFF7B72),
    onError: const Color(0xFF000000),
    errorContainer: const Color(0xFF3D0A0C),
    onErrorContainer: const Color(0xFFFF7B72),
    onSurface: const Color(0xFFEDE0E1),
    onSurfaceVariant: const Color(0xFFA08C90),
    surfaceVariant: const Color(0xFF1C1617),
    outline: const Color(0xFF5A464A),
    outlineVariant: const Color(0xFF2C2225),
  );
}

/// Internal palette representation.
class _Palette {
  const _Palette({
    required this.background,
    required this.surface,
    required this.card,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.surfaceVariant,
    required this.outline,
    required this.outlineVariant,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color surfaceVariant;
  final Color outline;
  final Color outlineVariant;
}
