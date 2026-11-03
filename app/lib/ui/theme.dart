import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

/// Builds the RepForge [ThemeData] for the given brightness.
ThemeData rfTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: RfColors.electric,
    onPrimary: RfColors.darkInk,
    secondary: RfColors.purple,
    onSecondary: RfColors.darkInk,
    tertiary: RfColors.green,
    onTertiary: RfColors.darkInk,
    error: RfColors.danger,
    onError: Colors.white,
    surface: dark ? RfColors.darkInk : RfColors.lightInk,
    onSurface: dark ? RfColors.darkText : RfColors.lightText,
    surfaceContainer: dark ? RfColors.darkPanel : RfColors.lightPanel,
    surfaceContainerHigh: dark ? RfColors.darkPanel2 : RfColors.lightPanel2,
    outline: dark ? RfColors.darkBorder : RfColors.lightBorder,
    onSurfaceVariant: dark ? RfColors.darkMuted : RfColors.lightMuted,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
  );
  final text = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(
      letterSpacing: 1.2,
      fontWeight: FontWeight.w700,
      color: scheme.onSurfaceVariant,
    ),
  );
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.surfaceContainerHigh,
      labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RfRadius.md),
      ),
      filled: true,
      fillColor: scheme.surfaceContainer,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(rfMinTouchTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RfRadius.md),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RfRadius.lg),
        side: BorderSide(color: scheme.outline),
      ),
    ),
  );
}
