import Draw
import Parsing

struct HexByte: ParserPrinter {
    func parse(_ input: inout Substring.UTF8View) throws -> UInt8 {
        let prefix = input.prefix(2)
        guard
            prefix.count == 2,
            let byte = UInt8(String(decoding: prefix, as: UTF8.self), radix: 16)
        else { throw ParsingError() }
        input.removeFirst(2)
        return byte
    }

    func print(_ output: UInt8, into input: inout Substring.UTF8View) {
        let byte = String(output, radix: 16)
        input.prepend(contentsOf: byte.count == 1 ? "0\(byte)".utf8 : "\(byte)".utf8)
    }
}

struct SingleHexByte: ParserPrinter {
    func parse(_ input: inout Substring.UTF8View) throws -> UInt8 {
        let prefix = input.prefix(1)
        guard
            prefix.count == 1,
            let byte = UInt8(String(decoding: prefix, as: UTF8.self), radix: 16)
        else { throw ParsingError() }
        input.removeFirst(1)
        return byte
    }

    func print(_ output: UInt8, into input: inout Substring.UTF8View) {
        let byte = String(output, radix: 16)
        input.prepend(contentsOf: byte.utf8)
    }
}

let colorNames: [Substring: Color] = [
    "clear": .clear,
    "black": .black,
    "white": .white,
    "blue": .blue,
    "green": .green,
    "red": .red,
    "yellow": .yellow,
    "cyan": .cyan,
    "magenta": .magenta,
]

struct NamedColor: ParserPrinter {
    func parse(_ input: inout Substring) throws -> Color {
        guard let color = colorNames[input] else {
            throw ParsingError()
        }
        input.removeFirst(input.count)
        return color
    }

    func print(_ output: Color, into input: inout Substring) throws {
        for (key, value) in colorNames {
            guard value == output else { continue }
            input.prepend(contentsOf: key)
            return
        }
        throw ParsingError()
    }
}

public enum ColorFieldID: String, CaseIterable {
    case backgroundColor = "background-color"
    case textColor = "text-color"
}

struct ColorConversionRGBA: Conversion {
    typealias Input = (UInt8, UInt8, UInt8, UInt8)
    typealias Output = Color

    func apply(_ input: Input) throws -> Output {
        hcolor(red: input.0, green: input.1, blue: input.2, alpha: input.3)
    }

    func unapply(_ output: Color) throws -> (UInt8, UInt8, UInt8, UInt8) {
        (
            UInt8(output.red * 255.0),
            UInt8(output.green * 255.0),
            UInt8(output.blue * 255.0),
            UInt8(output.alpha * 255.0)
        )
    }
}

struct ColorConversionSingleRGBA: Conversion {
    typealias Input = (UInt8, UInt8, UInt8, UInt8)
    typealias Output = Color

    func apply(_ input: Input) throws -> Output {
        hcolor(
            red: input.0 * 16 + input.0,
            green: input.1 * 16 + input.1,
            blue: input.2 * 16 + input.2,
            alpha: input.3 * 16 + input.3
        )
    }

    func unapply(_ output: Output) throws -> Input {
        (
            UInt8(output.red * 255.0),
            UInt8(output.green * 255.0),
            UInt8(output.blue * 255.0),
            UInt8(output.alpha * 255.0)
        )
    }
}

struct ColorConversionRGB: Conversion {
    typealias Input = (UInt8, UInt8, UInt8)
    typealias Output = Color

    func apply(_ input: Input) throws -> Output {
        hcolor(red: input.0, green: input.1, blue: input.2, alpha: 0xFF)
    }

    func unapply(_ output: Color) throws -> (UInt8, UInt8, UInt8) {
        (
            UInt8(output.red * 255.0),
            UInt8(output.green * 255.0),
            UInt8(output.blue * 255.0)
        )
    }
}

struct ColorConversionSingleRGB: Conversion {
    typealias Input = (UInt8, UInt8, UInt8)
    typealias Output = Color

    func apply(_ input: Input) throws -> Output {
        hcolor(
            red: input.0 * 16 + input.0,
            green: input.1 * 16 + input.1,
            blue: input.2 * 16 + input.2,
            alpha: 0xFF
        )
    }

    func unapply(_ output: Color) throws -> Input {
        (
            UInt8(output.red * 255.0),
            UInt8(output.green * 255.0),
            UInt8(output.blue * 255.0)
        )
    }
}

let rrggbbaaHexColor = ParsePrint(ColorConversionRGBA()) {
    "#".utf8
    HexByte()
    HexByte()
    HexByte()
    HexByte()
}

let rrggbbHexColor = ParsePrint(ColorConversionRGB()) {
    "#".utf8
    HexByte()
    HexByte()
    HexByte()
}

let rgbaHexColor = ParsePrint(ColorConversionSingleRGBA()) {
    "#".utf8
    SingleHexByte()
    SingleHexByte()
    SingleHexByte()
    SingleHexByte()
}

let rgbHexColor = ParsePrint(ColorConversionSingleRGB()) {
    "#".utf8
    SingleHexByte()
    SingleHexByte()
    SingleHexByte()
}

let colorParse = Parse {
    ColorFieldID.parser()
    Whitespace(.horizontal)
    ":".utf8
    Whitespace(.horizontal)
    OneOf {
        rrggbbaaHexColor
        rrggbbHexColor
        rgbaHexColor
        rgbHexColor
        From(.substring) { NamedColor() }
    }
}

func hcolor(
    red: UInt8,
    green: UInt8,
    blue: UInt8,
    alpha: UInt8
) -> Color {
    Color(
        red: Double(red) / 255.0,
        green: Double(green) / 255.0,
        blue: Double(blue) / 255.0,
        alpha: Double(alpha) / 255.0
    )
}
