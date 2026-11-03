import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

TextStyle _style(
  ({double size, double height, double spacing}) t, {
  required String family,
  required FontWeight weight,
  required Color color,
  List<FontFeature>? features,
}) => TextStyle(
  fontFamily: family,
  fontSize: t.size,
  height: t.height / t.size,
  letterSpacing: t.spacing,
  fontWeight: weight,
  color: color,
  fontFeatures: features,
);

/// Builds the RepForge [ThemeData] for the given brightness from the tokens.
ThemeData rfTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final rf = dark
      ? const RfSemanticColors.dark()
      : const RfSemanticColors.light();
  final bg = dark ? RfDark.bg : RfLight.bg;
  final text = dark ? RfDark.textPrimary : RfLight.textPrimary;
  final onAccent = dark ? RfDark.textOnAccent : RfLight.textOnAccent;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: rf.accent,
    onPrimary: onAccent,
    secondary: rf.textSecondary,
    onSecondary: bg,
    tertiary: rf.success,
    onTertiary: bg,
    error: rf.alert,
    onError: dark ? RfDark.bg : Colors.white,
    surface: bg,
    onSurface: text,
    surfaceContainerLowest: bg,
    surfaceContainerLow: rf.surface1,
    surfaceContainer: rf.surface1,
    surfaceContainerHigh: rf.surface2,
    surfaceContainerHighest: rf.surface3,
    outline: rf.border,
    outlineVariant: rf.borderStrong,
    onSurfaceVariant: rf.textMuted,
  );

  const tabular = [FontFeature.tabularFigures()];
  final rfText = RfTextStyles(
    dataXl: _style(
      RfType.dataXl,
      family: RfFonts.data,
      weight: FontWeight.w600,
      color: text,
      features: tabular,
    ),
    dataL: _style(
      RfType.dataL,
      family: RfFonts.data,
      weight: FontWeight.w600,
      color: text,
      features: tabular,
    ),
    dataM: _style(
      RfType.dataM,
      family: RfFonts.data,
      weight: FontWeight.w500,
      color: text,
      features: tabular,
    ),
    dataS: _style(
      RfType.dataS,
      family: RfFonts.data,
      weight: FontWeight.w500,
      color: text,
      features: tabular,
    ),
    meta: _style(
      RfType.meta,
      family: RfFonts.data,
      weight: FontWeight.w400,
      color: rf.textMuted,
      features: tabular,
    ),
    kicker: _style(
      RfType.label,
      family: RfFonts.ui,
      weight: FontWeight.w600,
      color: rf.textMuted,
    ),
    caption: _style(
      RfType.caption,
      family: RfFonts.ui,
      weight: FontWeight.w500,
      color: rf.textMuted,
    ),
  );

  final textTheme = TextTheme(
    displaySmall: _style(
      RfType.display,
      family: RfFonts.brand,
      weight: FontWeight.w700,
      color: text,
    ),
    headlineLarge: _style(
      RfType.h1,
      family: RfFonts.brand,
      weight: FontWeight.w700,
      color: text,
    ),
    headlineMedium: _style(
      RfType.h2,
      family: RfFonts.brand,
      weight: FontWeight.w600,
      color: text,
    ),
    headlineSmall: _style(
      RfType.h3,
      family: RfFonts.brand,
      weight: FontWeight.w600,
      color: text,
    ),
    titleMedium: _style(
      RfType.h4,
      family: RfFonts.brand,
      weight: FontWeight.w600,
      color: text,
    ),
    bodyLarge: _style(
      RfType.bodyLarge,
      family: RfFonts.ui,
      weight: FontWeight.w500,
      color: text,
    ),
    bodyMedium: _style(
      RfType.body,
      family: RfFonts.ui,
      weight: FontWeight.w500,
      color: text,
    ),
    bodySmall: _style(
      RfType.bodySmall,
      family: RfFonts.ui,
      weight: FontWeight.w500,
      color: rf.textMuted,
    ),
    labelLarge: _style(
      RfType.body,
      family: RfFonts.ui,
      weight: FontWeight.w700,
      color: text,
    ),
    labelMedium: _style(
      RfType.bodySmall,
      family: RfFonts.ui,
      weight: FontWeight.w600,
      color: rf.textSecondary,
    ),
    labelSmall: rfText.kicker,
  );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
    fontFamily: RfFonts.ui,
    textTheme: textTheme,
    scaffoldBackgroundColor: bg,
    visualDensity: VisualDensity.standard,
    extensions: [rf, rfText],
  );

  final primaryShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(RfRadius.md),
  );
  final secondaryShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(RfRadius.sm),
  );
  const minSize = Size(rfMinTouchTarget, rfMinTouchTarget);
  final buttonText = textTheme.labelLarge;

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.headlineSmall,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: rf.surface1,
      indicatorColor: Colors.transparent,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => rfText.kicker.copyWith(
          letterSpacing: 0,
          color: states.contains(WidgetState.selected)
              ? rf.accentText
              : rf.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: RfIcon.md,
          color: states.contains(WidgetState.selected)
              ? rf.accent
              : rf.textMuted,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: rf.surface1,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RfRadius.sm),
        borderSide: BorderSide(color: rf.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RfRadius.sm),
        borderSide: BorderSide(color: rf.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RfRadius.sm),
        borderSide: BorderSide(color: rf.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RfRadius.sm),
        borderSide: BorderSide(color: rf.alert),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RfRadius.sm),
        borderSide: BorderSide(color: rf.alert, width: 2),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(color: rf.textMuted),
      hintStyle: textTheme.bodyMedium?.copyWith(color: rf.textMuted),
      helperStyle: rfText.caption,
      errorStyle: rfText.caption.copyWith(color: rf.alertText),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: RfSpace.s4,
        vertical: RfSpace.s3,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(minSize),
        shape: WidgetStatePropertyAll(primaryShape),
        textStyle: WidgetStatePropertyAll(buttonText),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return rf.surface3;
          if (states.contains(WidgetState.pressed)) return RfBrand.amberPressed;
          if (states.contains(WidgetState.hovered)) return RfBrand.amberHover;
          return rf.accent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? rf.textMuted : onAccent,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minSize,
        shape: secondaryShape,
        side: BorderSide(color: rf.borderStrong),
        foregroundColor: text,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minSize,
        shape: secondaryShape,
        foregroundColor: rf.accentText,
        textStyle: buttonText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: minSize,
        foregroundColor: rf.textSecondary,
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: RfSpace.s2,
      iconColor: rf.textMuted,
      textColor: text,
    ),
    dividerTheme: DividerThemeData(color: rf.border, space: 1, thickness: 1),
    // Snackbars are inverted on light (slate on cream) so they read as
    // transient; on dark they sit on the elevated surface.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: primaryShape,
      backgroundColor: dark ? rf.elevated : RfBrand.slate,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: RfDark.textPrimary,
      ),
      actionTextColor: RfBrand.amber,
    ),
    cardTheme: CardThemeData(
      color: rf.surface1,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RfRadius.lg),
        side: BorderSide(color: rf.border),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: rf.accent,
      linearTrackColor: rf.track,
      circularTrackColor: rf.track,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: rf.surface3,
      labelStyle: textTheme.labelMedium,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RfRadius.xs),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: RfSpace.s3,
        vertical: RfSpace.s1,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: rf.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(RfRadius.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: rf.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RfRadius.xl),
      ),
    ),
    focusColor: rf.focus,
  );
}
