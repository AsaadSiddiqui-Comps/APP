import Foundation

struct HighlightOperation {
  let id: String
  let page: Int
  let x: Double
  let y: Double
  let w: Double
  let h: Double
  let color: Int
  let opacity: Double
}

struct TextOperation {
  let id: String
  let page: Int
  let text: String
  let x: Double
  let y: Double
  let color: Int
  let fontSize: Double
}

struct ImageOperation {
  let id: String
  let page: Int
  let path: String
  let x: Double
  let y: Double
  let width: Double
  let height: Double
}

final class AnnotationHandler {
  private var highlights: [HighlightOperation] = []
  private var texts: [TextOperation] = []
  private var images: [ImageOperation] = []

  func addHighlight(_ op: HighlightOperation) {
    highlights.append(op)
  }

  func updateHighlight(id: String, op: HighlightOperation) {
    if let index = highlights.firstIndex(where: { $0.id == id }) {
      highlights[index] = op
    }
  }

  func deleteHighlight(id: String) {
    highlights.removeAll { $0.id == id }
  }

  func addText(_ op: TextOperation) {
    texts.append(op)
  }

  func updateText(id: String, op: TextOperation) {
    if let index = texts.firstIndex(where: { $0.id == id }) {
      texts[index] = op
    }
  }

  func deleteText(id: String) {
    texts.removeAll { $0.id == id }
  }

  func addImage(_ op: ImageOperation) {
    images.append(op)
  }

  func updateImage(id: String, op: ImageOperation) {
    if let index = images.firstIndex(where: { $0.id == id }) {
      images[index] = op
    }
  }

  func deleteImage(id: String) {
    images.removeAll { $0.id == id }
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
