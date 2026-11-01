import 'package:flutter/material.dart';

/// RepForge design tokens. Every colour, spacing and radius used by the app
/// comes from here; feature code never hard-codes a value.
///
/// The dark palette carries over the legacy prototype's identity. The light
/// palette is new and keeps the same accent hues.
abstract final class RfColors {
  // Brand accents (shared by both themes).
  static const electric = Color(0xFF00AEEF);
  static const purple = Color(0xFF8C71E8);
  static const green = Color(0xFF4FD1A1);
  static const danger = Color(0xFFE5484D);

  // Dark surfaces.
  static const darkInk = Color(0xFF10141C);
  static const darkPanel = Color(0xFF181E29);
  static const darkPanel2 = Color(0xFF202838);
  static const darkBorder = Color(0xFF2B3545);
  static const darkText = Color(0xFFF1F4F9);
  static const darkMuted = Color(0xFF9AA6B8);

  // Light surfaces.
  static const lightInk = Color(0xFFF5F7FA);
  static const lightPanel = Color(0xFFFFFFFF);
  static const lightPanel2 = Color(0xFFE9EDF3);
  static const lightBorder = Color(0xFFD5DBE4);
  static const lightText = Color(0xFF141A24);
  static const lightMuted = Color(0xFF5B6675);
}

/// Spacing scale in logical pixels (4-point grid).
abstract final class RfSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii.
abstract final class RfRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

/// Minimum touch target per UXD requirements (48 dp Android, 44 pt iOS).
const double rfMinTouchTarget = 48;
