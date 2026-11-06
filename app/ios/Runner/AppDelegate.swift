import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Capability detection for barcode scanning (PLT-003).
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RepForgeCameraCapability") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.tempest.repforge/camera",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "hasCamera" {
        result(AVCaptureDevice.default(for: .video) != nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
