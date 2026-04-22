import Foundation

struct HighlightOperation {
  let page: Int
  let x: Double
  let y: Double
  let w: Double
  let h: Double
  let color: Int
  let opacity: Double
}

struct TextOperation {
  let page: Int
  let text: String
  let x: Double
  let y: Double
}

struct ImageOperation {
  let page: Int
  let path: String
  let x: Double
  let y: Double
}

final class AnnotationHandler {
  private var highlights: [HighlightOperation] = []
  private var texts: [TextOperation] = []
  private var images: [ImageOperation] = []

  func addHighlight(_ op: HighlightOperation) {
    highlights.append(op)
  }

  func addText(_ op: TextOperation) {
    texts.append(op)
  }

  func addImage(_ op: ImageOperation) {
    images.append(op)
  }

  func allHighlights() -> [HighlightOperation] {
    highlights
  }

  func allTexts() -> [TextOperation] {
    texts
  }

  func allImages() -> [ImageOperation] {
    images
  }

  func clear() {
    highlights.removeAll()
    texts.removeAll()
    images.removeAll()
  }
}
