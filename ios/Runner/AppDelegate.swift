import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let pdfPlatformBridge = PlatformBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PdfRenderViewPlugin") {
      registrar.register(PdfPlatformViewFactory(engine: pdfPlatformBridge.engine), withId: "pdf_render_view")
    }
    pdfPlatformBridge.attach(to: engineBridge.binaryMessenger)
  }
}
