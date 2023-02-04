import Parsing

public enum EquationPart: Equatable {
    case variable(Variable)
    case operation(Operation)
    case relation(Relation)
    case constant(Double)
    case lineComment(LineComment)

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

    public var isRelation: Bool {
        guard case .relation = self else {
            return false
        }
        return true
    }

    public var relation: Relation? {
        guard case let .relation(r) = self else {
            return nil
        }
        return r
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

extension EquationPart.LineComment {
    static let parser = Parse {
        "//"
        Prefix(while: { !$0.isNewline })
        OneOf {
            Whitespace(1, .vertical)
            End()
        }
    }

    struct Conv: Conversion {
        typealias Input = Substring
        typealias Output = EquationPart

        func apply(_ input: Input) throws -> Output {
            .lineComment(EquationPart.LineComment(text: String(input)))
        }

        func unapply(_ output: Output) throws -> Input {
            switch output {
            case let .lineComment(l): return l.text[...]
            default: throw ParsingError()
            }
        }
    }
}

extension EquationPart {
    static let parser = ParsePrint {
        OneOf {
            LineComment.parser.map(EquationPart.LineComment.Conv())
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

public struct Equation: Equatable {
    public enum Part: Equatable {
        case variable(EquationPart.Variable)
        case operation(EquationPart.Operation)
        case constant(Double)
    }

    public var relation: EquationPart.Relation
    public var left: [Equation.Part]
    public var right: [Equation.Part]
    public var lineComment: EquationPart.LineComment?
}

extension Equation {
    struct Conv: Conversion {
        typealias Input = [EquationPart]
        typealias Output = Equation

        func apply(_ input: [EquationPart]) throws -> Equation {
            try Equation(rawParts: input)
        }

        func unapply(_ output: Equation) throws -> [EquationPart] {
            let leftParts = output.left.map(\.raw)
            let rightParts = output.right.map(\.raw)
            var parts = leftParts + [.relation(output.relation)] + rightParts
            if let lineComment = output.lineComment {
                parts.append(.lineComment(lineComment))
            }
            return parts
        }
    }

    static let parser = EquationPart.manyParser
        .map(Conv())

    init(rawParts: [EquationPart]) throws {
        var relation: EquationPart.Relation? = nil
        var left = [Equation.Part]()
        var right = [Equation.Part]()
        var lineComment: EquationPart.LineComment? = nil

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
    init(rawPart: EquationPart) throws {
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

    var raw: EquationPart {
        switch self {
        case let .operation(o): return .operation(o)
        case let .variable(v): return .variable(v)
        case let .constant(c): return .constant(c)
        }
    }
}
