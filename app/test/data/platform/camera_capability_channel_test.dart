import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/platform/camera_capability_channel.dart';
import 'package:repforge/domain/scanning/barcode_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(CameraCapabilityChannel.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('true maps to available', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'hasCamera');
      return true;
    });
    expect(
      await const CameraCapabilityChannel().query(),
      ScannerCapability.available,
    );
  });

  test('false maps to noCamera', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => false);
    expect(
      await const CameraCapabilityChannel().query(),
      ScannerCapability.noCamera,
    );
  });

  test('missing handler maps to unsupported', () async {
    expect(
      await const CameraCapabilityChannel().query(),
      ScannerCapability.unsupported,
    );
  });

  test('PlatformException maps to unsupported', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'boom'),
    );
    expect(
      await const CameraCapabilityChannel().query(),
      ScannerCapability.unsupported,
    );
  });
}
