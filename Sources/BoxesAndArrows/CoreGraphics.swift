import Foundation
import Cocoa
import CoreGraphics

func measure(box: Box) -> CGSize {
    let attributedString = attributedString(for: box)
    let boundingRect = attributedString.boundingRect(
        with: .init(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
        options: .usesLineFragmentOrigin
    )
    return boundingRect.size
}

func attributedString(for box: Box) -> NSAttributedString {
    let font = NSFont.systemFont(ofSize: 16)
    let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    paragraphStyle.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .paragraphStyle: paragraphStyle
    ]
    let attributedString = NSAttributedString(string: box.label, attributes: attributes)
    return attributedString
}

func draw(graph: Graph) -> NSImage {
    draw(width: graph.width.variable.value, height: graph.height.variable.value) { ctx, rect in
        NSColor.white.setFill()
        ctx.fill([rect])

        for box in graph.boxes.values {
            let attributedString = attributedString(for: box)
            attributedString.draw(at: box.frame.origin)
            ctx.addRect(box.frame)
            ctx.strokePath()
        }

        let connectionPointRegister = ConnectionPointRegister()
        for arrow in graph.arrows {
            let source = graph.boxes[arrow.source]!
            let target = graph.boxes[arrow.target]!
            var accessGrid = AccessGrid(
                graph: graph,
                sourceBox: source,
                targetBox: target,
                cellSize: 5
            )
            let path = accessGrid.path(
                from: source.frame,
                to: target.frame,
                connectionPointRegister: connectionPointRegister
            )
            guard let path = path,
                  let path0 = path.first,
                  case var pathTail = path.dropFirst(),
                  let path1 = pathTail.dropFirst().first
            else { continue }

            let lineStart: CGPoint
            let pp0 = accessGrid.point(at: path0)
            let pp1 = accessGrid.point(at: path1)

            if path0.x == path1.x  {
                // vertical
                if path0.y < path1.y {
                    // going down, will cross with bottom of box
                    lineStart = CGPoint(x: pp0.x, y: source.frame.maxY)
                    pathTail = pathTail.drop(while: { accessGrid.point(at: $0).y < lineStart.y })
                } else {
                    // going up, will cross with top of box
                    lineStart = CGPoint(x: pp0.x, y: source.frame.minY)
                    pathTail = pathTail.drop(while: { accessGrid.point(at: $0).y > lineStart.y })
                }
            } else {
                // horizontal
                if path0.x < path1.x {
                    // going right, will cross with right edge of box
                    lineStart = CGPoint(x: source.frame.maxX, y: pp0.y)
                    pathTail = pathTail.drop(while: { accessGrid.point(at: $0).x < lineStart.x })
                } else {
                    // going left, will cross with left edge of box
                    lineStart = CGPoint(x: source.frame.minX, y: pp0.y)
                    pathTail = pathTail.drop(while: { accessGrid.point(at: $0).x > lineStart.x })
                }
            }

            // target end of line
            guard let pathR0 = pathTail.last, let pathR1 = pathTail.dropLast().last else { continue }
            let pR0p = accessGrid.point(at: pathR0)
            let lineEnd: CGPoint
            if pathR0.x == pathR1.x {
                // vertical
                if pathR1.y < pathR0.y {
                    // second to last is above last, line goes down, will cross top of box
                    lineEnd = CGPoint(x: pR0p.x, y: target.frame.minY)
                    let lastAbove = pathTail.lastIndex(where: { accessGrid.point(at: $0).y < lineEnd.y }) ?? 0
                    pathTail = pathTail.prefix(upTo: lastAbove + 1)
                } else {
                    // second to last below last, line goes up, will cross bottom of box
                    lineEnd = CGPoint(x: pR0p.x, y: target.frame.maxY)
                    let lastBelow = pathTail.lastIndex(where: { accessGrid.point(at: $0).y > lineEnd.y }) ?? 0
                    pathTail = pathTail.prefix(upTo: lastBelow + 1)
                }
            } else {
                // horizontal
                if pathR1.x < pathR0.x {
                    // second to last left of last, line goes right, will cross left side of box
                    lineEnd = CGPoint(x: target.frame.minX, y: pR0p.y)
                    let lastLeft = pathTail.lastIndex(where: { accessGrid.point(at: $0).x < lineEnd.x }) ?? 0
                    pathTail = pathTail.prefix(upTo: lastLeft + 1)
                } else {
                    // second to last right of last, line goes left, will cross right side of box
                    lineEnd = CGPoint(x: target.frame.maxX, y: pR0p.y)
                    let lastRight = pathTail.lastIndex(where: { accessGrid.point(at: $0).x > lineEnd.x }) ?? 0
                    pathTail = pathTail.prefix(upTo: lastRight + 1)
                }
            }

            ctx.move(to: lineStart)
            for coordinate in pathTail {
                ctx.addLine(to: accessGrid.point(at: coordinate))
            }
            ctx.addLine(to: lineEnd)
            ctx.strokePath()
        }
    }
}

func draw(width: CGFloat, height: CGFloat, closure: @escaping (CGContext, CGRect) -> Void) -> NSImage {
    NSImage(size: NSSize(width: width, height: height), flipped: true) { rect in
        let graphicsContext = NSGraphicsContext.current!
        let context = graphicsContext.cgContext
        context.setStrokeColor(.black)

        closure(context, rect)
        return true
    }
}


struct Access {
    var right: Bool
    var down: Bool
    var visited: Bool = false
    var distance: Int = .max
}

enum AccessDirection {
    case up
    case right
    case down
    case left
}

final class ConnectionPointRegister {
    var usedCoordinates: Set<AccessGrid.Coordinate> = []

    func pick(from coordinates: [AccessGrid.Coordinate]) -> AccessGrid.Coordinate? {
        for coordinate in coordinates {
            if !self.usedCoordinates.contains(coordinate) {
                self.usedCoordinates.insert(coordinate)
                return coordinate
            }
        }
        return coordinates.first
    }
}

struct AccessGrid {
    struct Coordinate: Hashable {
        var x: Int
        var y: Int
    }

    // rows of access elements: (x0, y0), (x1, y0) … (x0, y1), (x1, y1) …
    private(set) var cells: [Access]
    let width: Int
    let height: Int
    let cellSide: Int

    subscript(coord: Coordinate) -> Access {
        get {
            self.cells[self.index(for: coord)]
        }
        set {
            self.cells[self.index(for: coord)] = newValue
        }
        _modify {
            yield &self.cells[self.index(for: coord)]
        }
    }

    @inlinable
    func index(for coordinate: Coordinate) -> Int {
        coordinate.y * self.width + coordinate.x
    }

    mutating func zeroDistance(at coordinate: Coordinate) {
        var cell = self[coordinate]
        cell.distance = 0
        self[coordinate] = cell
    }

    func coordinate(in rect: CGRect) -> [Coordinate] {
        let cellSide = CGFloat(self.cellSide)
        let top = Int(ceil(rect.minY / cellSide))
        let left = Int(ceil(rect.minX / cellSide))

        let rectHorizontalCellCount = rect.size.width / cellSide
        let rectVerticalCellCount = rect.size.height / cellSide

        let coords = (0 ..< Int(floor(rectHorizontalCellCount))).flatMap { hcell in
            (0 ..< Int(floor(rectVerticalCellCount))).map { vcell in
                Coordinate(
                    x: left + hcell,
                    y: top + vcell //Int(floor(rectVerticalCellCount / 2.0))
                )
            }
        }
        return coords
    }

    func point(at coordinate: Coordinate) -> CGPoint {
        let cellSide = CGFloat(self.cellSide)
        let top = CGFloat(coordinate.y) * cellSide
        let left = CGFloat(coordinate.x) * cellSide
        return CGPoint(
            x: left + cellSide / 2.0,
            y: top + cellSide / 2.0
        )
    }

    func canGo(from source: Coordinate, to direction: AccessDirection) -> Bool {
        switch direction {
        case .up:
            if source.y == 0 { return false }
            return canGo(from: Coordinate(x: source.x, y: source.y - 1), to: .down)
        case .left:
            if source.x == 0 { return false }
            return canGo(from: Coordinate(x: source.x - 1, y: source.y), to: .right)
        case .down:
            if source.y >= self.height - 1 { return false }
            return self[source].down
        case .right:
            if source.x >= self.width - 1 { return false }
            return self[source].right
        }
    }

    func neighbors(of coordinate: Coordinate) -> [Coordinate] {
        [AccessDirection.left, .right, .up, .down].filter { direction in
            self.canGo(from: coordinate, to: direction)
        }
        .map(coordinate.neighbor(in:))
    }

    func connectionPointCandidates(
        from source: CGRect,
        to target: CGRect
    ) -> (source: [Coordinate], target: [Coordinate]) {
        var allSourceCoordinates = self.coordinate(in: source)
        var allTargetCoordinates = self.coordinate(in: target)

        // now narrow the sets.
        // if the rects overlap, just return something, doesn't matter what.
        // if they don't overlap, then all of target is on some side of source,
        // allowing us to cut down each coordinate set to just a line.

        guard !source.intersects(target) else {
            return (source: allSourceCoordinates, target: allTargetCoordinates)
        }

        if target.minX > source.maxX {
            // [source]  [target]
            let sourceCoordsMaxX = allSourceCoordinates.map(\.x).max()!
            let targetCoordsMinX = allTargetCoordinates.map(\.x).min()!

            allSourceCoordinates = allSourceCoordinates.filter { $0.x == sourceCoordsMaxX }
            allTargetCoordinates = allTargetCoordinates.filter { $0.x == targetCoordsMinX }
        }

        if target.maxX < source.minX {
            // [target]  [source]
            let sourceCoordsMinX = allSourceCoordinates.map(\.x).min()!
            let targetCoordsMaxX = allTargetCoordinates.map(\.x).max()!

            allSourceCoordinates = allSourceCoordinates.filter { $0.x == sourceCoordsMinX }
            allTargetCoordinates = allTargetCoordinates.filter { $0.x == targetCoordsMaxX }
        }

        if target.minY > source.maxY {
            // [source]
            // [target]
            let sourceCoordsMaxY = allSourceCoordinates.map(\.y).max()!
            let targetCoordsMinY = allTargetCoordinates.map(\.y).min()!

            allSourceCoordinates = allSourceCoordinates.filter { $0.y == sourceCoordsMaxY }
            allTargetCoordinates = allTargetCoordinates.filter { $0.y == targetCoordsMinY }
        }

        if target.maxY < source.minY {
            // [target]
            // [source]
            let sourceCoordsMinY = allSourceCoordinates.map(\.y).min()!
            let targetCoordsMaxY = allTargetCoordinates.map(\.y).max()!

            allSourceCoordinates = allSourceCoordinates.filter { $0.y == sourceCoordsMinY }
            allTargetCoordinates = allTargetCoordinates.filter { $0.y == targetCoordsMaxY }
        }

        return (source: allSourceCoordinates, target: allTargetCoordinates)
    }

    mutating func path(
        from source: CGRect,
        to target: CGRect,
        connectionPointRegister: ConnectionPointRegister
    ) -> [Coordinate]? {
        let (scpc, tcpc) = self.connectionPointCandidates(from: source, to: target)
        let sc = connectionPointRegister.pick(from: scpc)!
        let tc = connectionPointRegister.pick(from: tcpc)!

//        let sc = self.coordinate(in: source).first!
//        let tc = self.coordinate(in: target).first!

        self.zeroDistance(at: sc)
        let coordinates = (0 ..< self.width).flatMap { x in
            (0 ..< self.height).map { y in Coordinate(x: x, y: y) }
        }
        var prev = [Coordinate: Coordinate]()
        while case let available = coordinates.filter({ !self[$0].visited }), let firstAvailable = available.first {
            let smallestDistance = available.dropFirst().reduce((firstAvailable, self[firstAvailable])) { smallestDistance, coordinate in
                let coordinateAccess = self[coordinate]
                if coordinateAccess.distance < smallestDistance.1.distance {
                    return (coordinate, coordinateAccess)
                }
                return smallestDistance
            }
            if smallestDistance.0 == tc {
                break
            }
            self[smallestDistance.0].visited = true
            for neighbor in self.neighbors(of: smallestDistance.0) where !self[neighbor].visited {
                let alt = smallestDistance.1.distance + 1
                if alt < self[neighbor].distance {
                    self[neighbor].distance = alt
                    prev[neighbor] = smallestDistance.0
                }
            }
        }

        var path = [Coordinate]()
        if prev[tc] != nil || tc == sc {
            var u = Optional.some(tc)
            while let su = u {
                path.append(su)
                u = prev[su]
            }
        }

        return path.reversed()
    }
}

extension AccessGrid.Coordinate {
    func neighbor(in direction: AccessDirection) -> Self {
        var coordinate = self
        switch direction {
        case .up: coordinate.y -= 1
        case .right: coordinate.x += 1
        case .down: coordinate.y += 1
        case .left: coordinate.x -= 1
        }
        return coordinate
    }
}

extension AccessGrid {
    init(graph: Graph, sourceBox: Box, targetBox: Box, cellSize: Int) {
        let graphFrame = graph.frame
        let gridWidth = Int(ceil(graph.frame.width / CGFloat(cellSize)))
        let gridHeight = Int(ceil(graph.frame.height / CGFloat(cellSize)))
        var cells = [Access](repeating: Access(right: false, down: false), count: gridHeight * gridWidth)

        func rectIntersectsBox(_ rect: CGRect) -> Bool {
            for (boxID, box) in graph.boxes {
                if boxID == sourceBox.id || boxID == targetBox.id { continue }
                if box.frame.intersects(rect) { return true }
            }
            return false
        }

        for y in stride(from: Int(floor(graphFrame.minY)), to: Int(ceil(graphFrame.maxY)), by: cellSize) {
            for x in stride(from: Int(floor(graphFrame.minX)), to: Int(ceil(graphFrame.maxX)), by: cellSize) {
                let gridX = x / cellSize
                let gridY = y / cellSize
                let index = gridY * gridWidth + gridX
                let cellRect = CGRect(origin: .init(x: x, y: y), size: .init(width: cellSize, height: cellSize))
                var canGoRight = false
                if gridX < gridWidth - 1 {
                    var next = cellRect
                    next.origin.x += CGFloat(cellSize)
                    if !rectIntersectsBox(cellRect) && !rectIntersectsBox(next) {
                        canGoRight = true
                    }
                }
                var canGoDown = false
                if gridY < gridHeight - 1 {
                    var next = cellRect
                    next.origin.y += CGFloat(cellSize)
                    if !rectIntersectsBox(cellRect) && !rectIntersectsBox(next) {
                        canGoDown = true
                    }
                }

                cells[index] = Access(right: canGoRight, down: canGoDown)
            }
        }

        self.init(cells: cells, width: gridWidth, height: gridHeight, cellSide: cellSize)
    }
}
