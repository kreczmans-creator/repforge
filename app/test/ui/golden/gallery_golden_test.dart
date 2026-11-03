import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/ui/gallery/gallery_screen.dart';
import 'package:repforge/ui/theme.dart';

/// Loads the bundled brand fonts so goldens render real glyphs instead of
/// the test-only block font.
Future<void> loadBrandFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const files = {
    'Sora': ['Sora-500', 'Sora-600', 'Sora-700', 'Sora-800'],
    'Manrope': ['Manrope-400', 'Manrope-500', 'Manrope-600', 'Manrope-700'],
    'IBMPlexMono': ['IBMPlexMono-400', 'IBMPlexMono-500', 'IBMPlexMono-600'],
  };
  for (final entry in files.entries) {
    final loader = FontLoader(entry.key);
    for (final f in entry.value) {
      final data = await rootBundle.load('assets/fonts/$f.ttf');
      expect(data.lengthInBytes, greaterThan(10000), reason: '$f.ttf');
      loader.addFont(Future.value(data));
    }
    await loader.load();
  }
}

/// Golden images of the component gallery in both themes at phone size.
/// Regenerate deliberately with `flutter test --update-goldens` and review
/// the diff; CI compares against the committed files.
void main() {
  setUpAll(loadBrandFonts);

  for (final brightness in Brightness.values) {
    testWidgets('gallery renders every component (${brightness.name})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: rfTheme(brightness), home: const GalleryScreen()),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(GalleryScreen));
        for (final name in [
          'monogram-dark',
          'monogram-light',
          'wordmark-dark',
          'wordmark-light',
        ]) {
          await precacheImage(
            AssetImage('assets/brand/logo/$name.png'),
            context,
          );
        }
      });
      await tester.pump(const Duration(milliseconds: 50));
      await expectLater(
        find.byType(GalleryScreen),
        matchesGoldenFile('goldens/gallery_${brightness.name}.png'),
      );
    });
  }
}
