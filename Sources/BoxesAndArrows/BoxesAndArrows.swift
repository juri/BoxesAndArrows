import Cassowary
import Draw
import Tagged

public struct BoxStyle {
    public enum Tags {
        public enum ID {}
    }

    public typealias ID = Tagged<Tags.ID, String>

    public let id: ID
    public var inherits: [ID] = []
    public var backgroundColor: Color?
    public var textColor: Color?
}

public struct BoxStyles {
    var styles: [BoxStyle.ID: BoxStyle]

    mutating func add(boxStyle: BoxStyle) {
        self.styles[boxStyle.id] = boxStyle
    }

    func computed<T>(style: BoxStyle, keyPath: KeyPath<BoxStyle, T?>) -> T? {
        func collect(style: BoxStyle, seen: Set<BoxStyle.ID> = []) -> T?? {
            guard !seen.contains(style.id) else { return nil }
            var seen = seen
            seen.insert(style.id)
            var value = style[keyPath: keyPath]
            for inheritID in style.inherits {
                guard let inherit = self.styles[inheritID] else { continue }
                guard let inheritedValue = collect(style: inherit, seen: seen), let inheritedValue else { continue }
                value = inheritedValue
            }
            return value
        }
        return collect(style: style) ?? style[keyPath: keyPath]
    }

    func computedStyle<T>(box: Box, keyPath: KeyPath<BoxStyle, T?>) -> T? {
        guard let styleID = box.style, let style = self.styles[styleID] else {
            return nil
        }
        return self.computed(style: style, keyPath: keyPath)
    }
}

public struct Box {
    public enum Tags {
        public enum ID {}
    }

    public typealias ID = Tagged<Tags.ID, String>

    public let id: ID
    public var label: String
    public var style: BoxStyle.ID?

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
        label: String,
        style: BoxStyle.ID? = nil
    ) {
        self.id = id
        self.label = label
        self.style = style

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
        label: String,
        style: BoxStyle.ID? = nil
    ) {
        self.init(id: .init(rawValue: label), label: label, style: style)
    }

    var frame: Rectangle {
        Rectangle(
            origin: Point(x: self.left.variable.value, y: self.top.variable.value),
            size: Size(width: self.width.variable.value, height: self.height.variable.value)
        )
    }
}

public struct Arrow {
    public var lineWidth: Double = 1.0
    public var source: Box.ID
    public var sourceHead: ArrowHead = .line
    public var target: Box.ID
    public var targetHead: ArrowHead = .line
}

public enum ArrowHead {
    case line
    case filledVee
}

public struct ConnectionProperties {
    public var sourceHead: ArrowHead = .line
    public var targetHead: ArrowHead = .line
    public var lineWidth: Double = 1.0

    public static let `default` = ConnectionProperties()
}

extension Arrow {
    init(
        source: Box,
        sourceHead: ArrowHead = .line,
        target: Box,
        targetHead: ArrowHead = .line,
        lineWidth: Double = 1.0
    ) {
        self.init(
            lineWidth: lineWidth,
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
    public var boxStyles: BoxStyles

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
        self.boxStyles = BoxStyles(styles: [:])
    }

    mutating func add(box: Box) {
        self.boxes[box.id] = box
    }

    mutating func add(boxStyle: BoxStyle) {
        self.boxStyles.add(boxStyle: boxStyle)
    }

    mutating func connect(
        _ source: Box,
        to target: Box,
        connectionProperties: ConnectionProperties = .default
    ) {
        self.arrows.append(.init(
            source: source,
            sourceHead: connectionProperties.sourceHead,
            target: target,
            targetHead: connectionProperties.targetHead,
            lineWidth: connectionProperties.lineWidth
        ))
    }

    var frame: Rectangle {
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

            let size = graphics.measure(attributedText: attributedText(for: box))

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
