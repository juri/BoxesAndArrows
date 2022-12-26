import Cassowary
import CoreGraphics
import Draw
import Tagged

public struct Box {
    public enum Tags {
        public enum ID {}
    }

    public typealias ID = Tagged<Tags.ID, String>

    public let id: ID
    public var label: String

    var top: Anchor<Vertical>
    var centerY: Anchor<Vertical>
    var bottom: Anchor<Vertical>

    var left: Anchor<Horizontal>
    var centerX: Anchor<Horizontal>
    var right: Anchor<Horizontal>

    var height: Anchor<Dimension>
    var width: Anchor<Dimension>

    init(
        id: ID,
        label: String
    ) {
        self.id = id
        self.label = label

        self.top = Anchor(variable: Variable("\(id.rawValue).top"))
        self.centerY = Anchor(variable: Variable("\(id.rawValue).centerY"))
        self.bottom = Anchor(variable: Variable("\(id.rawValue).bottom"))
        self.left = Anchor(variable: Variable("\(id.rawValue).left"))
        self.centerX = Anchor(variable: Variable("\(id.rawValue).centerX"))
        self.right = Anchor(variable: Variable("\(id.rawValue).right"))
        self.height = Anchor(variable: Variable("\(id.rawValue).height"))
        self.width = Anchor(variable: Variable("\(id.rawValue).width"))
    }

    init(
        label: String
    ) {
        self.init(id: .init(rawValue: label), label: label)
    }

    var frame: CGRect {
        CGRect(
            origin: CGPoint(x: self.left.variable.value, y: self.top.variable.value),
            size: CGSize(width: self.width.variable.value, height: self.height.variable.value)
        )
    }

    var frameRectangle: Rectangle {
        Rectangle(
            origin: Point(x: self.left.variable.value, y: self.top.variable.value),
            size: Size(width: self.width.variable.value, height: self.height.variable.value)
        )
    }
}

public struct Arrow {
    public var source: Box.ID
    public var sourceHead: ArrowHead = .line
    public var target: Box.ID
    public var targetHead: ArrowHead = .line
}

public enum ArrowHead {
    case line
    case filledVee
}

extension Arrow {
    init(
        source: Box,
        sourceHead: ArrowHead = .line,
        target: Box,
        targetHead: ArrowHead = .line
    ) {
        self.init(
            source: source.id,
            sourceHead: sourceHead,
            target: target.id,
            targetHead: targetHead
        )
    }
}

public struct Graph {
    public var boxes: [Box.ID: Box] = [:]
    public var arrows: [Arrow] = []

    var top: Anchor<Vertical>
    var centerY: Anchor<Vertical>
    var bottom: Anchor<Vertical>

    var left: Anchor<Horizontal>
    var centerX: Anchor<Horizontal>
    var right: Anchor<Horizontal>

    var height: Anchor<Dimension>
    var width: Anchor<Dimension>

    init() {
        self.top = Anchor(variable: Variable("..top"))
        self.centerY = Anchor(variable: Variable("..centerY"))
        self.bottom = Anchor(variable: Variable("..bottom"))
        self.left = Anchor(variable: Variable("..left"))
        self.centerX = Anchor(variable: Variable("..centerX"))
        self.right = Anchor(variable: Variable("..right"))
        self.height = Anchor(variable: Variable("..height"))
        self.width = Anchor(variable: Variable("..width"))
    }

    mutating func add(box: Box) {
        self.boxes[box.id] = box
    }

    mutating func connect(_ source: Box, to target: Box, sourceHead: ArrowHead = .line, targetHead: ArrowHead = .line) {
        self.arrows.append(.init(source: source, sourceHead: sourceHead, target: target, targetHead: targetHead))
    }

    var frame: CGRect {
        CGRect(
            origin: CGPoint(x: self.left.variable.value, y: self.top.variable.value),
            size: CGSize(width: self.width.variable.value, height: self.height.variable.value)
        )
    }

    var frameRectangle: Rectangle {
        Rectangle(
            origin: Point(x: self.left.variable.value, y: self.top.variable.value),
            size: Size(width: self.width.variable.value, height: self.height.variable.value)
        )
    }
}

public enum Vertical {
    case boxTop
    case boxMiddle
    case boxBottom
    case graphTop
    case graphMiddle
    case graphBottom
}

public enum Horizontal {
    case boxLeft
    case boxMiddle
    case boxRight
    case graphLeft
    case graphMiddle
    case graphRight
}

public enum Dimension {
    case height
    case width
}

public struct Anchor<Direction> {
    var variable: Variable
}

extension Graph {
    func makeSolver(graphics: any Graphics) throws -> Solver {
        let solver = Solver()
        let outerMargin = 50.0
        for box in self.boxes.values {
            try solver.add(constraint: box.left.variable <= box.centerX.variable)
            try solver.add(constraint: box.centerX.variable <= box.right.variable)
            try solver.add(constraint: box.top.variable <= box.centerY.variable)
            try solver.add(constraint: box.centerY.variable <= box.bottom.variable)

            try solver.add(constraint: box.left.variable >= self.left.variable + outerMargin)
            try solver.add(constraint: box.top.variable >= self.top.variable + outerMargin)
            try solver.add(constraint: box.right.variable <= self.right.variable - outerMargin)
            try solver.add(constraint: box.bottom.variable <= self.bottom.variable - outerMargin)

            let size = graphics.measure(attributedString: attributedString(for: box))

            try solver.add(constraint: box.height.variable >= 0)
            try solver.add(constraint: box.height.variable >= size.height)
            try solver.add(constraint: box.width.variable >= 0)
            try solver.add(constraint: box.width.variable >= size.width)

            try solver.add(constraint: box.bottom.variable == box.top.variable + size.height)
            try solver.add(constraint: box.centerY.variable == box.top.variable + size.height / 2.0)
            try solver.add(constraint: box.right.variable == box.left.variable + size.width)
            try solver.add(constraint: box.centerX.variable == box.left.variable + size.width / 2.0)
        }

        try solver.add(constraint: self.left.variable == 0)
        try solver.add(constraint: self.left.variable <= self.right.variable)
        try solver.add(constraint: self.centerX.variable <= self.right.variable)
        try solver.add(constraint: self.top.variable == 0)
        try solver.add(constraint: self.top.variable <= self.centerY.variable)
        try solver.add(constraint: self.centerY.variable <= self.bottom.variable)

        try solver.add(constraint: self.height.variable == self.bottom.variable - self.top.variable)
        try solver.add(constraint: self.width.variable == self.right.variable - self.left.variable)

        return solver
    }
}
