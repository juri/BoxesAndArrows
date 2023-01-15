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

public struct Color: Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

extension Color {
    public static let clear = Color(red: 0, green: 0, blue: 0, alpha: 0)
    public static let black = Color(red: 0 as Double, green: 0, blue: 0, alpha: 1)
    public static let white = Color(red: 1 as Double, green: 1, blue: 1, alpha: 1)
    public static let blue = Color(red: 0 as Double, green: 0, blue: 1, alpha: 1)
    public static let green = Color(red: 0 as Double, green: 1, blue: 0, alpha: 1)
    public static let red = Color(red: 1 as Double, green: 0, blue: 0, alpha: 1)
    public static let yellow = Color(red: 1 as Double, green: 1, blue: 0, alpha: 1)
    public static let cyan = Color(red: 0 as Double, green: 1, blue: 1, alpha: 1)
    public static let magenta = Color(red: 1 as Double, green: 0, blue: 1, alpha: 1)

    public init(red: Int, green: Int, blue: Int, alpha: Int) {
        self.init(
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0,
            alpha: Double(alpha) / 255.0
        )
    }

    public init(hex: Int) {
        let red = hex >> 24 & 0xFF
        let green = hex >> 16 & 0xFF
        let blue = hex >> 8 & 0xFF
        let alpha = hex & 0xFF
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

public enum DrawCommand {
    case addLine(Point)
    case addRect(Rectangle)
    case draw(text: AttributedString, point: Point)
    case fill([Rectangle])
    case drawPath(DrawMethod)
    case move(Point)
    case setFill(Color)
}

public enum DrawMethod {
    case stroke(StrokeStyle)
    case fill(FillStyle)
    case fillStroke(FillStrokeStyle)
}

public struct StrokeStyle {
    public var color: Color
    public var lineWidth: Double

    public init(
        color: Color,
        lineWidth: Double = 1.0
    ) {
        self.color = color
        self.lineWidth = lineWidth
    }
}

public struct FillStyle {
    public var color: Color

    public init(
        color: Color
    ) {
        self.color = color
    }
}

public struct FillStrokeStyle {
    public var fill: FillStyle
    public var stroke: StrokeStyle

    public init(
        fill: FillStyle,
        stroke: StrokeStyle
    ) {
        self.fill = fill
        self.stroke = stroke
    }
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
