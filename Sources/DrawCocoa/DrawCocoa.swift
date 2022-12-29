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
            let transformed = text.transformingAttributes(\.textColor) { transformer in
                guard let value = transformer.value else { return }
                transformer.replace(
                    with: \.foregroundColor,
                    value: NSColor(red: value.red, green: value.green, blue: value.blue, alpha: value.alpha)
                )
            }
            context.saveGState()
            NSAttributedString(transformed).draw(at: CGPoint(point))
            context.restoreGState()

        case let .fill(rects):
            context.fill(rects.map(CGRect.init(_:)))

        case let .drawPath(.fill(style)):
            context.setFillColor(style.color.cgColor)
            context.drawPath(using: .fill)

        case let .drawPath(.stroke(style)):
            context.setStrokeColor(style.color.cgColor)
            context.drawPath(using: .stroke)

        case let .drawPath(.fillStroke(style)):
            context.setFillColor(style.fill.color.cgColor)
            context.setStrokeColor(style.stroke.color.cgColor)
            context.drawPath(using: .fillStroke)

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

extension Color {
    var cgColor: CGColor {
        CGColor(red: self.red, green: self.green, blue: self.blue, alpha: self.alpha)
    }
}
