import Cocoa
import Draw

func attributedString(for box: Box) -> AttributedString {
    var ats = AttributedString(box.label)
    ats.font = NSFont.systemFont(ofSize: 16)
    ats.paragraphStyle = {
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.alignment = .center
        return paragraphStyle
    }()
    return ats
}

func draw<Image>(graph: Graph, graphics: any Graphics<Image>) -> Image {
    var commands: [DrawCommand] = [
        .setFill(.white),
        .fill([graph.frame]),
    ]

    for box in graph.boxes.values {
        var attributedString = attributedString(for: box)
        if let textColor = graph.boxStyles.computedStyle(box: box, keyPath: \.textColor), let textColor {
            attributedString.textColor = textColor
        }
        commands.append(.draw(text: attributedString, point: box.frame.origin))
        commands.append(.addRect(box.frame))
        commands.append(.strokePath)
    }

    let connectionPointRegister = ConnectionPointRegister()
    for (counter, arrow) in zip(1..., graph.arrows) {
        let source = graph.boxes[arrow.source]!
        let target = graph.boxes[arrow.target]!
        let accessGrid = AccessGrid(
            graph: graph,
            sourceBox: source,
            targetBox: target,
            cellSize: 5,
            rectMargin: Double(counter) * 4.0
        )
        let path = accessGrid.path(
            connectionPointRegister: connectionPointRegister
        )
        guard let path0 = path.first,
              case var pathTail = path.dropFirst(),
              let path1 = pathTail.dropFirst().first
        else { continue }

        let lineStart: Point
        let pp0: Point = accessGrid.point(at: path0)

        if path0.x == path1.x {
            // vertical
            if path0.y < path1.y {
                // going down, will cross with bottom of box
                lineStart = Point(x: pp0.x, y: source.frame.maxY)
                pathTail = pathTail.drop(while: { accessGrid.point(at: $0).y < lineStart.y })
            } else {
                // going up, will cross with top of box
                lineStart = Point(x: pp0.x, y: source.frame.minY)
                pathTail = pathTail.drop(while: { accessGrid.point(at: $0).y > lineStart.y })
            }
        } else {
            // horizontal
            if path0.x < path1.x {
                // going right, will cross with right edge of box
                lineStart = Point(x: source.frame.maxX, y: pp0.y)
                pathTail = pathTail.drop(while: { accessGrid.point(at: $0).x < lineStart.x })
            } else {
                // going left, will cross with left edge of box
                lineStart = Point(x: source.frame.minX, y: pp0.y)
                pathTail = pathTail.drop(while: { accessGrid.point(at: $0).x > lineStart.x })
            }
        }

        // target end of line
        guard let pathR0 = pathTail.last, let pathR1 = pathTail.dropLast().last else { continue }
        let pR0p: Point = accessGrid.point(at: pathR0)
        let lineEnd: Point
        if pathR0.x == pathR1.x {
            // vertical
            if pathR1.y < pathR0.y {
                // second to last is above last, line goes down, will cross top of box
                lineEnd = Point(x: pR0p.x, y: target.frame.minY)
                let lastAbove = pathTail.lastIndex(where: { accessGrid.point(at: $0).y < lineEnd.y }) ?? 0
                pathTail = pathTail.prefix(upTo: lastAbove + 1)
            } else {
                // second to last below last, line goes up, will cross bottom of box
                lineEnd = Point(x: pR0p.x, y: target.frame.maxY)
                let lastBelow = pathTail.lastIndex(where: { accessGrid.point(at: $0).y > lineEnd.y }) ?? 0
                pathTail = pathTail.prefix(upTo: lastBelow + 1)
            }
        } else {
            // horizontal
            if pathR1.x < pathR0.x {
                // second to last left of last, line goes right, will cross left side of box
                lineEnd = Point(x: target.frame.minX, y: pR0p.y)
                let lastLeft = pathTail.lastIndex(where: { accessGrid.point(at: $0).x < lineEnd.x }) ?? 0
                pathTail = pathTail.prefix(upTo: lastLeft + 1)
            } else {
                // second to last right of last, line goes left, will cross right side of box
                lineEnd = Point(x: target.frame.maxX, y: pR0p.y)
                let lastRight = pathTail.lastIndex(where: { accessGrid.point(at: $0).x > lineEnd.x }) ?? 0
                pathTail = pathTail.prefix(upTo: lastRight + 1)
            }
        }

        commands.append(.move(lineStart))
        let simplifiedTail = pathTail.reduce(into: [AccessGrid.Coordinate]()) { acc, coord in
            if let p0 = acc.last,
               let p1 = acc.dropLast(1).last,
               (coord.x == p0.x && coord.x == p1.x) || (coord.y == p0.y && coord.y == p1.y)
            {
                acc[acc.endIndex - 1] = coord
            } else {
                acc.append(coord)
            }
        }
        for coordinate in simplifiedTail {
            commands.append(.addLine(accessGrid.point(at: coordinate)))
        }
        commands.append(.addLine(lineEnd))
        commands.append(.strokePath)

        switch arrow.targetHead {
        case .line:
            break
        case .filledVee:
            guard let last = simplifiedTail.last else { break }
            commands.append(contentsOf: filledVeeCommands(point: lineEnd, previous: accessGrid.point(at: last)))
        }
    }

    return graphics.makeDrawing(size: graph.frame.size).draw(commands)
}

func filledVeeCommands(
    point: Point,
    previous: Point
) -> [DrawCommand] {
    let arrowLength = 4.0
    let arrowWidth = 3.0

    var output: [DrawCommand] = [.move(point)]

    if point.x == previous.x && point.y < previous.y {
        let base = point.y + arrowLength
        output.append(.addLine(.init(x: point.x - arrowWidth, y: base)))
        output.append(.addLine(.init(x: point.x + arrowWidth, y: base)))
    } else if point.x == previous.x && point.y > previous.y {
        let base = point.y - arrowLength
        output.append(.addLine(.init(x: point.x - arrowWidth, y: base)))
        output.append(.addLine(.init(x: point.x + arrowWidth, y: base)))
    } else if point.y == previous.y && point.x < previous.x {
        let base = point.x + arrowLength
        output.append(.addLine(.init(x: base, y: point.y - arrowWidth)))
        output.append(.addLine(.init(x: base, y: point.y + arrowWidth)))
    } else if point.y == previous.y && point.x > previous.x {
        let base = point.x - arrowLength
        output.append(.addLine(.init(x: base, y: point.y - arrowWidth)))
        output.append(.addLine(.init(x: base, y: point.y + arrowWidth)))
    } else {
        return []
    }

    output.append(.addLine(point))
    output.append(.fillPath)

    return output
}
