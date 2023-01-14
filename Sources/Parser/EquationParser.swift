import Parsing

public enum EquationPart: Equatable {
    case variable(Variable)
    case operation(Operation)
    case relation(Relation)
    case constant(Double)

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
