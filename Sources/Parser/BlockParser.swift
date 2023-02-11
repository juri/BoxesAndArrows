import Draw
import Parsing

public enum NumericFieldID: String, CaseIterable {
    case lineWidth = "line-width"
    case horizontalPadding = "horizontal-padding"
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
    case lineComment(LineComment)

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

    struct LineCommentConversion: Conversion {
        typealias Input = LineComment
        typealias Output = BlockField

        func apply(_ input: Input) throws -> Output {
            .lineComment(input)
        }

        func unapply(_ output: Output) throws -> Input {
            struct InvalidBlock: Error {}
            guard case let .lineComment(l) = output else {
                throw InvalidBlock()
            }
            return l
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

    public struct LineComment: Equatable {
        public let text: String
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

extension BlockField.LineComment {
    struct Conv: Conversion {
        typealias Input = Substring
        typealias Output = BlockField

        func apply(_ input: Input) throws -> Output { .lineComment(BlockField.LineComment(text: String(input))) }
        func unapply(_ output: Output) throws -> Input {
            guard case let .lineComment(l) = output else {
                throw ParsingError()
            }
            return l.text[...]
        }
    }

    static let parse = ParsePrint {
        Whitespace(.horizontal)
        "//".utf8
        From(.substring) { Prefix(while: { !$0.isNewline }) }
        Whitespace(1, .vertical)
        Whitespace()
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
    BlockField.LineComment.parse.map(BlockField.LineComment.Conv())
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
