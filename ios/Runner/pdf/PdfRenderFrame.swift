import Foundation
import UIKit

struct PdfRenderFrame {
  let pageIndex: Int
  let pageCount: Int
  let baseImage: UIImage?
  let strokes: [StrokeOperation]
  let highlights: [HighlightOperation]
  let texts: [TextOperation]
  let images: [ImageOperation]
}
