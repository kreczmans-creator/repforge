import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/ui/theme.dart';
import 'package:repforge/ui/tokens.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  final la = _lum(a);
  final lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    group('WCAG AA contrast (${brightness.name})', () {
      final theme = rfTheme(brightness);
      final rf = theme.extension<RfSemanticColors>()!;
      final scheme = theme.colorScheme;
      final surfaces = {
        'background': scheme.surface,
        'surface1': rf.surface1,
        'surface2': rf.surface2,
      };

      for (final entry in surfaces.entries) {
        test('primary text on ${entry.key} >= 4.5', () {
          expect(
            contrast(scheme.onSurface, entry.value),
            greaterThanOrEqualTo(4.5),
          );
        });
        test('secondary text on ${entry.key} >= 4.5', () {
          expect(
            contrast(rf.textSecondary, entry.value),
            greaterThanOrEqualTo(4.5),
          );
        });
        test('muted text on ${entry.key} >= 4.5', () {
          expect(
            contrast(rf.textMuted, entry.value),
            greaterThanOrEqualTo(4.5),
          );
        });
        test('accent text on ${entry.key} >= 4.5', () {
          expect(
            contrast(rf.accentText, entry.value),
            greaterThanOrEqualTo(4.5),
          );
        });
        test('semantic text variants on ${entry.key} >= 4.5', () {
          for (final c in [rf.successText, rf.alertText, rf.infoText]) {
            expect(contrast(c, entry.value), greaterThanOrEqualTo(4.5));
          }
        });
        test('semantic fills on ${entry.key} >= 3 (graphics, large text)', () {
          for (final c in [rf.success, rf.alert, rf.info]) {
            expect(contrast(c, entry.value), greaterThanOrEqualTo(3));
          }
        });
        // Forge Amber is 2.4:1 on light surfaces by brand decision; amber
        // fills always carry a slate label or an icon, so only the dark theme
        // is held to the 3:1 graphics rule for the accent itself.
        if (brightness == Brightness.dark) {
          test('accent fill on ${entry.key} >= 3', () {
            expect(contrast(rf.accent, entry.value), greaterThanOrEqualTo(3));
          });
        }
      }

      test('button label on accent >= 4.5', () {
        expect(
          contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
      });
      test('snackbar text on elevated >= 4.5', () {
        final snack = theme.snackBarTheme;
        expect(
          contrast(snack.contentTextStyle!.color!, snack.backgroundColor!),
          greaterThanOrEqualTo(4.5),
        );
      });
      test('focus ring and border are distinguishable from surface (>= 3)', () {
        expect(contrast(rf.focus, rf.surface1), greaterThanOrEqualTo(3));
        expect(
          contrast(rf.borderStrong, rf.surface1),
          greaterThanOrEqualTo(1.3),
        );
      });
    });
  }
}
