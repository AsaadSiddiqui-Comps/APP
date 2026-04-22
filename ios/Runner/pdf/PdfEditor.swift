import Foundation

final class PdfEditor {
  private let drawingHandler: DrawingHandler
  private let annotationHandler: AnnotationHandler

  init(drawingHandler: DrawingHandler, annotationHandler: AnnotationHandler) {
    self.drawingHandler = drawingHandler
    self.annotationHandler = annotationHandler
  }

  // This is a seam for swapping in a full PDFium mutation pipeline.
  func save(sourcePath: String) -> String {
    let sourceURL = URL(fileURLWithPath: sourcePath)
    let folderURL = sourceURL.deletingLastPathComponent()
    let outputURL = folderURL.appendingPathComponent("edited_\(Int(Date().timeIntervalSince1970)).pdf")

    do {
      if FileManager.default.fileExists(atPath: outputURL.path) {
        try FileManager.default.removeItem(at: outputURL)
      }
      try FileManager.default.copyItem(at: sourceURL, to: outputURL)
      return outputURL.path
    } catch {
      return ""
    }
  }

  func clearOps() {
    drawingHandler.clear()
    annotationHandler.clear()
  }
}
