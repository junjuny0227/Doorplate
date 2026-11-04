import AppKit

public enum StatusDot {
  case running, longRunning, docker, system

  @MainActor public func image() -> NSImage {
    let color: NSColor
    switch self {
    case .running: color = .systemGreen
    case .longRunning: color = .systemOrange
    case .docker: color = .systemBlue
    case .system: color = .secondaryLabelColor
    }
    return NSImage(size: NSSize(width: 8, height: 8), flipped: false) { bounds in
      color.set()
      let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5))
      if self == .system {
        circle.lineWidth = 1
        circle.stroke()
      } else {
        circle.fill()
      }
      return true
    }
  }
}
