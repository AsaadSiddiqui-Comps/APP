import Foundation

struct StrokePoint {
  let x: Double
  let y: Double
}

struct StrokeOperation {
  let page: Int
  let color: Int
  let width: Double
  let points: [StrokePoint]
}

final class DrawingHandler {
  private var operations: [StrokeOperation] = []

  func addStroke(page: Int, color: Int, width: Double, points: [StrokePoint]) {
    guard points.count > 1 else { return }
    operations.append(StrokeOperation(page: page, color: color, width: width, points: points))
  }

  func allOperations() -> [StrokeOperation] {
    operations
  }

  func clear() {
    operations.removeAll()
  }
}
