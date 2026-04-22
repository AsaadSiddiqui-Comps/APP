import Flutter
import UIKit

final class PdfPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private let engine: PdfEngine

  init(engine: PdfEngine) {
    self.engine = engine
    super.init()
  }

  func createArgsCodec() -> (any FlutterMessageCodec & NSObjectProtocol) {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> any FlutterPlatformView {
    PdfPlatformView(engine: engine)
  }
}
