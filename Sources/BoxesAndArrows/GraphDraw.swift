import Cocoa
import Draw

func attributedText(for box: Box) -> AttributedText {
    AttributedText(
        text: box.label,
        textAlignment: .center,
        font: Font.systemDefault(size: 16)
    )
}

func draw<Image>(graph: Graph, graphics: any Graphics<Image>) -> Image {
    var commands: [DrawCommand] = [
        .setFill(.white),
        .fill([graph.frame]),
    ]

    for box in graph.boxes.sorted(by: { $0.key < $1.key }).map(\.value) {
        var attributedText = attributedText(for: box)
        if let textColor = graph.boxStyles.computedStyle(box: box, keyPath: \.textColor) {
            attributedText.textColor = textColor
        }
        commands.append(.addRect(box.frame))
        let lineWidth = graph.boxStyles.computedStyle(box: box, keyPath: \.lineWidth) ?? 1.0
        if let backgroundColor = graph.boxStyles.computedStyle(box: box, keyPath: \.backgroundColor) {
            commands.append(.drawPath(.fillStroke(
                FillStrokeStyle(
                    fill: FillStyle(color: backgroundColor),
                    stroke: StrokeStyle(color: .black, lineWidth: lineWidth)
                )
            )))
        } else {
            commands.append(.drawPath(.stroke(StrokeStyle(color: .black, lineWidth: lineWidth))))
        }
        let textSize = graphics.measure(attributedText: attributedText)
        let xOrigin = box.frame.minX + (box.frame.width / 2.0 - textSize.width / 2.0)
        let yOrigin = box.frame.minY + (box.frame.height / 2.0 - textSize.height / 2.0)
        commands.append(.draw(text: attributedText, point: Point(x: xOrigin, y: yOrigin)))
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
        guard let (start: lineStart, path: pathTail) = findLineStart(
            path: path[...],
            source: source.frame,
            accessGrid: accessGrid
        ) else {
            continue
        }
        guard let (end: lineEnd, path: pathTail) = findLineEnd(
            path: pathTail,
            target: target.frame,
            accessGrid: accessGrid
        ) else {
            continue
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
        commands.append(.drawPath(.stroke(StrokeStyle(color: .black, lineWidth: arrow.lineWidth))))

        switch arrow.sourceHead {
        case .line:
            break
        case .filledVee:
            guard let tailStart = simplifiedTail.first else { break }
            commands.append(contentsOf: filledVeeCommands(
                point: lineStart,
                previous: accessGrid.point(at: tailStart),
                lineWidth: arrow.lineWidth
            ))
        }

        switch arrow.targetHead {
        case .line:
            break
        case .filledVee:
            guard let last = simplifiedTail.last else { break }
            commands.append(contentsOf: filledVeeCommands(
                point: lineEnd,
                previous: accessGrid.point(at: last),
                lineWidth: arrow.lineWidth
            ))
        }
    }

    return graphics.makeDrawing(size: graph.frame.size).draw(commands)
}

func findLineStart(
    path: ArraySlice<AccessGrid.Coordinate>,
    source: Rectangle,
    accessGrid: AccessGrid
) -> (start: Point, path: ArraySlice<AccessGrid.Coordinate>)? {
    guard let path0 = path.first,
          case var pathTail = path.dropFirst(),
          let path1 = pathTail.dropFirst().first
    else { return nil }

    let lineStart: Point
    let pp0: Point = accessGrid.point(at: path0)

    if path0.x == path1.x {
        // vertical
        if path0.y < path1.y {
            // going down, will cross with bottom of box
            lineStart = Point(x: pp0.x, y: source.maxY)
            pathTail = pathTail.drop(while: { accessGrid.point(at: $0).y < lineStart.y })
        } else {
            // going up, will cross with top of box
            lineStart = Point(x: pp0.x, y: source.minY)
            pathTail = pathTail.drop(while: { accessGrid.point(at: $0).y > lineStart.y })
        }
    } else {
        // horizontal
        if path0.x < path1.x {
            // going right, will cross with right edge of box
            lineStart = Point(x: source.maxX, y: pp0.y)
            pathTail = pathTail.drop(while: { accessGrid.point(at: $0).x < lineStart.x })
        } else {
            // going left, will cross with left edge of box
            lineStart = Point(x: source.minX, y: pp0.y)
            pathTail = pathTail.drop(while: { accessGrid.point(at: $0).x > lineStart.x })
        }
    }
    return (start: lineStart, path: pathTail)
}

func findLineEnd(
    path: ArraySlice<AccessGrid.Coordinate>,
    target: Rectangle,
    accessGrid: AccessGrid
) -> (end: Point, path: ArraySlice<AccessGrid.Coordinate>)? {
    var path = path
    guard let pathR0 = path.last, let pathR1 = path.dropLast().last else { return nil }
    let pR0p: Point = accessGrid.point(at: pathR0)
    let lineEnd: Point
    if pathR0.x == pathR1.x {
        // vertical
        if pathR1.y < pathR0.y {
            // second to last is above last, line goes down, will cross top of box
            lineEnd = Point(x: pR0p.x, y: target.minY)
            let lastAbove = path.lastIndex(where: { accessGrid.point(at: $0).y < lineEnd.y }) ?? 0
            path = path.prefix(upTo: lastAbove + 1)
        } else {
            // second to last below last, line goes up, will cross bottom of box
            lineEnd = Point(x: pR0p.x, y: target.maxY)
            let lastBelow = path.lastIndex(where: { accessGrid.point(at: $0).y > lineEnd.y }) ?? 0
            path = path.prefix(upTo: lastBelow + 1)
        }
    } else {
        // horizontal
        if pathR1.x < pathR0.x {
            // second to last left of last, line goes right, will cross left side of box
            lineEnd = Point(x: target.minX, y: pR0p.y)
            let lastLeft = path.lastIndex(where: { accessGrid.point(at: $0).x < lineEnd.x }) ?? 0
            path = path.prefix(upTo: lastLeft + 1)
        } else {
            // second to last right of last, line goes left, will cross right side of box
            lineEnd = Point(x: target.maxX, y: pR0p.y)
            let lastRight = path.lastIndex(where: { accessGrid.point(at: $0).x > lineEnd.x }) ?? 0
            path = path.prefix(upTo: lastRight + 1)
        }
    }
    return (end: lineEnd, path: path)
}

func filledVeeCommands(
    point: Point,
    previous: Point,
    lineWidth: Double
) -> [DrawCommand] {
    let arrowLength = 3.0 + lineWidth
    let arrowWidth = 2.0 + lineWidth

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
    output.append(.drawPath(.fill(FillStyle(color: .black))))

    return output
}
