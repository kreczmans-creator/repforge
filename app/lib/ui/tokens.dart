import 'package:flutter/material.dart';

/// RepForge design tokens, implementing "RepForge Design System v1.0" (brand
/// reconstruction approved by the owner): Forge Slate / Forge Amber palette,
/// Sora · Manrope · IBM Plex Mono typography, 4-pt spacing, radius and motion
/// scales. Feature code never hard-codes a value; it reads these tokens or the
/// [ThemeData] built from them in `theme.dart`.
///
/// Contrast decisions from the brand document are applied as given: slate
/// labels on amber buttons (6.1:1), "Amber Ink" #B45F00 for amber text on
/// light surfaces, muted text #8E9DAE (dark) and #5E6E7F (light).
/// `test/ui/contrast_test.dart` enforces AA for every text/surface pair.
abstract final class RfBrand {
  // Brand primitives (theme independent).
  static const slate = Color(0xFF1F2A3A);
  static const amber = Color(0xFFFF8A00);
  static const amberHover = Color(0xFFFFA033);
  static const amberPressed = Color(0xFFE67C00);
  // Brand document gives #B45F00 (4.6:1 on white); darkened one step so it
  // also passes 4.5:1 on Surface 2 (#F5F1EB).
  static const amberInk = Color(0xFFA85800);
  static const steel = Color(0xFF3B4A5A);
  static const stone = Color(0xFF6B7B8C);
  static const mist = Color(0xFFBBC4CF);
  static const sand = Color(0xFFF2E8DC);

  // Semantic primitives (icons, fills, large text).
  static const success = Color(0xFF22C55E);
  static const info = Color(0xFF3B82F6);
  static const alert = Color(0xFFEF4444);
  static const focus = Color(0xFF8B5CF6);

  // Small semantic text on light surfaces needs darker inks (Stage 2 note in
  // the brand document); these pass 4.5:1 on white.
  static const successInk = Color(0xFF14763A);
  static const alertInk = Color(0xFFC62828);
  static const infoInk = Color(0xFF1D4ED8);

  // Small semantic text on dark surfaces: lighter tints that pass 4.5:1 on
  // Surface 1 and 2 (the brand fills are AA large-text only there).
  static const successTint = Color(0xFF4ADE80);
  static const infoTint = Color(0xFF60A5FA);
  static const alertTint = Color(0xFFF87171);
}

/// Dark theme (primary) surface and text values.
abstract final class RfDark {
  static const bg = Color(0xFF111923);
  static const surface1 = Color(0xFF182331);
  static const surface2 = Color(0xFF1F2A3A);
  static const surface3 = Color(0xFF263648);
  static const elevated = Color(0xFF304357);
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFFBBC4CF);
  static const textMuted = Color(0xFF8E9DAE);
  static const Color textOnAccent = RfBrand.slate;
  static const Color accentText = RfBrand.amber;
  static const border = Color(0xFF354557);
  static const borderStrong = Color(0xFF46586D);
  static const Color track = surface3;
}

/// Light theme surface and text values.
abstract final class RfLight {
  static const bg = Color(0xFFFBF9F6);
  static const surface1 = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF5F1EB);
  static const surface3 = Color(0xFFECE6DE);
  static const elevated = Color(0xFFFFFFFF);
  static const Color textPrimary = RfBrand.slate;
  static const Color textSecondary = RfBrand.steel;
  static const textMuted = Color(0xFF5E6E7F);
  static const Color textOnAccent = RfBrand.slate;
  static const Color accentText = RfBrand.amberInk;
  static const border = Color(0xFFE4DED6);
  static const borderStrong = Color(0xFFCFC7BD);
  static const Color track = surface3;
}

/// Font family names as registered in `pubspec.yaml`.
abstract final class RfFonts {
  /// Brand and headings (weights 500–800).
  static const brand = 'Sora';

  /// Interface and body (weights 400–700).
  static const ui = 'Manrope';

  /// Technical and numerical data (weights 400–600).
  static const data = 'IBMPlexMono';
}

/// Spacing scale, 4-pt base.
abstract final class RfSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;

  // Aliases used throughout the app.
  static const double xs = s1;
  static const double sm = s2;
  static const double md = s3;
  static const double lg = s4;
  static const double xl = s6;
  static const double xxl = s8;

  /// Horizontal page gutter (brand mock-up uses 20).
  static const double gutter = s5;
}

/// Corner radii.
abstract final class RfRadius {
  /// Chips, checkboxes, small controls.
  static const double xs = 6;

  /// Inputs, secondary buttons.
  static const double sm = 10;

  /// Primary buttons, list rows.
  static const double md = 14;

  /// Cards.
  static const double lg = 18;

  /// Bottom sheets, dialogs.
  static const double xl = 24;
  static const double pill = 999;
}

/// Motion durations and the standard curve.
abstract final class RfMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve standard = Cubic(0.2, 0, 0, 1);
}

/// Icon sizes (brand icon library exports: 20 / 24 / 32).
abstract final class RfIcon {
  static const double sm = 20;
  static const double md = 24;
  static const double lg = 32;
}

/// Minimum touch target (48 dp Android, 44 pt iOS; 48 used on both).
const double rfMinTouchTarget = 48;

/// Type scale from the brand document (size / line height). All sizes are in
/// logical pixels before user text scaling, which is always respected.
abstract final class RfType {
  static const ({double size, double height, double spacing}) display = (
    size: 40.0,
    height: 44.0,
    spacing: -0.8,
  );
  static const ({double size, double height, double spacing}) h1 = (
    size: 28.0,
    height: 34.0,
    spacing: -0.42,
  );
  static const ({double size, double height, double spacing}) h2 = (
    size: 22.0,
    height: 28.0,
    spacing: -0.22,
  );
  static const ({double size, double height, double spacing}) h3 = (
    size: 18.0,
    height: 24.0,
    spacing: 0.0,
  );
  static const ({double size, double height, double spacing}) h4 = (
    size: 16.0,
    height: 22.0,
    spacing: 0.0,
  );
  static const ({double size, double height, double spacing}) bodyLarge = (
    size: 17.0,
    height: 26.0,
    spacing: 0.0,
  );
  static const ({double size, double height, double spacing}) body = (
    size: 15.0,
    height: 22.0,
    spacing: 0.0,
  );
  static const ({double size, double height, double spacing}) bodySmall = (
    size: 13.0,
    height: 18.0,
    spacing: 0.0,
  );
  static const ({double size, double height, double spacing}) label = (
    size: 11.0,
    height: 14.0,
    spacing: 0.88,
  );
  static const ({double size, double height, double spacing}) caption = (
    size: 12.0,
    height: 16.0,
    spacing: 0.0,
  );
  static const ({double size, double height, double spacing}) dataXl = (
    size: 36.0,
    height: 40.0,
    spacing: 0.0,
  );
  static const ({double size, double height, double spacing}) dataL = (
    size: 28.0,
    height: 32.0,
    spacing: 0.0,
  );
  static const ({double size, double height, double spacing}) dataM = (
    size: 17.0,
    height: 22.0,
    spacing: 0.0,
  );
  static const ({double size, double height, double spacing}) dataS = (
    size: 13.0,
    height: 18.0,
    spacing: 0.0,
  );
  static const ({double size, double height, double spacing}) meta = (
    size: 11.0,
    height: 16.0,
    spacing: 0.44,
  );
}

/// Colours beyond [ColorScheme], registered as a [ThemeExtension] so there is
/// exactly one source for them. Read with `context.rf`.
@immutable
final class RfSemanticColors extends ThemeExtension<RfSemanticColors> {
  const RfSemanticColors({
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.elevated,
    required this.border,
    required this.borderStrong,
    required this.track,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentText,
    required this.accentSubtle,
    required this.success,
    required this.info,
    required this.alert,
    required this.focus,
    required this.successText,
    required this.infoText,
    required this.alertText,
    required this.chartSeries,
  });

  const RfSemanticColors.dark()
    : this(
        surface1: RfDark.surface1,
        surface2: RfDark.surface2,
        surface3: RfDark.surface3,
        elevated: RfDark.elevated,
        border: RfDark.border,
        borderStrong: RfDark.borderStrong,
        track: RfDark.track,
        textSecondary: RfDark.textSecondary,
        textMuted: RfDark.textMuted,
        accent: RfBrand.amber,
        accentText: RfDark.accentText,
        accentSubtle: const Color(0x24FF8A00),
        success: RfBrand.success,
        info: RfBrand.info,
        alert: RfBrand.alert,
        focus: RfBrand.focus,
        successText: RfBrand.successTint,
        infoText: RfBrand.infoTint,
        alertText: RfBrand.alertTint,
        chartSeries: const [
          RfBrand.amber,
          RfBrand.mist,
          RfBrand.info,
          RfBrand.success,
        ],
      );

  const RfSemanticColors.light()
    : this(
        surface1: RfLight.surface1,
        surface2: RfLight.surface2,
        surface3: RfLight.surface3,
        elevated: RfLight.elevated,
        border: RfLight.border,
        borderStrong: RfLight.borderStrong,
        track: RfLight.track,
        textSecondary: RfLight.textSecondary,
        textMuted: RfLight.textMuted,
        accent: RfBrand.amber,
        accentText: RfLight.accentText,
        accentSubtle: const Color(0x1FFF8A00),
        success: RfBrand.successInk,
        info: RfBrand.infoInk,
        alert: RfBrand.alertInk,
        focus: RfBrand.focus,
        successText: RfBrand.successInk,
        infoText: RfBrand.infoInk,
        alertText: RfBrand.alertInk,
        chartSeries: const [
          RfBrand.amberInk,
          RfBrand.steel,
          RfBrand.infoInk,
          RfBrand.successInk,
        ],
      );

  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color elevated;
  final Color border;
  final Color borderStrong;
  final Color track;
  final Color textSecondary;
  final Color textMuted;

  /// Amber fill (buttons, progress, active tab, icon tiles).
  final Color accent;

  /// Amber as text or link; "Amber Ink" on light surfaces.
  final Color accentText;

  /// 12–14 % amber tint for icon tiles and selected states.
  final Color accentSubtle;
  final Color success;
  final Color info;

  /// Fills and icons (brand primitives; AA for large text and graphics).
  final Color alert;
  final Color focus;

  /// Small-text-safe variants of the semantic colours (>= 4.5:1).
  final Color successText;
  final Color infoText;
  final Color alertText;

  /// Ordered colours for multi-series charts.
  final List<Color> chartSeries;

  @override
  RfSemanticColors copyWith({
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? elevated,
    Color? border,
    Color? borderStrong,
    Color? track,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentText,
    Color? accentSubtle,
    Color? success,
    Color? info,
    Color? alert,
    Color? focus,
    Color? successText,
    Color? infoText,
    Color? alertText,
    List<Color>? chartSeries,
  }) => RfSemanticColors(
    surface1: surface1 ?? this.surface1,
    surface2: surface2 ?? this.surface2,
    surface3: surface3 ?? this.surface3,
    elevated: elevated ?? this.elevated,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    track: track ?? this.track,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    accent: accent ?? this.accent,
    accentText: accentText ?? this.accentText,
    accentSubtle: accentSubtle ?? this.accentSubtle,
    success: success ?? this.success,
    info: info ?? this.info,
    alert: alert ?? this.alert,
    focus: focus ?? this.focus,
    successText: successText ?? this.successText,
    infoText: infoText ?? this.infoText,
    alertText: alertText ?? this.alertText,
    chartSeries: chartSeries ?? this.chartSeries,
  );

  @override
  RfSemanticColors lerp(RfSemanticColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return RfSemanticColors(
      surface1: l(surface1, other.surface1),
      surface2: l(surface2, other.surface2),
      surface3: l(surface3, other.surface3),
      elevated: l(elevated, other.elevated),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      track: l(track, other.track),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      accent: l(accent, other.accent),
      accentText: l(accentText, other.accentText),
      accentSubtle: l(accentSubtle, other.accentSubtle),
      success: l(success, other.success),
      info: l(info, other.info),
      alert: l(alert, other.alert),
      focus: l(focus, other.focus),
      successText: l(successText, other.successText),
      infoText: l(infoText, other.infoText),
      alertText: l(alertText, other.alertText),
      chartSeries: t < 0.5 ? chartSeries : other.chartSeries,
    );
  }
}

/// Convenience accessors: `context.rf.accent`, `context.rfText.dataL`.
extension RfThemeContext on BuildContext {
  RfSemanticColors get rf => Theme.of(this).extension<RfSemanticColors>()!;
  RfTextStyles get rfText => Theme.of(this).extension<RfTextStyles>()!;
}

/// Brand text styles that have no [TextTheme] slot (data and meta styles in
/// IBM Plex Mono, kicker labels). Registered as a [ThemeExtension].
@immutable
final class RfTextStyles extends ThemeExtension<RfTextStyles> {
  const RfTextStyles({
    required this.dataXl,
    required this.dataL,
    required this.dataM,
    required this.dataS,
    required this.meta,
    required this.kicker,
    required this.caption,
  });

  final TextStyle dataXl;
  final TextStyle dataL;
  final TextStyle dataM;
  final TextStyle dataS;
  final TextStyle meta;

  /// Uppercase label above a heading or card, +8 % tracking.
  final TextStyle kicker;
  final TextStyle caption;

  @override
  RfTextStyles copyWith({
    TextStyle? dataXl,
    TextStyle? dataL,
    TextStyle? dataM,
    TextStyle? dataS,
    TextStyle? meta,
    TextStyle? kicker,
    TextStyle? caption,
  }) => RfTextStyles(
    dataXl: dataXl ?? this.dataXl,
    dataL: dataL ?? this.dataL,
    dataM: dataM ?? this.dataM,
    dataS: dataS ?? this.dataS,
    meta: meta ?? this.meta,
    kicker: kicker ?? this.kicker,
    caption: caption ?? this.caption,
  );

  @override
  RfTextStyles lerp(RfTextStyles? other, double t) {
    if (other == null) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return RfTextStyles(
      dataXl: l(dataXl, other.dataXl),
      dataL: l(dataL, other.dataL),
      dataM: l(dataM, other.dataM),
      dataS: l(dataS, other.dataS),
      meta: l(meta, other.meta),
      kicker: l(kicker, other.kicker),
      caption: l(caption, other.caption),
    );
  }
}
