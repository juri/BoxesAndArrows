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

extension Point {
    public init(
        x: Int,
        y: Int
    ) {
        self.x = Double(x)
        self.y = Double(y)
    }
}

public struct Size {
    public var width: Double
    public var height: Double

    public static let zero = Size(width: Double.zero, height: Double.zero)

    public init(
        width: Double,
        height: Double
    ) {
        self.width = width
        self.height = height
    }
}

extension Size {
    public init(
        width: Int,
        height: Int
    ) {
        self.width = Double(width)
        self.height = Double(height)
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

extension Rectangle {
    @inlinable public var minX: Double { self.origin.x }
    @inlinable public var minY: Double { self.origin.y }
    @inlinable public var maxX: Double { self.minX + self.width }
    @inlinable public var maxY: Double { self.minY + self.height }
    @inlinable public var width: Double { self.size.width }
    @inlinable public var height: Double { self.size.height }

    public func insetBy(_ amount: Double) -> Rectangle {
        Rectangle(
            origin: Point(x: self.minX + amount, y: self.minY + amount),
            size: Size(width: self.width - amount * 2.0, height: self.height - amount * 2.0)
        )
    }

    public func intersects(_ other: Rectangle) -> Bool {
        self.maxX >= other.minX && self.minX <= other.maxX && self.maxY >= other.minY && self.minY <= other.maxY
    }

    public func contains(_ other: Rectangle) -> Bool {
        self.maxX >= other.maxX && self.minX <= other.minX && self.minY <= other.minY && self.maxY >= other.maxY
    }
}

public struct Color {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
}

extension Color {
    public static let black = Color(red: 0, green: 0, blue: 0, alpha: 1)
    public static let white = Color(red: 1, green: 1, blue: 1, alpha: 1)
    public static let blue = Color(red: 0, green: 0, blue: 1, alpha: 1)
    public static let green = Color(red: 0, green: 1, blue: 0, alpha: 1)
    public static let red = Color(red: 1, green: 0, blue: 0, alpha: 1)
    public static let yellow = Color(red: 1, green: 1, blue: 0, alpha: 1)
    public static let cyan = Color(red: 0, green: 1, blue: 1, alpha: 1)
    public static let magenta = Color(red: 1, green: 0, blue: 1, alpha: 1)
}

public enum DrawCommand {
    case addLine(Point)
    case addRect(Rectangle)
    case draw(text: AttributedString, point: Point)
    case fill([Rectangle])
    case fillPath
    case move(Point)
    case setFill(Color)
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
