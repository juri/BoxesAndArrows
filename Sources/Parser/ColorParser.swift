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

enum ColorFieldID: String, CaseIterable {
    case backgroundColor = "background-color"
    case textColor = "text-color"
}

let colorParse = Parse {
    ColorFieldID.parser()
    Whitespace(.horizontal)
    ":".utf8
    Whitespace(.horizontal)
    rrggbbaaHexColor
}

let rrggbbaaHexColor = ParsePrint(.memberwise(hcolor(red:green:blue:alpha:))) {
    "#".utf8
    HexByte()
    HexByte()
    HexByte()
    HexByte()
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
