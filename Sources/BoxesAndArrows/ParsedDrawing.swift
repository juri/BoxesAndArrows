import Cassowary
import Draw
import Parser

public func drawSpec<T>(_ spec: String, graphics: any Graphics<T>) throws -> T {
    let decls = try parse(spec)
    var graph = Graph()
    var boxStyles = [BoxStyle.ID: BoxStyle]()
    var parsedBoxes = [String: TopLevelDecl.Box]()
    var parsedArrows = [TopLevelDecl.Arrow]()
    var constraints = [Equation]()

    for decl in decls {
        switch decl {
        case let .boxStyle(style):
            let boxStyle = try boxStyle(from: style)
            boxStyles[boxStyle.id] = boxStyle
        case let .box(box):
            parsedBoxes[box.name] = box
        case let .arrow(connection):
            parsedArrows.append(connection)
        case let .constraint(equationPart):
            constraints.append(equationPart)
        case .lineComment:
            break
        }
    }

    var boxes = [Box.ID: Box]()
    for (_, parsedBox) in parsedBoxes {
        let (box, style) = try box(from: parsedBox, styles: boxStyles)
        graph.add(box: box)
        boxes[box.id] = box
        if let style {
            graph.add(boxStyle: style)
        }
    }
    for style in boxStyles.values {
        graph.add(boxStyle: style)
    }

    for connection in parsedArrows {
        guard let box1 = boxes[.init(rawValue: connection.box1)] else {
            throw UndefinedReferenceError(name: connection.box1)
        }
        guard let box2 = boxes[.init(rawValue: connection.box2)] else {
            throw UndefinedReferenceError(name: connection.box2)
        }

        let properties = try connectionProperties(from: connection.fields)

        graph.connect(box1, to: box2, connectionProperties: properties)
    }

    func variable(_ name: Equation.Variable) throws -> Variable {
        guard let box = boxes[.init(name.head)] else {
            throw UndefinedReferenceError(name: name.head)
        }
        guard let tailHead = name.tail.first, name.tail.count == 1 else {
            throw UndefinedReferenceError(name: "\(name.head).\(name.tail.joined(separator: "."))")
        }
        switch tailHead {
        case "top": return box.top.variable
        case "bottom": return box.bottom.variable
        case "left": return box.left.variable
        case "right": return box.right.variable
        case "centerX": return box.centerX.variable
        case "centerY": return box.centerY.variable
        case "height": return box.height.variable
        case "width": return box.width.variable
        default:
            throw UndefinedReferenceError(name: "\(name.head).\(tailHead)")
        }
    }

    let solver = try graph.makeSolver(graphics: graphics)
    for constraint in constraints {
        let (relation, lhs, rhs) = (constraint.relation, constraint.left, constraint.right) // try splitSides(constraint)
        let lhse = try expression(from: lhs, findVariable: variable(_:))
        let rhse = try expression(from: rhs, findVariable: variable(_:))

        let cconstraint: Cassowary.Constraint
        switch relation {
        case .lte:
            cconstraint = lhse <= rhse
        case .eq:
            cconstraint = lhse == rhse
        case .gte:
            cconstraint = lhse >= rhse
        case .gt, .lt:
            throw EquationFormatError(equation: constraint)
        }
        try solver.add(constraint: cconstraint)
    }

    solver.update()
    return draw(graph: graph, graphics: graphics)
}

private func expression(
    from sideParts: [Equation.Part],
    findVariable: (Equation.Variable) throws -> Cassowary.Variable
) throws -> Cassowary.Expression {
    enum State {
        case initial
        case const(Double)
        case constOp(Double, Equation.Operation)
        case term(Cassowary.Term)
        case termOp(Cassowary.Term, Equation.Operation)
        case expr(Cassowary.Expression)
        case exprOp(Cassowary.Expression, Equation.Operation)
    }
    var state = State.initial
    for sidePart in sideParts {
        switch (sidePart, state) {
        case let (.constant(d), .initial):
            state = .const(d)
        case (.constant, .const):
            throw EquationSideFormatError(parts: sideParts)
        case let (.constant(d), .constOp(sd, sop)):
            state = .const(sop.apply(double1: sd, double2: d))
        case (.constant, .term):
            throw EquationSideFormatError(parts: sideParts)
        case let (.constant(d), .termOp(st, sop)):
            switch sop {
            case .add: state = .expr(st + d)
            case .sub: state = .expr(st - d)
            case .mult: state = .term(st * d)
            case .div: state = .term(st / d)
            }
        case (.constant, .expr):
            throw EquationSideFormatError(parts: sideParts)
        case let (.constant(d), .exprOp(se, sop)):
            switch sop {
            case .add: state = .expr(se + d)
            case .sub: state = .expr(se - d)
            case .mult: state = .expr(se * d)
            case .div: state = .expr(se / d)
            }

        case (.operation, .initial),
             (.operation, .constOp),
             (.operation, .termOp),
             (.operation, .exprOp):
            throw EquationSideFormatError(parts: sideParts)
        case let (.operation(o), .const(d)):
            state = .constOp(d, o)
        case let (.operation(o), .term(t)):
            state = .termOp(t, o)
        case let (.operation(o), .expr(e)):
            state = .exprOp(e, o)

        case (.variable, .const),
             (.variable, .term),
             (.variable, .expr):
            throw EquationSideFormatError(parts: sideParts)
        case let (.variable(v), .initial):
            let variable = try findVariable(v)
            state = .term(.init(variable))
        case let (.variable(v), .constOp(sd, sop)):
            let variable = try findVariable(v)
            switch sop {
            case .add: state = .expr(sd + variable)
            case .sub: state = .expr(sd - variable)
            case .mult: state = .term(sd * variable)
            case .div: throw EquationSideFormatError(parts: sideParts)
            }
        case let (.variable(v), .termOp(st, sop)):
            let variable = try findVariable(v)
            switch sop {
            case .add: state = .expr(st + variable)
            case .sub: state = .expr(st - variable)
            case .mult, .div: throw EquationSideFormatError(parts: sideParts)
            }
        case let (.variable(v), .exprOp(se, sop)):
            let variable = try findVariable(v)
            switch sop {
            case .add: state = .expr(se + variable)
            case .sub: state = .expr(se - variable)
            case .mult, .div: throw EquationSideFormatError(parts: sideParts)
            }
        }
    }

    switch state {
    case let .expr(expr): return expr
    case let .term(term): return Expression(term)
    case let .const(const): return Expression(const)
    default: throw EquationSideFormatError(parts: sideParts)
    }
}

private extension Equation.Operation {
    func apply(double1: Double, double2: Double) -> Double {
        switch self {
        case .add: return double1 + double2
        case .sub: return double1 - double2
        case .mult: return double1 * double2
        case .div: return double1 / double2
        }
    }
}

private func boxStyle(from style: TopLevelDecl.BoxStyle) throws -> BoxStyle {
    var boxStyle = BoxStyle(id: .init(style.name))
    for field in style.fields {
        switch field {
        case let .color(colorField):
            switch colorField.fieldID {
            case .textColor: boxStyle.textColor = colorField.value
            case .backgroundColor: boxStyle.backgroundColor = colorField.value
            }
        case let .numeric(numericField):
            throw UnsupportedFieldTypeError(field: numericField.fieldID.rawValue)
        case let .string(stringField):
            throw UnsupportedFieldTypeError(field: stringField.fieldID.rawValue)
        case let .variable(variableField):
            throw UnsupportedFieldTypeError(field: variableField.fieldID.rawValue)
        case .lineComment:
            break
        }
    }
    return boxStyle
}

struct UnsupportedFieldTypeError: Error {
    var field: String
}

struct UndefinedReferenceError: Error {
    var name: String
}

struct EquationFormatError: Error {
    var equation: Equation
}

struct EquationSideFormatError: Error {
    var parts: [Equation.Part]
}

private func box(
    from parsedBox: TopLevelDecl.Box,
    styles: [BoxStyle.ID: BoxStyle]
) throws -> (Box, BoxStyle?) {
    var parentStyle: BoxStyle.ID?
    var style = BoxStyle(id: .init("__!__box_\(parsedBox.name)"))
    var label: String?
    for field in parsedBox.fields {
        switch field {
        case let .color(colorField):
            switch colorField.fieldID {
            case .backgroundColor: style.backgroundColor = colorField.value
            case .textColor: style.textColor = colorField.value
            }

        case let .numeric(numericField):
            switch numericField.fieldID {
            case .lineWidth:
                throw UnsupportedFieldTypeError(field: numericField.fieldID.rawValue)
            }

        case let .string(stringField):
            switch stringField.fieldID {
            case .label: label = stringField.value
            }

        case let .variable(variableField):
            switch variableField.fieldID {
            case .style:
                let styleID = BoxStyle.ID(rawValue: variableField.value)
                guard styles[styleID] != nil else {
                    throw UndefinedReferenceError(name: variableField.value)
                }
                parentStyle = styleID
            case .head1, .head2:
                throw UnsupportedFieldTypeError(field: variableField.fieldID.rawValue)
            }

        case .lineComment:
            break
        }
    }

    let boxStyleID: BoxStyle.ID?
    var returnedStyle: BoxStyle? = nil
    if style.textColor != nil || style.backgroundColor != nil {
        if let parentStyle {
            style.inherits = [parentStyle]
        }
        returnedStyle = style
        boxStyleID = style.id
    } else if let parentStyle {
        boxStyleID = parentStyle
    } else {
        boxStyleID = nil
    }
    let box = Box(
        id: Box.ID(rawValue: parsedBox.name),
        label: label ?? parsedBox.name,
        style: boxStyleID
    )
    return (box, returnedStyle)
}

private func connectionProperties(
    from fields: [BlockField]
) throws -> ConnectionProperties {
    var properties = ConnectionProperties()

    for field in fields {
        switch field {
        case let .color(colorField):
            switch colorField.fieldID {
            case .backgroundColor: throw UnsupportedFieldTypeError(field: colorField.fieldID.rawValue)
            case .textColor: throw UnsupportedFieldTypeError(field: colorField.fieldID.rawValue)
            }

        case let .numeric(numericField):
            switch numericField.fieldID {
            case .lineWidth: properties.lineWidth = numericField.value
            }

        case let .string(stringField):
            switch stringField.fieldID {
            case .label: throw UnsupportedFieldTypeError(field: stringField.fieldID.rawValue)
            }

        case let .variable(variableField):
            switch variableField.fieldID {
            case .style:
                throw UnsupportedFieldTypeError(field: variableField.fieldID.rawValue)
            case .head1:
                properties.sourceHead = try arrowHead(with: variableField.value)
            case .head2:
                properties.targetHead = try arrowHead(with: variableField.value)
            }

        case .lineComment:
            break
        }
    }

    return properties
}

private let arrowHeads: [String: ArrowHead] = [
    "line": .line,
    "filled_vee": .filledVee,
]

private func arrowHead(with name: String) throws -> ArrowHead {
    guard let head = arrowHeads[name] else {
        throw UndefinedReferenceError(name: name)
    }
    return head
}
