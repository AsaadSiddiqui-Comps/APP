import UIKit

final class PdfRenderView: UIView {
  private let engine: PdfEngine
  private let bitmapPaint = CGBlendMode.normal

  init(engine: PdfEngine) {
    self.engine = engine
    super.init(frame: .zero)
    backgroundColor = .black
    engine.attachInvalidator { [weak self] in
      self?.setNeedsDisplay()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if bounds.width > 0, bounds.height > 0 {
      engine.onSurfaceSizeChanged(width: Int(bounds.width), height: Int(bounds.height))
    }
  }

  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    context.setFillColor(UIColor.black.cgColor)
    context.fill(bounds)

    let frame = engine.currentFrame()
    guard let baseImage = frame.baseImage else {
      drawLoading(in: context)
      return
    }

    baseImage.draw(in: bounds)
    drawHighlights(frame, in: context)
    drawStrokes(frame, in: context)
    drawTexts(frame, in: context)
    drawImages(frame, in: context)
  }

  private func drawLoading(in context: CGContext) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
      .foregroundColor: UIColor.white,
      .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
      .paragraphStyle: paragraph,
    ]
    let text = NSAttributedString(string: "Loading PDF...", attributes: attributes)
    text.draw(in: CGRect(x: 0, y: bounds.midY - 16, width: bounds.width, height: 32))
  }

  private func drawHighlights(_ frame: PdfRenderFrame, in context: CGContext) {
    for op in frame.highlights {
      context.setFillColor(UIColor(red: CGFloat((op.color >> 16) & 0xFF) / 255.0,
                                   green: CGFloat((op.color >> 8) & 0xFF) / 255.0,
                                   blue: CGFloat(op.color & 0xFF) / 255.0,
                                   alpha: op.opacity).cgColor)
      context.fill(CGRect(x: op.x, y: op.y, width: op.w, height: op.h))
    }
  }

  private func drawStrokes(_ frame: PdfRenderFrame, in context: CGContext) {
    for op in frame.strokes where op.points.count > 1 {
      let color = UIColor(
        red: CGFloat((op.color >> 16) & 0xFF) / 255.0,
        green: CGFloat((op.color >> 8) & 0xFF) / 255.0,
        blue: CGFloat(op.color & 0xFF) / 255.0,
        alpha: CGFloat((op.color >> 24) & 0xFF) / 255.0
      )
      context.setStrokeColor(color.cgColor)
      context.setLineWidth(CGFloat(op.width))
      context.setLineCap(.round)
      context.setLineJoin(.round)
      context.beginPath()
      guard let first = op.points.first else { continue }
      context.move(to: CGPoint(x: first.x, y: first.y))
      var previous = first
      for point in op.points.dropFirst() {
        let mid = CGPoint(x: (previous.x + point.x) / 2.0, y: (previous.y + point.y) / 2.0)
        context.addQuadCurve(to: mid, control: CGPoint(x: previous.x, y: previous.y))
        previous = point
      }
      context.addLine(to: CGPoint(x: previous.x, y: previous.y))
      context.strokePath()
    }
  }

  private func drawTexts(_ frame: PdfRenderFrame, in context: CGContext) {
    for op in frame.texts {
      let color = UIColor(
        red: CGFloat((op.color >> 16) & 0xFF) / 255.0,
        green: CGFloat((op.color >> 8) & 0xFF) / 255.0,
        blue: CGFloat(op.color & 0xFF) / 255.0,
        alpha: CGFloat((op.color >> 24) & 0xFF) / 255.0
      )
      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .left
      let attributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: color,
        .font: UIFont.systemFont(ofSize: CGFloat(op.fontSize), weight: .regular),
        .paragraphStyle: paragraph,
      ]
      op.text.draw(at: CGPoint(x: op.x, y: op.y), withAttributes: attributes)
    }
  }

  private func drawImages(_ frame: PdfRenderFrame, in context: CGContext) {
    for op in frame.images {
      guard let image = UIImage(contentsOfFile: op.path) else { continue }
      image.draw(in: CGRect(x: op.x, y: op.y, width: max(op.width, 1), height: max(op.height, 1)))
    }
  }
}
