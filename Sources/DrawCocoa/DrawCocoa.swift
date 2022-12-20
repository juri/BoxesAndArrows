import Cocoa
import CoreGraphics
import Draw
import Foundation

public struct GraphicsCocoa {
    public init() {}
}

extension GraphicsCocoa: Graphics {
    public func makeDrawing(size: Size) -> any Drawing<NSImage> {
        DrawCocoa(size: CGSize(size))
    }

    public func measure(attributedString: AttributedString) -> Size {
        let nsattr = NSAttributedString(attributedString)
        let boundingRect = nsattr.boundingRect(
            with: .init(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin
        )
        return Size(boundingRect.size)
    }
}

public struct DrawCocoa {
    let size: CGSize

    init(size: CGSize) {
        self.size = size
    }
}

extension DrawCocoa: Drawing {
    public func draw(_ commands: [DrawCommand]) -> NSImage {
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(self.size.width.rounded()),
            pixelsHigh: Int(self.size.height.rounded()),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let nsContext = NSGraphicsContext(bitmapImageRep: bitmapRep)!
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        let context_ = nsContext.cgContext

        let flippedContext = NSGraphicsContext(cgContext: context_, flipped: true)
        NSGraphicsContext.current = flippedContext
        let context = flippedContext.cgContext

        context.translateBy(x: 0, y: self.size.height)
        context.scaleBy(x: 1, y: -1)
        context.setStrokeColor(.black)

        for command in commands {
            self.apply(command, context: context)
        }

        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)
        return image
    }

    func apply(_ command: DrawCommand, context: CGContext) {
        switch command {
        case let .addLine(point):
            context.addLine(to: CGPoint(point))

        case let .addRect(rect):
            context.addRect(CGRect(rect))

        case let .draw(text: text, point: point):
            NSAttributedString(text).draw(at: CGPoint(point))

        case let .fill(rects):
            context.fill(rects.map(CGRect.init(_:)))

        case let .move(point):
            context.move(to: CGPoint(point))

        case let .setFill(color):
            NSColor(color).setFill()

        case .strokePath:
            context.strokePath()
        }
    }
}

extension CGPoint {
    init(_ point: Draw.Point) {
        self.init(x: point.x, y: point.y)
    }
}

extension CGSize {
    init(_ size: Draw.Size) {
        self.init(width: size.width, height: size.height)
    }
}

extension Draw.Size {
    init(_ size: CGSize) {
        self.init(width: size.width, height: size.height)
    }
}

extension CGRect {
    init(_ rect: Draw.Rectangle) {
        self.init(origin: .init(rect.origin), size: .init(rect.size))
    }
}

extension NSColor {
    convenience init(_ color: Color) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}
