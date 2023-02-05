import CustomDump
@testable import Parser
import XCTest

final class EquationTests: XCTestCase {
    func testEmptyVariable() throws {
        XCTAssertThrowsError(try Equation.Variable.parser.parse(""))
    }

    func testSpaceVariable() throws {
        XCTAssertThrowsError(try Equation.Variable.parser.parse(" "))
    }

    func testPeriodVariable() throws {
        XCTAssertThrowsError(try Equation.Variable.parser.parse("."))
    }

    func testLeadingPeriod() throws {
        XCTAssertThrowsError(try Equation.Variable.parser.parse(".b.c"))
    }

    func testTrailingPeriod() throws {
        XCTAssertThrowsError(try Equation.Variable.parser.parse("a.b.c."))
    }

    func testSinglePartVariable() throws {
        let variable = try Equation.Variable.parser.parse("a")
        XCTAssertEqual(variable, .init(head: "a", tail: []))
    }

    func testTwoPartVariable() throws {
        let variable = try Equation.Variable.parser.parse("a.b")
        XCTAssertEqual(variable, .init(head: "a", tail: ["b"]))
    }

    func testThreePartVariable() throws {
        let variable = try Equation.Variable.parser.parse("a.b.c")
        XCTAssertEqual(variable, .init(head: "a", tail: ["b", "c"]))
    }

    func testEquation() throws {
        let parts = try EquationPart.manyParser.parse("1.2 + box1.left == box2.right - 40 // comment")
        XCTAssertNoDifference(
            [
                .constant(1.2),
                .operation(.add),
                .variable(.init(head: "box1", tail: ["left"])),
                .relation(.eq),
                .variable(.init(head: "box2", tail: ["right"])),
                .operation(.sub),
                .constant(40.0),
                .lineComment(.init(text: " comment")),
            ],
            parts
        )
    }
}
