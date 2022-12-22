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
                    y: top + vcell
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

    /// Calculate path from `source` to `target` avoiding other boxes.
    ///
    /// Uses Dijkstra to to calculate the route.
    mutating func path(
        from source: CGRect,
        to target: CGRect,
        connectionPointRegister: ConnectionPointRegister
    ) -> [Coordinate]? {
        let (scpc, tcpc) = self.connectionPointCandidates(from: source, to: target)
        let sc = connectionPointRegister.pick(from: scpc)!
        let tc = connectionPointRegister.pick(from: tcpc)!

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
                let alt = (smallestDistance.1.distance == .max ? 0 : smallestDistance.1.distance) + 1
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
        var visited: Bool = false
        var distance: Int = .max
    }

    enum AccessDirection {
        case up
        case right
        case down
        case left
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
    init(graph: Graph, sourceBox: Box, targetBox: Box, cellSize: Int) {
        let graphFrame = graph.frame
        let gridWidth = Int(ceil(graph.frame.width / CGFloat(cellSize)))
        let gridHeight = Int(ceil(graph.frame.height / CGFloat(cellSize)))
        var cells = [Access](
            repeating: Access(up: false, right: false, down: false, left: false), count: gridHeight * gridWidth
        )

        func rectIntersectsBox(_ rect: CGRect) -> Bool {
            for (boxID, box) in graph.boxes {
                if boxID == targetBox.id { continue }
                if (boxID == sourceBox.id || boxID == targetBox.id) && box.frame.intersects(rect) {
                    return true
                }
                if box.frame.insetBy(dx: -1, dy: -1).intersects(rect) {
                    return true
                }
            }
            return false
        }

        func rectInsideBox(_ rect: CGRect) -> Bool {
            for (boxID, box) in graph.boxes {
                if boxID == targetBox.id { continue }
                if (boxID == sourceBox.id || boxID == targetBox.id) && box.frame.contains(rect) {
                    return true
                }
                if box.frame.insetBy(dx: -1, dy: -1).contains(rect) {
                    return true
                }
            }
            return false
        }

        let yStart = Int(floor(graphFrame.minY))
        let xStart = Int(floor(graphFrame.minX))

        for y in stride(from: yStart, to: Int(ceil(graphFrame.maxY)), by: cellSize) {
            for x in stride(from: xStart, to: Int(ceil(graphFrame.maxX)), by: cellSize) {
                let gridX = x / cellSize
                let gridY = y / cellSize
                let cellRect = CGRect(origin: .init(x: x, y: y), size: .init(width: cellSize, height: cellSize))
                let index = gridY * gridWidth + gridX
                let thisInsideBox = rectInsideBox(cellRect)

                if gridY <= yStart {
                    cells[index].up = false
                } else {
                    var neighbor = cellRect
                    neighbor.origin.y -= CGFloat(cellSize)
                    cells[index].up = (thisInsideBox && !rectInsideBox(neighbor)) || !rectIntersectsBox(neighbor)
                }

                if gridX >= gridWidth - 1 {
                    cells[index].right = false
                } else {
                    var neighbor = cellRect
                    neighbor.origin.x += CGFloat(cellSize)
                    cells[index].right = (thisInsideBox && !rectInsideBox(neighbor)) || !rectIntersectsBox(neighbor)
                }

                if gridY >= gridHeight - 1 {
                    cells[index].down = false
                } else {
                    var neighbor = cellRect
                    neighbor.origin.y += CGFloat(cellSize)
                    cells[index].down = (thisInsideBox && !rectInsideBox(neighbor)) || !rectIntersectsBox(neighbor)
                }

                if gridX <= xStart {
                    cells[index].left = false
                } else {
                    var neighbor = cellRect
                    neighbor.origin.x -= CGFloat(cellSize)
                    cells[index].left = (thisInsideBox && !rectInsideBox(neighbor)) || !rectIntersectsBox(neighbor)
                }
            }
        }

        self.init(cells: cells, width: gridWidth, height: gridHeight, cellSide: cellSize)
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
