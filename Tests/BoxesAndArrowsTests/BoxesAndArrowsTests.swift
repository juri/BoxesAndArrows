@testable import BoxesAndArrows
import Cassowary
import DrawCocoa
import XCTest

final class BoxesAndArrowsTests: XCTestCase {
    func test() throws {
        var graph = Graph()
        let foo = Box(label: "foofoo")
        let bar = Box(label: "bar")
        let zap = Box(label: "zap")
        graph.add(box: foo)
        graph.add(box: bar)
        graph.add(box: zap)
        graph.connect(foo, to: zap, targetHead: .filledVee)
        graph.connect(bar, to: zap, targetHead: .filledVee)

        let graphics = GraphicsCocoa()

        let solver = try graph.makeSolver(graphics: graphics)
        try solver.add(constraint: bar.top.variable == foo.bottom.variable + 20.0)
        try solver.add(constraint: bar.left.variable == foo.left.variable)
        try solver.add(constraint: zap.left.variable == foo.right.variable + 20.0)
        try solver.add(constraint: zap.top.variable == foo.bottom.variable)

        solver.update()

        print("graph:")
        print("top    ", graph.top.variable.value)
        print("centerY", graph.centerY.variable.value)
        print("bottom ", graph.bottom.variable.value)

        print("left   ", graph.left.variable.value)
        print("centerX", graph.centerX.variable.value)
        print("right  ", graph.right.variable.value)

        print("width  ", graph.width.variable.value)
        print("height ", graph.height.variable.value)

        for box in [foo, bar, zap] {
            print("------------------- \(box.label)")
            print("top    ", box.top.variable.value)
            print("centerY", box.centerY.variable.value)
            print("bottom ", box.bottom.variable.value)

            print("left   ", box.left.variable.value)
            print("centerX", box.centerX.variable.value)
            print("right  ", box.right.variable.value)

            print("width  ", box.width.variable.value)
            print("height ", box.height.variable.value)
        }

        let image = draw(graph: graph, graphics: graphics)
        print("got image:", image)
        print()
    }

    func testTwoLeftToRight() throws {
        var graph = Graph()
        let left = Box(label: "left")
        let center = Box(label: "center")
        let right = Box(label: "right")
        graph.add(box: left)
        graph.add(box: center)
        graph.add(box: right)
        graph.connect(left, to: right, targetHead: .filledVee)

        let graphics = GraphicsCocoa()

        let solver = try graph.makeSolver(graphics: graphics)
        try solver.add(constraint: left.top.variable == right.top.variable)
        try solver.add(constraint: left.top.variable == center.top.variable)
        try solver.add(constraint: left.right.variable + 30.0 == center.left.variable)
        try solver.add(constraint: center.right.variable + 30.0 == right.left.variable)

        solver.update()

        let image = draw(graph: graph, graphics: graphics)
        print("got image:", image)
        print()
    }

    func testTwoRightToLeft() throws {
        var graph = Graph()
        let left = Box(label: "left")
        let center = Box(label: "center")
        let right = Box(label: "right")
        graph.add(box: left)
        graph.add(box: center)
        graph.add(box: right)
        graph.connect(right, to: left, targetHead: .filledVee)

        let graphics = GraphicsCocoa()
        let solver = try graph.makeSolver(graphics: graphics)
        try solver.add(constraint: left.top.variable == right.top.variable)
        try solver.add(constraint: left.top.variable == center.top.variable)
        try solver.add(constraint: left.right.variable + 30.0 == center.left.variable)
        try solver.add(constraint: center.right.variable + 30.0 == right.left.variable)

        solver.update()

        let image = draw(graph: graph, graphics: graphics)
        print("got image:", image)
        print()
    }

    func testUpToDown() throws {
        var graph = Graph()
        let up = Box(label: "up")
        let center = Box(label: "center")
        let down = Box(label: "down")
        graph.add(box: up)
        graph.add(box: center)
        graph.add(box: down)
        graph.connect(up, to: down, targetHead: .filledVee)

        let graphics = GraphicsCocoa()
        let solver = try graph.makeSolver(graphics: graphics)
        try solver.add(constraint: up.left.variable == down.left.variable)
        try solver.add(constraint: up.left.variable == center.left.variable)
        try solver.add(constraint: up.bottom.variable + 30.0 == center.top.variable)
        try solver.add(constraint: center.bottom.variable + 30.0 == down.top.variable)

        solver.update()

        let image = draw(graph: graph, graphics: graphics)
        print("got image:", image)
        print()
    }

    func testDownToUp() throws {
        var graph = Graph()
        let up = Box(label: "up")
        let center = Box(label: "center")
        let down = Box(label: "down")
        graph.add(box: up)
        graph.add(box: center)
        graph.add(box: down)
        graph.connect(down, to: up, targetHead: .filledVee)

        let graphics = GraphicsCocoa()
        let solver = try graph.makeSolver(graphics: graphics)
        try solver.add(constraint: up.left.variable == down.left.variable)
        try solver.add(constraint: up.left.variable == center.left.variable)
        try solver.add(constraint: up.bottom.variable + 30.0 == center.top.variable)
        try solver.add(constraint: center.bottom.variable + 30.0 == down.top.variable)

        solver.update()

        let image = draw(graph: graph, graphics: graphics)
        print("got image:", image)
        print()
    }
}
