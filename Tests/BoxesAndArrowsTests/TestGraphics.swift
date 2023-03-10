import Draw
import Foundation

struct TestGraphics {
    static let lineHeight: Double = 20.0
    static let charWidth: Double = 10.0
}

extension TestGraphics: Graphics {
    func measure(attributedText: AttributedText) -> Draw.Size {
        let string = attributedText.text
        let lines = string.split(separator: "\n")
        let maxLineLength = lines.map(\.count).max()!
        return Size(width: Double(maxLineLength) * Self.charWidth, height: Double(lines.count) * Self.lineHeight)
    }

    func makeDrawing(size: Size) -> any Drawing<[DrawCommand]> {
        TestDrawing(size: size)
    }
}

struct TestDrawing {
    let size: Size
}

extension TestDrawing: Drawing {
    func draw(_ commands: [DrawCommand]) -> [DrawCommand] {
        commands
    }
}
