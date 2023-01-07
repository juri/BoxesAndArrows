import Parsing

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

enum ValidEquationMember: Equatable {
    case term(Term)
    case operation(Operation)
    case relation(Relation)

    indirect enum Term: Equatable {
        case variable(EquationPart.Variable, Next?)
        case constant(Double, Next?)

        enum Next: Equatable {
            case operation(ValidEquationMember.Operation)
            case relation(ValidEquationMember.Relation)
        }

        var next: Next? {
            switch self {
            case let .variable(_, n): return n
            case let .constant(_, n): return n
            }
        }
    }

    struct Operation: Equatable {
        var part: EquationPart.Operation
        var next: Term?
    }

    struct Relation: Equatable {
        var part: EquationPart.Relation
        var next: Term?
    }

    struct ValidatingEquationConversion: Conversion {
        typealias Input = [EquationPart]
        typealias Output = ValidEquationMember

        func apply(_ input: Input) throws -> Output {
            var member: ValidEquationMember?

            var hasRelation: Bool {
                var m = member
                while true {
                    switch m {
                    case .none: return false
                    case .some(.relation): return true
                    case let .some(.term(t)):
                        switch t.next {
                        case .none: return false
                        case .relation: return true
                        case let .operation(op): m = .operation(op)
                        }
                    case let .some(.operation(op)):
                        guard let term = op.next else { return false }
                        m = .term(term)
                    }
                }
            }

            for part in input.reversed() {
                switch (part, member) {
                case let (.constant(c), nil):
                    member = .term(.constant(c, nil))
                case let (.constant(c), .operation(op)):
                    member = .term(.constant(c, .operation(op)))
                case let (.constant(c), .relation(r)):
                    member = .term(.constant(c, .relation(r)))
                case let (.variable(v), nil):
                    member = .term(.variable(v, nil))
                case let (.variable(v), .operation(op)):
                    member = .term(.variable(v, .operation(op)))
                case let (.variable(v), .relation(r)):
                    member = .term(.variable(v, .relation(r)))
                case let (.operation(o), .term(t)):
                    member = .operation(.init(part: o, next: t))
                case let (.relation(r), .term(t)):
                    guard !hasRelation else {
                        throw ParsingError()
                    }
                    member = .relation(.init(part: r, next: t))
                case (.operation, nil),
                     (.relation, nil),
                     (.constant, .term),
                     (.variable, .term),
                     (.relation, .relation),
                     (.relation, .operation),
                     (.operation, .operation),
                     (.operation, .relation):
                    throw ParsingError()
                }
            }
            guard let member else { throw ParsingError() }
            guard hasRelation else { throw ParsingError() }
            return member
        }

        func unapply(_ output: Output) throws -> Input {
            var parts = [EquationPart]()
            var member = output
            outer: while true {
                switch member {
                case let .term(t):
                    switch t {
                    case let .constant(c, next):
                        parts.append(.constant(c))
                        switch next {
                        case .none: break outer
                        case let .relation(r): member = .relation(r)
                        case let .operation(o): member = .operation(o)
                        }
                    case let .variable(v, next):
                        parts.append(.variable(v))
                        switch next {
                        case .none: break outer
                        case let .relation(r): member = .relation(r)
                        case let .operation(o): member = .operation(o)
                        }
                    }
                case let .operation(op):
                    parts.append(.operation(op.part))
                    guard let next = op.next else {
                        break outer
                    }
                    member = .term(next)
                case let .relation(rel):
                    parts.append(.relation(rel.part))
                    guard let next = rel.next else {
                        break outer
                    }
                    member = .term(next)
                }
            }
            return parts
        }
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
