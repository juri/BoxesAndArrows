import Draw
import Parsing

/*
 box-style style1 {
     background-color: #aabbcc; text-color: #00000011
 }

 // comment

 box box1 {
     label: "Hello"
     style: style1
 }
 box box2 { style: style2 }

 connect box1 box2 { head1: line; head2: filled-vee }

 constrain box1.top == box2.top
 constrain box2.left == box2.right + 100.0
  */

struct ParsingError: Error {}

public enum NumericFieldID: String, CaseIterable {
    case lineWidth = "line-width"
}

public enum VariableFieldID: String, CaseIterable {
    case head1
    case head2
    case style
}

public enum StringFieldID: String, CaseIterable {
    case label
}

public enum BlockField: Equatable {
    case color(ColorField)
    case numeric(NumericField)
    case string(StringField)
    case variable(VariableField)

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

    public struct ColorField: Equatable {
        public let fieldID: ColorFieldID
        public let value: Color
    }

    public struct StringField: Equatable {
        public let fieldID: StringFieldID
        public let value: String
    }

    public struct VariableField: Equatable {
        public let fieldID: VariableFieldID
        public let value: String
    }

    public struct NumericField: Equatable {
        public let fieldID: NumericFieldID
        public let value: Double
    }
}

extension BlockField.VariableField {
    struct Conv: Conversion {
        typealias Input = (VariableFieldID, Substring)
        typealias Output = BlockField.VariableField

        func apply(_ input: Input) throws -> Output { Output(fieldID: input.0, value: String(input.1)) }
        func unapply(_ output: Output) throws -> Input { (output.fieldID, output.value[...]) }
    }
}

let numberParse = Parse(.memberwise(BlockField.NumericField.init(fieldID:value:))) {
    NumericFieldID.parser()
    Whitespace(.horizontal)
    ":".utf8
    Whitespace(.horizontal)
    Double.parser()
}

let stringParse = Parse(.memberwise(BlockField.StringField.init(fieldID:value:))) {
    StringFieldID.parser()
    Whitespace(.horizontal)
    ":"
    Whitespace(.horizontal)
    Strings.quoted
}

let variableParse = ParsePrint(BlockField.VariableField.Conv()) {
    VariableFieldID.parser()
    Whitespace(.horizontal)
    ":"
    Whitespace(.horizontal)
    Prefix(while: { !$0.isWhitespace && $0 != ";" })
}

let blockFieldParser = OneOf {
    colorParse.map(BlockField.ColorConversion())
    numberParse.map(BlockField.NumericFieldConversion())
    From(.substring) { stringParse.map(BlockField.StringFieldConversion()) }
    From(.substring) { variableParse.map(.case(BlockField.variable)) }
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

public enum TopLevelDecl: Equatable {
    case boxStyle(BoxStyle)
    case box(Box)
    case arrow(Arrow)
    case constraint([EquationPart])
    case lineComment(LineComment)

    public struct BoxStyle: Equatable {
        public let name: String
        public let fields: [BlockField]
    }

    public struct Box: Equatable {
        public let name: String
        public let fields: [BlockField]
    }

    public struct Arrow: Equatable {
        public let box1: String
        public let box2: String
        public let fields: [BlockField]
    }

    public struct LineComment: Equatable {
        public let comment: String
    }
}

extension TopLevelDecl.BoxStyle {
    struct Conv: Conversion {
        typealias Input = (Substring, [BlockField])
        typealias Output = TopLevelDecl.BoxStyle

        func apply(_ input: Input) throws -> Output { .init(name: String(input.0), fields: input.1) }
        func unapply(_ output: Output) throws -> Input { (output.name[...], output.fields) }
    }
}

extension TopLevelDecl.Box {
    struct Conv: Conversion {
        typealias Input = (Substring, [BlockField])
        typealias Output = TopLevelDecl.Box

        func apply(_ input: Input) throws -> Output { .init(name: String(input.0), fields: input.1) }
        func unapply(_ output: Output) throws -> Input { (output.name[...], output.fields) }
    }
}

extension TopLevelDecl.Arrow {
    struct Conv: Conversion {
        typealias Input = (Substring, Substring, [BlockField])
        typealias Output = TopLevelDecl.Arrow

        func apply(_ input: Input) throws -> Output {
            .init(box1: String(input.0), box2: String(input.1), fields: input.2)
        }

        func unapply(_ output: Output) throws -> Input { (output.box1[...], output.box2[...], output.fields) }
    }
}

extension TopLevelDecl.LineComment {
    struct Conv: Conversion {
        typealias Input = Substring
        typealias Output = TopLevelDecl.LineComment
        func apply(_ input: Input) throws -> Output { .init(comment: String(input)) }
        func unapply(_ output: Output) throws -> Input { output.comment[...] }
    }
}

let boxStyleParser = ParsePrint(TopLevelDecl.BoxStyle.Conv()) {
    "box-style".utf8
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    blockParser
    Whitespace()
}

let styledBoxParser = ParsePrint(TopLevelDecl.Box.Conv()) {
    "box".utf8
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    blockParser
    Whitespace()
}

let plainBoxParser = ParsePrint(TopLevelDecl.Box.Conv()) {
    "box".utf8
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Always([BlockField]())
    Whitespace()
}

let boxParser = OneOf {
    styledBoxParser
    plainBoxParser
}

let connectParser = ParsePrint(TopLevelDecl.Arrow.Conv()) {
    "connect".utf8
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    blockParser
    Whitespace()
}

let constraintParser = ParsePrint {
    "constrain"
    Whitespace(.horizontal)
    EquationPart.manyParser
    Whitespace()
}

let lineComment = ParsePrint {
    "//"
    Prefix(while: { !$0.isNewline })
    Whitespace(1, .vertical)
}

let topLevelLineComment = ParsePrint(TopLevelDecl.LineComment.Conv()) {
    lineComment
}

let topLevelParser = Many {
    OneOf {
        boxStyleParser.map(.case(TopLevelDecl.boxStyle))
        boxParser.map(.case(TopLevelDecl.box))
        connectParser.map(.case(TopLevelDecl.arrow))
        From(.substring) { constraintParser.map(.case(TopLevelDecl.constraint)) }
        From(.substring) { topLevelLineComment.map(.case(TopLevelDecl.lineComment)) }
    }
}

public func parse(_ spec: String) throws -> [TopLevelDecl] {
    try topLevelParser.parse(spec)
}
