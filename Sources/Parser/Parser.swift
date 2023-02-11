import Draw
import Parsing

public enum TopLevelDecl: Equatable {
    case boxStyle(BoxStyle)
    case box(Box)
    case arrow(Arrow)
    case constraint(Equation)
    case lineComment(LineComment)

    public struct LineComment: Equatable {
        public let comment: String
    }

    public enum EndOfLine: Equatable {
        case lineComment(LineComment)
        case none
    }

    public struct BoxStyle: Equatable {
        public let name: String
        public let fields: [BlockField]
        public let endOfLine: EndOfLine
    }

    public struct Box: Equatable {
        public let name: String
        public let fields: [BlockField]
        public let endOfLine: EndOfLine
    }

    public struct Arrow: Equatable {
        public let box1: String
        public let box2: String
        public let fields: [BlockField]
        public let endOfLine: EndOfLine
    }
}

extension TopLevelDecl.LineComment {
    init(comment: Substring) {
        self.init(comment: String(comment))
    }
}

extension TopLevelDecl.BoxStyle {
    struct Conv: Conversion {
        typealias Input = (Substring, [BlockField], TopLevelDecl.EndOfLine)
        typealias Output = TopLevelDecl.BoxStyle

        func apply(_ input: Input) throws -> Output {
            TopLevelDecl.BoxStyle(
                name: String(input.0),
                fields: input.1,
                endOfLine: input.2
            )
        }

        func unapply(_ output: Output) throws -> Input {
            (output.name[...], output.fields, output.endOfLine)
        }
    }
}

extension TopLevelDecl.Box {
    struct Conv: Conversion {
        typealias Input = (Substring, [BlockField], TopLevelDecl.EndOfLine)
        typealias Output = TopLevelDecl.Box

        func apply(_ input: Input) throws -> Output {
            TopLevelDecl.Box(
                name: String(input.0),
                fields: input.1,
                endOfLine: input.2
            )
        }

        func unapply(_ output: Output) throws -> Input {
            (output.name[...], output.fields, output.endOfLine)
        }
    }
}

extension TopLevelDecl.Arrow {
    struct Conv: Conversion {
        typealias Input = (Substring, Substring, [BlockField], TopLevelDecl.EndOfLine)
        typealias Output = TopLevelDecl.Arrow

        func apply(_ input: Input) throws -> Output {
            TopLevelDecl.Arrow(
                box1: String(input.0),
                box2: String(input.1),
                fields: input.2,
                endOfLine: input.3
            )
        }

        func unapply(_ output: Output) throws -> Input {
            (output.box1[...], output.box2[...], output.fields, output.endOfLine)
        }
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

let lineComment = ParsePrint(TopLevelDecl.LineComment.Conv()) {
    Whitespace(.horizontal)
    "//".utf8
    From(.substring) { Prefix(while: { !$0.isNewline }) }
    Whitespace(1, .vertical)
    Whitespace()
}

let emptyEndOfLine = ParsePrint {
    Whitespace(.horizontal)
    Whitespace(1, .vertical)
    Whitespace()
    "".utf8 // this can't be the only way to get the typing to work?
}

let endOfLine = OneOf {
    emptyEndOfLine.map(.case(TopLevelDecl.EndOfLine.none))
    lineComment.map(.case(TopLevelDecl.EndOfLine.lineComment))
    End().map(.case(TopLevelDecl.EndOfLine.none))
}

let boxStyleParser = ParsePrint(TopLevelDecl.BoxStyle.Conv()) {
    Whitespace(.horizontal)
    "box-style".utf8
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    blockParser
    endOfLine
}

let styledBoxParser = ParsePrint(TopLevelDecl.Box.Conv()) {
    Whitespace(.horizontal)
    "box".utf8
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    blockParser
    endOfLine
}

let plainBoxParser = ParsePrint(TopLevelDecl.Box.Conv()) {
    Whitespace(.horizontal)
    "box".utf8
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Always([BlockField]())
    endOfLine
}

let boxParser = OneOf {
    styledBoxParser
    plainBoxParser
}

let connectParser = ParsePrint(TopLevelDecl.Arrow.Conv()) {
    Whitespace(.horizontal)
    "connect".utf8
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    blockParser
    endOfLine
}

let constraintParser = ParsePrint {
    Whitespace(.horizontal)
    "constrain"
    Whitespace(.horizontal)
    Equation.parser
    From(.utf8) {
        OneOf {
            emptyEndOfLine
            End()
        }
    }
}

let topLevelParser = Many {
    OneOf {
        boxStyleParser.map(.case(TopLevelDecl.boxStyle))
        boxParser.map(.case(TopLevelDecl.box))
        connectParser.map(.case(TopLevelDecl.arrow))
        From(.substring) { constraintParser.map(.case(TopLevelDecl.constraint)) }
        lineComment.map(.case(TopLevelDecl.lineComment))
    }
}

public func parse(_ spec: String) throws -> [TopLevelDecl] {
    try topLevelParser.parse(spec)
}
