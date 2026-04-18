import Flutter
import UIKit

final class NativeDrawingEngine {
  private let channelName = "com.docly.pdf_drawing/native_renderer"
  private var channel: FlutterMethodChannel?

  private var canvasSize: CGSize = .zero
  private var renderer: UIGraphicsImageRenderer?
  private var currentImage: UIImage?

  private struct Stroke {
    let points: [CGPoint]
    let color: UIColor
    let width: CGFloat
    let opacity: CGFloat
  }

  private var strokes: [Stroke] = []
  private var redoStrokes: [Stroke] = []

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    self.channel = channel
  }

  func detach() {
    channel?.setMethodCallHandler(nil)
    channel = nil
    renderer = nil
    currentImage = nil
    strokes.removeAll()
    redoStrokes.removeAll()
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initDrawingContext":
      guard
        let args = call.arguments as? [String: Any],
        let width = args["width"] as? NSNumber,
        let height = args["height"] as? NSNumber
      else {
        result(false)
        return
      }
      result(initContext(width: width.intValue, height: height.intValue))

    case "drawStroke":
      guard
        let args = call.arguments as? [String: Any],
        let pointsFlat = args["points"] as? [NSNumber],
        let colorValue = args["color"] as? NSNumber,
        let width = args["strokeWidth"] as? NSNumber,
        let opacity = args["opacity"] as? NSNumber
      else {
        result(nil)
        return
      }
      drawStroke(pointsFlat: pointsFlat, colorValue: colorValue.intValue, width: CGFloat(width.doubleValue), opacity: CGFloat(opacity.doubleValue))
      result(nil)

    case "erase":
      guard
        let args = call.arguments as? [String: Any],
        let centerX = args["centerX"] as? NSNumber,
        let centerY = args["centerY"] as? NSNumber,
        let radius = args["radius"] as? NSNumber
      else {
        result(nil)
        return
      }
      erase(at: CGPoint(x: centerX.doubleValue, y: centerY.doubleValue), radius: CGFloat(radius.doubleValue))
      result(nil)

    case "renderToPNG":
      result(currentImage?.pngData())

    case "clearBuffer":
      clear()
      result(nil)

    case "undo":
      result(undo())

    case "redo":
      result(redo())

    case "getStrokeCount":
      result(strokes.count)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initContext(width: Int, height: Int) -> Bool {
    guard width > 0, height > 0 else { return false }

    canvasSize = CGSize(width: width, height: height)
    renderer = UIGraphicsImageRenderer(size: canvasSize)
    currentImage = renderer?.image { _ in }
    strokes.removeAll()
    redoStrokes.removeAll()
    return true
  }

  private func drawStroke(pointsFlat: [NSNumber], colorValue: Int, width: CGFloat, opacity: CGFloat) {
    guard let renderer = renderer else { return }

    var points: [CGPoint] = []
    var idx = 0
    while idx + 1 < pointsFlat.count {
      let x = CGFloat(pointsFlat[idx].doubleValue)
      let y = CGFloat(pointsFlat[idx + 1].doubleValue)
      points.append(CGPoint(x: x, y: y))
      idx += 2
    }
    guard points.count > 1 else { return }

    let stroke = Stroke(
      points: points,
      color: UIColor(argb: colorValue),
      width: width,
      opacity: max(0.0, min(1.0, opacity))
    )

    strokes.append(stroke)
    redoStrokes.removeAll()

    currentImage = renderer.image { ctx in
      currentImage?.draw(at: .zero)
      draw(stroke: stroke, in: ctx.cgContext)
    }
  }

  private func erase(at center: CGPoint, radius: CGFloat) {
    guard let renderer = renderer else { return }

    currentImage = renderer.image { ctx in
      currentImage?.draw(at: .zero)
      ctx.cgContext.setBlendMode(.clear)
      ctx.cgContext.setFillColor(UIColor.clear.cgColor)
      let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
      ctx.cgContext.fillEllipse(in: rect)
    }
  }

  private func undo() -> Bool {
    guard let last = strokes.popLast() else { return false }
    redoStrokes.append(last)
    redrawAll()
    return true
  }

  private func redo() -> Bool {
    guard let stroke = redoStrokes.popLast() else { return false }
    strokes.append(stroke)
    redrawAll()
    return true
  }

  private func clear() {
    strokes.removeAll()
    redoStrokes.removeAll()
    currentImage = renderer?.image { _ in }
  }

  private func redrawAll() {
    guard let renderer = renderer else { return }
    currentImage = renderer.image { ctx in
      for stroke in strokes {
        draw(stroke: stroke, in: ctx.cgContext)
      }
    }
  }

  private func draw(stroke: Stroke, in context: CGContext) {
    guard stroke.points.count > 1 else { return }

    context.setStrokeColor(stroke.color.withAlphaComponent(stroke.opacity).cgColor)
    context.setLineWidth(stroke.width)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    context.beginPath()
    context.move(to: stroke.points[0])
    for point in stroke.points.dropFirst() {
      context.addLine(to: point)
    }
    context.strokePath()
  }
}

private extension UIColor {
  convenience init(argb: Int) {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    self.init(red: r, green: g, blue: b, alpha: a)
  }
}
