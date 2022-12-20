import Cocoa
import Foundation

public struct Point {
    public var x: Double
    public var y: Double

    public init(
        x: Double,
        y: Double
    ) {
        self.x = x
        self.y = y
    }
}

public struct Size {
    public var width: Double
    public var height: Double

    public static let zero = Size(width: .zero, height: .zero)

    public init(
        width: Double,
        height: Double
    ) {
        self.width = width
        self.height = height
    }
}

public struct Rectangle {
    public var origin: Point
    public var size: Size

    public init(
        origin: Point,
        size: Size
    ) {
        self.origin = origin
        self.size = size
    }
}

public enum DrawCommand {
    case addLine(Point)
    case addRect(Rectangle)
    case draw(text: AttributedString, point: Point)
    case fill([Rectangle])
    case move(Point)
    case setFill(NSColor)
    case strokePath
}

public protocol Graphics<Image> {
    associatedtype Image

    func makeDrawing(size: Size) -> any Drawing<Image>
    func measure(attributedString: AttributedString) -> Size
}

public protocol Drawing<Image> {
    associatedtype Image

    func draw(_ commands: [DrawCommand]) -> Image
}
