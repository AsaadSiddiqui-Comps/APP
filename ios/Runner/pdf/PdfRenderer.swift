import Foundation
import PDFKit
import UIKit

final class PdfRenderer {
  private var document: PDFDocument?

  func load(path: String) {
    document = PDFDocument(url: URL(fileURLWithPath: path))
  }

  func pageCount() -> Int {
    max(document?.pageCount ?? 0, 1)
  }

  func renderPage(pageIndex: Int, width: Int, height: Int) -> UIImage? {
    guard let document, pageIndex >= 0, pageIndex < document.pageCount else {
      return nil
    }

    guard let page = document.page(at: pageIndex) else {
      return nil
    }

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
    return renderer.image { context in
      UIColor.black.setFill()
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
      page.draw(with: .mediaBox, to: context.cgContext)
    }
  }

  func dispose() {
    document = nil
  }
}
