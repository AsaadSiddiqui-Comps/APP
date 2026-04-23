import Flutter
import Foundation

final class PlatformBridge {
  private var channel: FlutterMethodChannel?
  let engine = PdfEngine()

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "pdf_editor", binaryMessenger: messenger)
    self.channel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "bridge_deallocated", message: "Platform bridge deallocated", details: nil))
        return
      }
      self.handle(call: call, result: result)
    }
  }

  func dispose() {
    channel?.setMethodCallHandler(nil)
    channel = nil
    engine.dispose()
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "loadPdf":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            !path.isEmpty else {
        result(FlutterError(code: "invalid_args", message: "path is required", details: nil))
        return
      }
      engine.loadPdf(path: path)
      result(nil)

    case "drawStroke":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
        return
      }
      let pointsRaw = args["points"] as? [[String: Any]] ?? []
      let points = pointsRaw.compactMap { m -> StrokePoint? in
        guard let x = (m["x"] as? NSNumber)?.doubleValue,
              let y = (m["y"] as? NSNumber)?.doubleValue else {
          return nil
        }
        return StrokePoint(x: x, y: y)
      }
      let color = (args["color"] as? NSNumber)?.intValue ?? Int(0xFF000000)
      let width = (args["width"] as? NSNumber)?.doubleValue ?? 3.0
      engine.addStroke(points: points, color: color, width: width)
      result(nil)

    case "addHighlight":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
        return
      }
      let x = (args["x"] as? NSNumber)?.doubleValue ?? 0
      let y = (args["y"] as? NSNumber)?.doubleValue ?? 0
      let w = (args["w"] as? NSNumber)?.doubleValue ?? 0
      let h = (args["h"] as? NSNumber)?.doubleValue ?? 0
      let color = (args["color"] as? NSNumber)?.intValue ?? Int(0xFFFFFF00)
      let opacity = (args["opacity"] as? NSNumber)?.doubleValue ?? 0.35
      engine.addHighlight(x: x, y: y, w: w, h: h, color: color, opacity: opacity)
      result(nil)

    case "addText":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
        return
      }
      let text = args["text"] as? String ?? ""
      let x = (args["x"] as? NSNumber)?.doubleValue ?? 0
      let y = (args["y"] as? NSNumber)?.doubleValue ?? 0
      let color = (args["color"] as? NSNumber)?.intValue ?? Int(0xFF000000)
      let fontSize = (args["fontSize"] as? NSNumber)?.doubleValue ?? 16.0
      engine.addText(text: text, x: x, y: y, color: color, fontSize: fontSize)
      result(nil)

    case "addImage":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
        return
      }
      let path = args["path"] as? String ?? ""
      let x = (args["x"] as? NSNumber)?.doubleValue ?? 0
      let y = (args["y"] as? NSNumber)?.doubleValue ?? 0
      let width = (args["width"] as? NSNumber)?.doubleValue ?? 100.0
      let height = (args["height"] as? NSNumber)?.doubleValue ?? 100.0
      engine.addImage(path: path, x: x, y: y, width: width, height: height)
      result(nil)

    case "updateText":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
        return
      }
      let id = args["id"] as? String ?? ""
      let text = args["text"] as? String ?? ""
      let x = (args["x"] as? NSNumber)?.doubleValue ?? 0
      let y = (args["y"] as? NSNumber)?.doubleValue ?? 0
      let color = (args["color"] as? NSNumber)?.intValue ?? Int(0xFF000000)
      let fontSize = (args["fontSize"] as? NSNumber)?.doubleValue ?? 16.0
      if !id.isEmpty {
        engine.updateText(id: id, text: text, x: x, y: y, color: color, fontSize: fontSize)
      }
      result(nil)

    case "updateImage":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
        return
      }
      let id = args["id"] as? String ?? ""
      let path = args["path"] as? String ?? ""
      let x = (args["x"] as? NSNumber)?.doubleValue ?? 0
      let y = (args["y"] as? NSNumber)?.doubleValue ?? 0
      let width = (args["width"] as? NSNumber)?.doubleValue ?? 100.0
      let height = (args["height"] as? NSNumber)?.doubleValue ?? 100.0
      if !id.isEmpty {
        engine.updateImage(id: id, path: path, x: x, y: y, width: width, height: height)
      }
      result(nil)

    case "deleteText":
      let args = call.arguments as? [String: Any]
      if let id = args?["id"] as? String, !id.isEmpty {
        engine.deleteText(id: id)
      }
      result(nil)

    case "deleteImage":
      let args = call.arguments as? [String: Any]
      if let id = args?["id"] as? String, !id.isEmpty {
        engine.deleteImage(id: id)
      }
      result(nil)

    case "addPage":
      let args = call.arguments as? [String: Any]
      let page = (args?["afterPage"] as? NSNumber)?.intValue
      engine.addPage(afterPage: page)
      result(nil)

    case "savePdf":
      result(engine.savePdf())

    case "setCurrentPage":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
        return
      }
      let page = (args["page"] as? NSNumber)?.intValue ?? 1
      engine.setCurrentPage(page)
      result(nil)

    case "getPageCount":
      result(engine.getPageCount())

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
