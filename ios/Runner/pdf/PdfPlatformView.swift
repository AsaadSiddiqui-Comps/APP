import Flutter
import UIKit

final class PdfPlatformView: NSObject, FlutterPlatformView {
  private let view: PdfRenderView
  private let engine: PdfEngine

  init(engine: PdfEngine) {
    self.engine = engine
    self.view = PdfRenderView(engine: engine)
    super.init()
  }

  func view() -> UIView {
    view
  }
}
