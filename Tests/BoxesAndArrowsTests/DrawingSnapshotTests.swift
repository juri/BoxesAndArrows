@testable import BoxesAndArrows
import Cassowary
import Draw
import DrawCocoa
import SnapshotTesting
import XCTest

final class DrawingSnapshotTests: XCTestCase {
    func testThreeBoxes() throws {
        var graph = Graph()
        let foo = Box(label: "foofoo")
        let bar = Box(label: "bar")
        let zap = Box(label: "zap")
        graph.add(box: foo)
        graph.add(box: bar)
        graph.add(box: zap)
        graph.connect(foo, to: zap, connectionProperties: .init(targetHead: .filledVee))
        graph.connect(bar, to: zap, connectionProperties: .init(targetHead: .filledVee))

        func _draw<T>(graphics: any Graphics<T>) throws -> T {
            let solver = try graph.makeSolver(graphics: graphics)
            try solver.add(constraint: bar.top.variable == foo.bottom.variable + 80.0)
            try solver.add(constraint: bar.left.variable == foo.left.variable)
            try solver.add(constraint: zap.left.variable == foo.right.variable + 80.0)
            try solver.add(constraint: zap.top.variable == foo.bottom.variable)

            solver.update()

            return draw(graph: graph, graphics: graphics)
        }

        let commands = try _draw(graphics: TestGraphics())
        let image = try _draw(graphics: GraphicsCocoa())

        assertSnapshot(matching: image, as: .image)
        assertSnapshot(matching: commands, as: .dump)
    }

    func testTwoLeftToRight() throws {
        var graph = Graph()
        let left = Box(label: "left")
        let center = Box(label: "center")
        let right = Box(label: "right")
        graph.add(box: left)
        graph.add(box: center)
        graph.add(box: right)
        graph.connect(left, to: right, connectionProperties: .init(targetHead: .filledVee))

        func _draw<T>(graphics: any Graphics<T>) throws -> T {
            let solver = try graph.makeSolver(graphics: graphics)
            try solver.add(constraint: left.top.variable == right.top.variable)
            try solver.add(constraint: left.top.variable == center.top.variable)
            try solver.add(constraint: left.right.variable + 40.0 == center.left.variable)
            try solver.add(constraint: center.right.variable + 40.0 == right.left.variable)

            solver.update()

            return draw(graph: graph, graphics: graphics)
        }

        let commands = try _draw(graphics: TestGraphics())
        let image = try _draw(graphics: GraphicsCocoa())

        assertSnapshot(matching: image, as: .image)
        assertSnapshot(matching: commands, as: .dump)
    }

    func testTwoRightToLeft() throws {
        var graph = Graph()
        let left = Box(label: "left")
        let center = Box(label: "center")
        let right = Box(label: "right")
        graph.add(box: left)
        graph.add(box: center)
        graph.add(box: right)
        graph.connect(right, to: left, connectionProperties: .init(targetHead: .filledVee))

        func _draw<T>(graphics: any Graphics<T>) throws -> T {
            let solver = try graph.makeSolver(graphics: graphics)
            try solver.add(constraint: left.top.variable == right.top.variable)
            try solver.add(constraint: left.top.variable == center.top.variable)
            try solver.add(constraint: left.right.variable + 40.0 == center.left.variable)
            try solver.add(constraint: center.right.variable + 40.0 == right.left.variable)

            solver.update()

            return draw(graph: graph, graphics: graphics)
        }

        let commands = try _draw(graphics: TestGraphics())
        let image = try _draw(graphics: GraphicsCocoa())

        assertSnapshot(matching: image, as: .image)
        assertSnapshot(matching: commands, as: .dump)
    }

    func testUpToDown() throws {
        var graph = Graph()
        let up = Box(label: "up")
        let center = Box(label: "center")
        let down = Box(label: "down")
        graph.add(box: up)
        graph.add(box: center)
        graph.add(box: down)
        graph.connect(up, to: down, connectionProperties: .init(targetHead: .filledVee))

        func _draw<T>(graphics: any Graphics<T>) throws -> T {
            let solver = try graph.makeSolver(graphics: graphics)
            try solver.add(constraint: up.left.variable == down.left.variable)
            try solver.add(constraint: up.left.variable == center.left.variable)
            try solver.add(constraint: up.bottom.variable + 40.0 == center.top.variable)
            try solver.add(constraint: center.bottom.variable + 40.0 == down.top.variable)

            solver.update()

            return draw(graph: graph, graphics: graphics)
        }

        let commands = try _draw(graphics: TestGraphics())
        let image = try _draw(graphics: GraphicsCocoa())

        assertSnapshot(matching: image, as: .image)
        assertSnapshot(matching: commands, as: .dump)
    }

    func testUpToDownMultiple() throws {
        var graph = Graph()
        let box1 = Box(label: "box1")
        let box2 = Box(label: "box2")
        let box3 = Box(label: "box3")
        let box4 = Box(label: "box4")
        let box5 = Box(label: "box5")
        graph.add(box: box1)
        graph.add(box: box2)
        graph.add(box: box3)
        graph.add(box: box4)
        graph.add(box: box5)
        graph.connect(box1, to: box4, connectionProperties: .init(targetHead: .filledVee))
        graph.connect(box2, to: box5, connectionProperties: .init(targetHead: .filledVee))

        func _draw<T>(graphics: any Graphics<T>) throws -> T {
            let solver = try graph.makeSolver(graphics: graphics)
            try solver.add(constraint: box1.left.variable == box2.left.variable)
            try solver.add(constraint: box1.left.variable == box3.left.variable)
            try solver.add(constraint: box1.left.variable == box4.left.variable)
            try solver.add(constraint: box1.left.variable == box5.left.variable)
            try solver.add(constraint: box1.bottom.variable + 40.0 == box2.top.variable)
            try solver.add(constraint: box2.bottom.variable + 40.0 == box3.top.variable)
            try solver.add(constraint: box3.bottom.variable + 40.0 == box4.top.variable)
            try solver.add(constraint: box4.bottom.variable + 40.0 == box5.top.variable)

            solver.update()

            return draw(graph: graph, graphics: graphics)
        }

        let commands = try _draw(graphics: TestGraphics())
        let image = try _draw(graphics: GraphicsCocoa())

        assertSnapshot(matching: image, as: .image)
        assertSnapshot(matching: commands, as: .dump)
    }

    func testDownToUp() throws {
        var graph = Graph()
        let boxStyle1 = BoxStyle(id: "style1", textColor: .blue)
        let boxStyle2 = BoxStyle(id: "style2", inherits: [boxStyle1.id], backgroundColor: .red)
        let up = Box(label: "up", style: boxStyle1.id)
        let center = Box(label: "center", style: boxStyle2.id)
        let down = Box(label: "down")
        graph.add(box: up)
        graph.add(box: center)
        graph.add(box: down)
        graph.connect(down, to: up, connectionProperties: .init(targetHead: .filledVee))

        graph.add(boxStyle: boxStyle1)
        graph.add(boxStyle: boxStyle2)

        func _draw<T>(graphics: any Graphics<T>) throws -> T {
            let solver = try graph.makeSolver(graphics: graphics)
            try solver.add(constraint: up.left.variable == down.left.variable)
            try solver.add(constraint: up.left.variable == center.left.variable)
            try solver.add(constraint: up.bottom.variable + 40.0 == center.top.variable)
            try solver.add(constraint: center.bottom.variable + 40.0 == down.top.variable)

            solver.update()

            return draw(graph: graph, graphics: graphics)
        }

        let commands = try _draw(graphics: TestGraphics())
        let image = try _draw(graphics: GraphicsCocoa())

        assertSnapshot(matching: image, as: .image)
        assertSnapshot(matching: commands, as: .dump)
    }

    func testDrawSpec() throws {
        let input = """
        box-style style1 { background-color: #FF90F4; text-color: black; }
        box-style style2 { background-color: #00BFC8; text-color: white; }

        box n1 { style: style1 }
        box n2 { style: style2 }

        connect n1 n2 { head1: filled_vee; head2: filled_vee; line-width: 4.0 }
        constrain n1.left == n2.right + 30.0
        constrain n1.top == n2.top
        """

        func _draw<T>(graphics: any Graphics<T>) throws -> T {
            try drawSpec(input, graphics: graphics)
        }

        let commands = try _draw(graphics: TestGraphics())
        let image = try _draw(graphics: GraphicsCocoa())

        assertSnapshot(matching: image, as: .image)
        assertSnapshot(matching: commands, as: .dump)
    }
}
