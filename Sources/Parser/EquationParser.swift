import Parsing

// MARK: Equation

/// `Equation` is the output of the equation parser. Some sanity checking has been done on it, and its split to sides.
public struct Equation: Equatable {
    public var relation: Relation
    public var left: [Equation.Part]
    public var right: [Equation.Part]
    public var lineComment: LineComment?
}

extension Equation {
    public enum Part: Equatable {
        case variable(Variable)
        case operation(Operation)
        case constant(Double)
    }

    public struct Variable: Hashable {
        public let head: String
        public let tail: [String]
    }

    public enum Operation: String, Equatable, CaseIterable {
        case add = "+"
        case sub = "-"
        case mult = "*"
        case div = "/"
    }

    public enum Relation: String, Equatable, CaseIterable {
        case lt = "<"
        case lte = "<="
        case eq = "=="
        case gte = ">="
        case gt = ">"
    }

    public struct LineComment: Hashable {
        public let text: String
    }
}

extension Equation.Part {
    func canBeFollowed(by part: Equation.Part) -> Bool {
        switch (self, part) {
        case (.variable, .operation),
             (.constant, .operation),
             (.operation, .variable),
             (.operation, .constant):
            return true
        default:
            return false
        }
    }
}

extension Equation.Variable {
    struct Conv: Conversion {
        typealias Input = [Substring]
        typealias Output = Equation.Variable

        func apply(_ input: Input) throws -> Equation.Variable {
            .init(head: String(input[0]), tail: input.dropFirst().map(String.init))
        }

        func unapply(_ output: Output) throws -> Input {
            [output.head[...]] + output.tail.map { $0[...] }
        }
    }

    /// A parser for a multipart string, parts separated by `.`.
    static let parser = Many {
        Prefix { !$0.isWhitespace && $0 != "." }
            .filter { !$0.isEmpty }
    } separator: {
        "."
    }
    .filter { !$0.isEmpty }
    .map(Conv())
}

extension Equation.LineComment {
    /// A parser for a line comment: starts with a `//`, terminates with end of line or end of input.
    static let parser = Parse {
        "//"
        Prefix(while: { !$0.isNewline })
        OneOf {
            Whitespace(1, .vertical)
            End()
        }
    }
}

// MARK: - EquationPartRaw

/// `EquationPartRaw` is a raw part of the equation. These will go through sanity checks when converted to `Equation.Part` and
/// split into `Equation`.
enum EquationPartRaw: Equatable {
    case variable(Equation.Variable)
    case operation(Equation.Operation)
    case relation(Equation.Relation)
    case constant(Double)
    case lineComment(Equation.LineComment)
}

extension EquationPartRaw {
    /// A parser for one raw equation part followed by whitespace.
    static let parser = ParsePrint {
        OneOf {
            Equation.LineComment.parser.map(Equation.LineComment.Conv())
            Double.parser(of: Substring.self).map(.case(EquationPartRaw.constant))
            Equation.Operation.parser().map(Equation.Operation.Conv())
            Equation.Relation.parser().map(Equation.Relation.Conv())
            Equation.Variable.parser.map(Equation.Variable.CaseConv())
        }
        Whitespace(.horizontal)
    }

    /// A parser for many equation parts raw.
    static let manyParser = Many {
        parser
    }
}

extension Equation.Operation {
    struct Conv: Conversion {
        typealias Input = Equation.Operation
        typealias Output = EquationPartRaw

        func apply(_ input: Input) throws -> Output {
            .operation(input)
        }

        func unapply(_ output: EquationPartRaw) throws -> Input {
            switch output {
            case let .operation(op): return op
            default: throw ParsingError()
            }
        }
    }
}

extension Equation.Relation {
    struct Conv: Conversion {
        typealias Input = Equation.Relation
        typealias Output = EquationPartRaw

        func apply(_ input: Input) throws -> Output {
            .relation(input)
        }

        func unapply(_ output: EquationPartRaw) throws -> Input {
            switch output {
            case let .relation(r): return r
            default: throw ParsingError()
            }
        }
    }
}

extension Equation.Variable {
    struct CaseConv: Conversion {
        typealias Input = Equation.Variable
        typealias Output = EquationPartRaw

        func apply(_ input: Input) throws -> Output {
            .variable(input)
        }

        func unapply(_ output: EquationPartRaw) throws -> Equation.Variable {
            switch output {
            case let .variable(v): return v
            default: throw ParsingError()
            }
        }
    }
}

extension Equation.LineComment {
    struct Conv: Conversion {
        typealias Input = Substring
        typealias Output = EquationPartRaw

        func apply(_ input: Input) throws -> Output {
            .lineComment(Equation.LineComment(text: String(input)))
        }

        func unapply(_ output: Output) throws -> Input {
            switch output {
            case let .lineComment(l): return l.text[...]
            default: throw ParsingError()
            }
        }
    }
}

extension Equation {
    struct Conv: Conversion {
        typealias Input = [EquationPartRaw]
        typealias Output = Equation

        func apply(_ input: [EquationPartRaw]) throws -> Equation {
            try Equation(rawParts: input)
        }

        func unapply(_ output: Equation) throws -> [EquationPartRaw] {
            let leftParts = output.left.map(\.raw)
            let rightParts = output.right.map(\.raw)
            var parts = leftParts + [.relation(output.relation)] + rightParts
            if let lineComment = output.lineComment {
                parts.append(.lineComment(lineComment))
            }
            return parts
        }
    }

    static let parser = EquationPartRaw.manyParser
        .map(Conv())

    init(rawParts: [EquationPartRaw]) throws {
        var relation: Relation? = nil
        var left = [Equation.Part]()
        var right = [Equation.Part]()
        var lineComment: LineComment? = nil

        func append(part: Equation.Part, to parts: inout [Equation.Part]) throws {
            if let prev = parts.last, !prev.canBeFollowed(by: part) {
                throw ParsingError()
            }
            parts.append(part)
        }

        func append(part: Equation.Part) throws {
            if relation == nil {
                try append(part: part, to: &left)
            } else {
                try append(part: part, to: &right)
            }
        }

    loop: for rawPart in rawParts {
            switch (relation, rawPart) {
            case let (nil, .relation(r)): relation = r
            case (.some, .relation): throw ParsingError()

            case let (nil, .variable(v)):
                try append(part: .variable(v))
            case let (nil, .operation(o)):
                try append(part: .operation(o))
            case let (nil, .constant(c)):
                try append(part: .constant(c))
            case (nil, .lineComment):
                throw ParsingError()

            case let (.some, .variable(v)):
                try append(part: .variable(v))
            case let (.some, .operation(o)):
                try append(part: .operation(o))
            case let (.some, .constant(c)):
                try append(part: .constant(c))
            case let (.some, .lineComment(l)):
                lineComment = l
                break loop
            }
        }

        guard let relation, !left.isEmpty, !right.isEmpty else {
            throw ParsingError()
        }
        self.init(
            relation: relation,
            left: left,
            right: right,
            lineComment: lineComment
        )
    }
}

extension Equation.Part {
    init(rawPart: EquationPartRaw) throws {
        switch rawPart {
        case let .variable(variable):
            self = .variable(variable)
        case let .operation(operation):
            self = .operation(operation)
        case .relation:
            throw ParsingError()
        case let .constant(double):
            self = .constant(double)
        case .lineComment:
            throw ParsingError()
        }
    }

    var raw: EquationPartRaw {
        switch self {
        case let .operation(o): return .operation(o)
        case let .variable(v): return .variable(v)
        case let .constant(c): return .constant(c)
        }
    }
}
