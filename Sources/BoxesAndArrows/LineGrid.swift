import Draw
import Foundation

/// `ConnectionPointRegister` tracks box connection point usage.
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

/// `AccessGrid` builds a grid of cells from the drawing area for drawing lines
/// that don't pass through boxes.
struct AccessGrid {
    // rows of access elements: (x0, y0), (x1, y0) … (x0, y1), (x1, y1) …
    let cells: [Access]
    let width: Int
    let height: Int
    let cellSide: Int
    let sourceBox: Box
    let targetBox: Box

    subscript(coord: Coordinate) -> Access {
        self.cells[self.index(for: coord)]
    }

    @inlinable
    func index(for coordinate: Coordinate) -> Int {
        coordinate.y * self.width + coordinate.x
    }

    func coordinate(in rect: Rectangle) -> [Coordinate] {
        let cellSide = Double(self.cellSide)
        let top = Int(ceil(rect.minY / cellSide))
        let left = Int(ceil(rect.minX / cellSide))

        let rectHorizontalCellCount = rect.size.width / cellSide
        let rectVerticalCellCount = rect.size.height / cellSide

        let coords = (0 ..< Int(floor(rectHorizontalCellCount))).flatMap { hcell in
            (0 ..< Int(floor(rectVerticalCellCount))).map { vcell in
                Coordinate(
                    x: left + hcell,
                    y: top + vcell
                )
            }
        }
        return coords
    }

    func point(at coordinate: Coordinate) -> Point {
        let cellSide = Double(self.cellSide)
        let top = Double(coordinate.y) * cellSide
        let left = Double(coordinate.x) * cellSide
        return Point(
            x: left + cellSide / 2.0,
            y: top + cellSide / 2.0
        )
    }

    func canGo(from source: Coordinate, to direction: AccessDirection) -> Bool {
        switch direction {
        case .up:
            return self[source].up
        case .left:
            return self[source].left
        case .down:
            return self[source].down
        case .right:
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
        from source: Rectangle,
        to target: Rectangle
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

    /// Calculate path from `source` to `target` avoiding other boxes.
    ///
    /// Uses Dijkstra to to calculate the route.
    func path(
        connectionPointRegister: ConnectionPointRegister
    ) -> [Coordinate] {
        let (scpc, tcpc) = self.connectionPointCandidates(from: self.sourceBox.frame, to: self.targetBox.frame)
        let sc = connectionPointRegister.pick(from: scpc)!
        let tc = connectionPointRegister.pick(from: tcpc)!

        var statuses: [Coordinate: CoordinateStatus] = [:]
        func status(at coordinate: Coordinate) -> CoordinateStatus {
            statuses[coordinate, default: CoordinateStatus()]
        }

        statuses[sc, default: CoordinateStatus()].distance = 0

        let coordinates = (0 ..< self.width).flatMap { x in
            (0 ..< self.height).map { y in Coordinate(x: x, y: y) }
        }
        var prev = [Coordinate: Coordinate]()
        while case let available = coordinates.filter({ !status(at: $0).visited }), let firstAvailable = available.first {
            let (closestCoordinate, closestAccess) = available
                .dropFirst()
                .reduce((firstAvailable, status(at: firstAvailable))) { smallestDistance, coordinate in
                    let coordinateStatus = status(at: coordinate)
                    if coordinateStatus.distance < smallestDistance.1.distance {
                        return (coordinate, coordinateStatus)
                    }
                    return smallestDistance
                }
            if closestCoordinate == tc {
                break
            }
            statuses[closestCoordinate, default: CoordinateStatus()].visited = true
            for neighbor in self.neighbors(of: closestCoordinate) where !status(at: neighbor).visited {
                let alt = (closestAccess.distance == .max ? 0 : closestAccess.distance) + 1
                if alt < status(at: neighbor).distance {
                    statuses[neighbor, default: CoordinateStatus()].distance = alt
                    prev[neighbor] = closestCoordinate
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

extension AccessGrid {
    struct Coordinate: Hashable {
        var x: Int
        var y: Int
    }

    struct Access {
        var up: Bool
        var right: Bool
        var down: Bool
        var left: Bool
    }

    enum AccessDirection {
        case up
        case right
        case down
        case left
    }

    struct CoordinateStatus {
        var visited: Bool = false
        var distance: Int = .max
    }
}

extension AccessGrid.Coordinate {
    func neighbor(in direction: AccessGrid.AccessDirection) -> Self {
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
    init(
        graph: Graph,
        sourceBox: Box,
        targetBox: Box,
        cellSize: Int,
        rectMargin: Double
    ) {
        let graphFrame = graph.frame
        let gridWidth = Int(ceil(graph.frame.width / Double(cellSize)))
        let gridHeight = Int(ceil(graph.frame.height / Double(cellSize)))
        var cells = [Access](
            repeating: Access(up: false, right: false, down: false, left: false), count: gridHeight * gridWidth
        )

        func rectIntersectsBox(_ rect: Rectangle) -> Bool {
            for (boxID, box) in graph.boxes {
                if boxID == targetBox.id { continue }
                if (boxID == sourceBox.id || boxID == targetBox.id) && box.frame.intersects(rect) {
                    return true
                }
                if box.frame.insetBy(-rectMargin).intersects(rect) {
                    return true
                }
            }
            return false
        }

        func rectInsideBox(_ rect: Rectangle) -> Bool {
            containingBox(rect) != nil
        }

        func containingBox(_ rect: Rectangle) -> Box? {
            for (boxID, box) in graph.boxes {
                if boxID == targetBox.id { continue }
                if (boxID == sourceBox.id || boxID == targetBox.id) && box.frame.contains(rect) {
                    return box
                }
                if box.frame.insetBy(-rectMargin).contains(rect) {
                    return box
                }
            }
            return nil
        }

        let yStart = Int(floor(graphFrame.minY))
        let xStart = Int(floor(graphFrame.minX))

        for y in stride(from: yStart, to: Int(ceil(graphFrame.maxY)), by: cellSize) {
            for x in stride(from: xStart, to: Int(ceil(graphFrame.maxX)), by: cellSize) {
                let gridX = x / cellSize
                let gridY = y / cellSize
                let cellRect = Rectangle(origin: .init(x: x, y: y), size: .init(width: cellSize, height: cellSize))
                let cellCenter = Point(
                    x: cellRect.origin.x + cellRect.size.width / 2.0,
                    y: cellRect.origin.y + cellRect.size.height / 2.0
                )
                let index = gridY * gridWidth + gridX
                let boxContainingCell = containingBox(cellRect)
                let outsideDirection = boxContainingCell.map { box in
                    let upDistance = (AccessDirection.up, cellCenter.y - box.frame.minY, box.frame.maxX - box.frame.minX)
                    let downDistance = (AccessDirection.down, box.frame.maxY - cellCenter.y, box.frame.maxX - box.frame.minX)
                    let leftDistance = (AccessDirection.left, cellCenter.x - box.frame.minX, box.frame.maxY - box.frame.minY)
                    let rightDistance = (AccessDirection.right, box.frame.maxX - cellCenter.x, box.frame.maxY - box.frame.minY)
                    let directions = [upDistance, downDistance, leftDistance, rightDistance]
                        .sorted(by: {
                            guard $0.1 == $1.1 else { return $0.1 < $1.1 }
                            return $0.2 > $1.2
                        })
                    return [directions[0].0, directions[1].0]
                } ?? [AccessDirection]()
                let thisInsideBox = rectInsideBox(cellRect)

                if gridY <= yStart {
                    cells[index].up = false
                } else if outsideDirection.contains(.up) {
                    cells[index].up = true
                } else {
                    var neighbor = cellRect
                    neighbor.origin.y -= Double(cellSize)
                    cells[index].up = (thisInsideBox && !rectInsideBox(neighbor)) || !rectIntersectsBox(neighbor)
                }

                if gridX >= gridWidth - 1 {
                    cells[index].right = false
                } else if outsideDirection.contains(.right) {
                    cells[index].right = true
                } else {
                    var neighbor = cellRect
                    neighbor.origin.x += Double(cellSize)
                    cells[index].right = (thisInsideBox && !rectInsideBox(neighbor)) || !rectIntersectsBox(neighbor)
                }

                if gridY >= gridHeight - 1 {
                    cells[index].down = false
                } else if outsideDirection.contains(.down) {
                    cells[index].down = true
                } else {
                    var neighbor = cellRect
                    neighbor.origin.y += Double(cellSize)
                    cells[index].down = (thisInsideBox && !rectInsideBox(neighbor)) || !rectIntersectsBox(neighbor)
                }

                if gridX <= xStart {
                    cells[index].left = false
                } else if outsideDirection.contains(.left) {
                    cells[index].left = true
                } else {
                    var neighbor = cellRect
                    neighbor.origin.x -= Double(cellSize)
                    cells[index].left = (thisInsideBox && !rectInsideBox(neighbor)) || !rectIntersectsBox(neighbor)
                }
            }
        }

        self.init(
            cells: cells,
            width: gridWidth,
            height: gridHeight,
            cellSide: cellSize,
            sourceBox: sourceBox,
            targetBox: targetBox
        )
    }
}

extension AccessGrid {
    func picture() -> String {
        var output = [String]()
        let space = " "
        let dimensionWidth = max(String(self.width).count, String(self.height).count)
        let width = dimensionWidth + 2
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        formatter.formatWidth = dimensionWidth
        for y in 0 ..< self.height {
            var line = ""
            for x in 0 ..< self.width {
                let cell = self[Coordinate(x: x, y: y)]

                line.append("┌")
                if cell.up {
                    line.append(String(repeating: "┄", count: width))
                } else {
                    line.append(String(repeating: "━", count: width))
                }
                line.append("┐")
            }
            line.append("\n")
            for x in 0 ..< self.width {
                let cell = self[Coordinate(x: x, y: y)]
                if cell.left {
                    line.append("┆")
                } else {
                    line.append("┃")
                }

                line.append(space)
                line.append(formatter.string(for: x)!)
                line.append(space)

                if cell.right {
                    line.append("┆")
                } else {
                    line.append("┃")
                }
            }
            line.append("\n")
            for x in 0 ..< self.width {
                let cell = self[Coordinate(x: x, y: y)]
                if cell.left {
                    line.append("┆")
                } else {
                    line.append("┃")
                }

                line.append(space)
                line.append(formatter.string(for: y)!)
                line.append(space)

                if cell.right {
                    line.append("┆")
                } else {
                    line.append("┃")
                }
            }
            line.append("\n")

            for x in 0 ..< self.width {
                let cell = self[Coordinate(x: x, y: y)]

                line.append("└")
                if cell.down {
                    line.append(String(repeating: "┄", count: width))
                } else {
                    line.append(String(repeating: "━", count: width))
                }
                line.append("┘")
            }
            line.append("\n")
            output.append(line)
        }
        return output.joined()
    }
}
