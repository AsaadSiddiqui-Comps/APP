import Foundation
import UIKit

final class PdfEngine {
  private let drawingHandler = DrawingHandler()
  private let annotationHandler = AnnotationHandler()
  private let renderer = PdfRenderer()
  private lazy var editor = PdfEditor(drawingHandler: drawingHandler, annotationHandler: annotationHandler)

  private var currentPdfPath: String?
  private var currentPage: Int = 1
  private var surfaceWidth: Int = 0
  private var surfaceHeight: Int = 0
  private var currentBaseImage: UIImage?
  private var invalidator: (() -> Void)?
  private var renderFrame: PdfRenderFrame = PdfRenderFrame(
    pageIndex: 1,
    pageCount: 1,
    baseImage: nil,
    strokes: [],
    highlights: [],
    texts: [],
    images: []
  )

  func attachInvalidator(_ callback: (() -> Void)?) {
    invalidator = callback
  }

  func loadPdf(path: String) {
    renderer.load(path: path)
    currentPdfPath = path
    currentPage = 1
    editor.clearOps()
    rebuildFrame(refreshBase: true)
  }

  func onSurfaceSizeChanged(width: Int, height: Int) {
    guard width > 0, height > 0 else { return }
    guard width != surfaceWidth || height != surfaceHeight else { return }
    surfaceWidth = width
    surfaceHeight = height
    rebuildFrame(refreshBase: true)
  }

  func getPageCount() -> Int {
    renderer.pageCount()
  }

  func setCurrentPage(_ page: Int) {
    let nextPage = min(max(page, 1), getPageCount())
    guard nextPage != currentPage else { return }
    currentPage = nextPage
    rebuildFrame(refreshBase: true)
  }

  func addStroke(points: [StrokePoint], color: Int, width: Double) {
    drawingHandler.addStroke(page: currentPage, color: color, width: width, points: points)
    rebuildFrame(refreshBase: false)
  }

  func addHighlight(x: Double, y: Double, w: Double, h: Double, color: Int, opacity: Double) {
    annotationHandler.addHighlight(
      HighlightOperation(id: _nextId(), page: currentPage, x: x, y: y, w: w, h: h, color: color, opacity: opacity)
    )
    rebuildFrame(refreshBase: false)
  }

  func addText(text: String, x: Double, y: Double, color: Int = Int(0xFF000000), fontSize: Double = 16.0) {
    annotationHandler.addText(TextOperation(id: _nextId(), page: currentPage, text: text, x: x, y: y, color: color, fontSize: fontSize))
    rebuildFrame(refreshBase: false)
  }

  func addImage(path: String, x: Double, y: Double, width: Double = 100.0, height: Double = 100.0) {
    annotationHandler.addImage(ImageOperation(id: _nextId(), page: currentPage, path: path, x: x, y: y, width: width, height: height))
    rebuildFrame(refreshBase: false)
  }

  func updateText(id: String, text: String, x: Double, y: Double, color: Int, fontSize: Double) {
    annotationHandler.updateText(id: id, op: TextOperation(id: id, page: currentPage, text: text, x: x, y: y, color: color, fontSize: fontSize))
    rebuildFrame(refreshBase: false)
  }

  func updateImage(id: String, path: String, x: Double, y: Double, width: Double, height: Double) {
    annotationHandler.updateImage(id: id, op: ImageOperation(id: id, page: currentPage, path: path, x: x, y: y, width: width, height: height))
    rebuildFrame(refreshBase: false)
  }

  func deleteText(id: String) {
    annotationHandler.deleteText(id: id)
    rebuildFrame(refreshBase: false)
  }

  func deleteImage(id: String) {
    annotationHandler.deleteImage(id: id)
    rebuildFrame(refreshBase: false)
  }

  func addPage(afterPage: Int?) {
    currentPage = max(afterPage ?? (currentPage + 1), 1)
    rebuildFrame(refreshBase: true)
  }

  func savePdf() -> String {
    guard let path = currentPdfPath else { return "" }
    return editor.save(sourcePath: path)
  }

  func currentFrame() -> PdfRenderFrame {
    renderFrame
  }

  func dispose() {
    renderer.dispose()
    editor.clearOps()
    currentPdfPath = nil
    currentBaseImage = nil
  }

  private func rebuildFrame(refreshBase: Bool) {
    if refreshBase {
      currentBaseImage = surfaceWidth > 0 && surfaceHeight > 0
        ? renderer.renderPage(pageIndex: currentPage - 1, width: surfaceWidth, height: surfaceHeight)
        : nil
    }

    renderFrame = PdfRenderFrame(
      pageIndex: currentPage,
      pageCount: getPageCount(),
      baseImage: currentBaseImage,
      strokes: drawingHandler.allOperations().filter { $0.page == currentPage },
      highlights: annotationHandler.allHighlights().filter { $0.page == currentPage },
      texts: annotationHandler.allTexts().filter { $0.page == currentPage },
      images: annotationHandler.allImages().filter { $0.page == currentPage }
    )

    invalidator?()
  }

  private func _nextId() -> String {
    String(Date().timeIntervalSince1970 * 1_000_000)
  }
}
