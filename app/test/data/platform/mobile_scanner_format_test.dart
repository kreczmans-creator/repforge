import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'package:repforge/data/platform/mobile_scanner_barcode_scanner.dart';
import 'package:repforge/domain/scanning/barcode.dart';

void main() {
  test('maps the four retail symbologies to the domain enum', () {
    expect(mapScannerFormat(ms.BarcodeFormat.ean13), BarcodeFormat.ean13);
    expect(mapScannerFormat(ms.BarcodeFormat.ean8), BarcodeFormat.ean8);
    expect(mapScannerFormat(ms.BarcodeFormat.upcA), BarcodeFormat.upcA);
    expect(mapScannerFormat(ms.BarcodeFormat.upcE), BarcodeFormat.upcE);
  });

  test('any other symbology maps to null', () {
    expect(mapScannerFormat(ms.BarcodeFormat.qrCode), isNull);
    expect(mapScannerFormat(ms.BarcodeFormat.code128), isNull);
    expect(mapScannerFormat(ms.BarcodeFormat.unknown), isNull);
  });
}
