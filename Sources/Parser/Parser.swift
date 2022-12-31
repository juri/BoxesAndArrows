import Draw
import Parsing

/*
 node-style style1 {
     background-color: #aabbcc; text-color: #00000011
 }

 // comment

 node box1 {
     label: "Hello"
     style: style1
 }
 node box2 { style: style2 }

 connect box1 box2 { head1: line; head2: filled-vee }

 constrain box1.top == box2.top
 constrain box2.left == box2.right + 100.0
  */

struct ParsingError: Error {}

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

enum NumericFieldID: String, CaseIterable {
    case lineWidth = "line-width"
}

struct ColorField: Equatable {
    let fieldID: ColorFieldID
    let value: Color
}

let colorParse = Parse {
    ColorFieldID.parser()
    Whitespace(.horizontal)
    ":".utf8
    Whitespace(.horizontal)
    hexColor
}

let numberParse = Parse(.memberwise(NumericField.init(fieldID:value:))) {
    NumericFieldID.parser()
    Whitespace(.horizontal)
    ":".utf8
    Whitespace(.horizontal)
    Double.parser()
}

let escaped = Parse {
    "\\"
    Prefix(1)
}

let notQuote = Prefix(while: { $0 != "\"" && $0 != "\\" }).filter { !$0.isEmpty }
let stringPart = OneOf {
    escaped
    notQuote
}

struct StringJoinConversion: Conversion {
    func apply(_ input: [Substring]) throws -> String { input.joined() }
    func unapply(_ output: String) throws -> [Substring] { [output[...]] }
}

let oneOrMoreStringContent = Many {
    stringPart
}.map(StringJoinConversion())

let stringContent = oneOrMoreStringContent
    .replaceError(with: "")

let quoted = Parse {
    "\""
    stringContent
    "\""
}

let stringParse = Parse(.memberwise(StringField.init(fieldID:value:))) {
    StringFieldID.parser()
    Whitespace(.horizontal)
    ":"
    Whitespace(.horizontal)
    quoted
}

struct NumericField: Equatable {
    let fieldID: NumericFieldID
    let value: Double
}

enum StringFieldID: String, CaseIterable {
    case label
}

struct StringField: Equatable {
    let fieldID: StringFieldID
    let value: String
}

enum BlockField: Equatable {
    case color(ColorField)
    case numeric(NumericField)
    case string(StringField)

    struct ColorConversion: Conversion {
        func apply(_ input: (ColorFieldID, Color)) throws -> BlockField {
            BlockField.color(ColorField(fieldID: input.0, value: input.1))
        }

        func unapply(_ output: BlockField) throws -> (ColorFieldID, Color) {
            struct InvalidBlock: Error {}
            switch output {
            case let .color(cf): return (cf.fieldID, cf.value)
            default: throw InvalidBlock()
            }
        }
    }

    struct NumericFieldConversion: Conversion {
        func apply(_ input: NumericField) throws -> BlockField {
            BlockField.numeric(input)
        }

        func unapply(_ output: BlockField) throws -> NumericField {
            struct InvalidBlock: Error {}
            switch output {
            case let .numeric(nf): return nf
            default: throw InvalidBlock()
            }
        }
    }

    struct StringFieldConversion: Conversion {
        typealias Input = StringField
        typealias Output = BlockField

        func apply(_ input: StringField) throws -> BlockField {
            BlockField.string(input)
        }

        func unapply(_ output: BlockField) throws -> StringField {
            struct InvalidBlock: Error {}
            switch output {
            case let .string(sf): return sf
            default: throw InvalidBlock()
            }
        }
    }
}

let blockFieldParser = OneOf {
    colorParse.map(BlockField.ColorConversion())
    numberParse.map(BlockField.NumericFieldConversion())
    From(.substring) { stringParse.map(BlockField.StringFieldConversion()) }
}

let terminatedBlockFieldParser = Parse {
    blockFieldParser
    OneOf {
        Parse {
            Whitespace()
            ";".utf8
            Whitespace()
        }
        Parse {
            Whitespace()
            Whitespace(.vertical)
            Whitespace()
        }
    }.replaceError(with: ())
}

let blockFieldsParser = Many {
    terminatedBlockFieldParser
}

let blockParser = Parse {
    "{".utf8
    Whitespace()
    blockFieldsParser
    Whitespace()
    "}".utf8
}

let nodeStyleParser = Parse {
    "node-style".utf8
    From(.substring) { Prefix(while: { $0 != " " }) }
    blockParser
}

let hexColor = ParsePrint(.memberwise(hcolor(red:green:blue:alpha:))) {
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
