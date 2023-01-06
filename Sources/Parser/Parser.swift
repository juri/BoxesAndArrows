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

enum NumericFieldID: String, CaseIterable {
    case lineWidth = "line-width"
}

enum VariableFieldID: String, CaseIterable {
    case head1
    case head2
    case style
}

struct ColorField: Equatable {
    let fieldID: ColorFieldID
    let value: Color
}

struct VariableField: Equatable {
    let fieldID: VariableFieldID
    let value: String
}

let numberParse = Parse(.memberwise(NumericField.init(fieldID:value:))) {
    NumericFieldID.parser()
    Whitespace(.horizontal)
    ":".utf8
    Whitespace(.horizontal)
    Double.parser()
}

extension VariableField {
    struct Conv: Conversion {
        typealias Input = (VariableFieldID, Substring)
        typealias Output = VariableField

        func apply(_ input: (VariableFieldID, Substring)) throws -> VariableField {
            VariableField(fieldID: input.0, value: String(input.1))
        }

        func unapply(_ output: VariableField) throws -> (VariableFieldID, Substring) {
            (output.fieldID, output.value[...])
        }
    }
}

let variableParse = ParsePrint(VariableField.Conv()) {
    VariableFieldID.parser()
    Whitespace(.horizontal)
    ":"
    Whitespace(.horizontal)
    Prefix(while: { !$0.isWhitespace && $0 != ";" })
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

let nodeStyleParser = ParsePrint(TopLevelDecl.NodeStyle.Conv()) {
    "node-style".utf8
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    blockParser
    Whitespace()
}

let nodeParser = ParsePrint(TopLevelDecl.Node.Conv()) {
    "node".utf8
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    blockParser
    Whitespace()
}

let connectParser = ParsePrint(TopLevelDecl.Connection.Conv()) {
    "connect".utf8
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    From(.substring) { Prefix(while: { !$0.isWhitespace }) }
    Whitespace(.horizontal)
    blockParser
    Whitespace()
}

enum EquationPart: Equatable {
    case variable(Variable)
    case operation(Operation)
    case relation(Relation)
    case constant(Double)

    struct Variable: Equatable {
        let head: String
        let tail: [String]
    }

    enum Operation: String, Equatable, CaseIterable {
        case add = "+"
        case sub = "-"
        case mult = "*"
        case div = "/"
    }

    enum Relation: String, Equatable, CaseIterable {
        case lt = "<"
        case lte = "<="
        case eq = "=="
        case gte = ">="
        case gt = ">"
    }
}

extension EquationPart.Variable {
    struct Conv: Conversion {
        typealias Input = [Substring]
        typealias Output = EquationPart.Variable

        func apply(_ input: Input) throws -> EquationPart.Variable {
            .init(head: String(input[0]), tail: input.dropFirst().map(String.init))
        }

        func unapply(_ output: Output) throws -> Input {
            [output.head[...]] + output.tail.map { $0[...] }
        }
    }

    struct CaseConv: Conversion {
        typealias Input = EquationPart.Variable
        typealias Output = EquationPart

        func apply(_ input: Input) throws -> Output {
            .variable(input)
        }

        func unapply(_ output: EquationPart) throws -> EquationPart.Variable {
            switch output {
            case let .variable(v): return v
            default: throw ParsingError()
            }
        }
    }

    static let parser = Many {
        Prefix { !$0.isWhitespace && $0 != "." }
            .filter { !$0.isEmpty }
    } separator: {
        "."
    }
    .filter { !$0.isEmpty }
    .map(Conv())
}

extension EquationPart {
    static let parser = Parse {
        OneOf {
            Double.parser(of: Substring.self).map(.case(EquationPart.constant))
            Operation.parser().map(EquationPart.Operation.Conv())
            Relation.parser().map(EquationPart.Relation.Conv())
            EquationPart.Variable.parser.map(EquationPart.Variable.CaseConv())
        }
        Whitespace(.horizontal)
    }

    static let manyParser = Many {
        parser
    }
}

extension EquationPart.Operation {
    struct Conv: Conversion {
        typealias Input = EquationPart.Operation
        typealias Output = EquationPart

        func apply(_ input: Input) throws -> Output {
            .operation(input)
        }

        func unapply(_ output: EquationPart) throws -> Input {
            switch output {
            case let .operation(op): return op
            default: throw ParsingError()
            }
        }
    }
}

extension EquationPart.Relation {
    struct Conv: Conversion {
        typealias Input = EquationPart.Relation
        typealias Output = EquationPart

        func apply(_ input: Input) throws -> Output {
            .relation(input)
        }

        func unapply(_ output: EquationPart) throws -> Input {
            switch output {
            case let .relation(r): return r
            default: throw ParsingError()
            }
        }
    }
}

let constraintParser = ParsePrint {
    "constrain"
    Whitespace(.horizontal)
    EquationPart.manyParser
    Whitespace()
}

let topLevelParser = Many {
    OneOf {
        nodeStyleParser.map(.case(TopLevelDecl.nodeStyle))
        nodeParser.map(.case(TopLevelDecl.node))
        connectParser.map(.case(TopLevelDecl.connection))
        From(.substring) { constraintParser.map(.case(TopLevelDecl.constraint)) }
    }
}

enum TopLevelDecl: Equatable {
    case nodeStyle(NodeStyle)
    case node(Node)
    case connection(Connection)
    case constraint([EquationPart])

    struct NodeStyle: Equatable {
        let name: String
        let fields: [BlockField]
    }

    struct Node: Equatable {
        let name: String
        let fields: [BlockField]
    }

    struct Connection: Equatable {
        let node1: String
        let node2: String
        let fields: [BlockField]
    }
}

extension TopLevelDecl.NodeStyle {
    struct Conv: Conversion {
        typealias Input = (Substring, [BlockField])
        typealias Output = TopLevelDecl.NodeStyle

        func apply(_ input: Input) throws -> Output { .init(name: String(input.0), fields: input.1) }
        func unapply(_ output: Output) throws -> Input { (output.name[...], output.fields) }
    }
}

extension TopLevelDecl.Node {
    struct Conv: Conversion {
        typealias Input = (Substring, [BlockField])
        typealias Output = TopLevelDecl.Node

        func apply(_ input: Input) throws -> Output { .init(name: String(input.0), fields: input.1) }
        func unapply(_ output: Output) throws -> Input { (output.name[...], output.fields) }
    }
}

extension TopLevelDecl.Connection {
    struct Conv: Conversion {
        typealias Input = (Substring, Substring, [BlockField])
        typealias Output = TopLevelDecl.Connection

        func apply(_ input: Input) throws -> Output {
            .init(node1: String(input.0), node2: String(input.1), fields: input.2)
        }

        func unapply(_ output: Output) throws -> Input { (output.node1[...], output.node2[...], output.fields) }
    }
}
