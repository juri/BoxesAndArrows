@testable import Parser
import XCTest

final class StringParseTests: XCTestCase {
    func testFailOnEmpty() throws {
        XCTAssertThrowsError(try quoted.parse(""))
    }

    func testFailOnSingleQuote() throws {
        XCTAssertThrowsError(try quoted.parse("\""))
    }

    func testFailOnUnterminatedQuote() throws {
        XCTAssertThrowsError(try quoted.parse("\"hello"))
    }

    func testSucceedOnEmptyString() throws {
        let output = try quoted.parse("""
        ""
        """)
        XCTAssertEqual(output, "")
    }

    func testSucceedOnNonEmptyString() throws {
        let output = try quoted.parse("""
        "asdf"
        """)
        XCTAssertEqual(output, "asdf")
    }

    func testSucceedWithEscapedQuote() throws {
        let input = """
        "\\""
        """
        print("input", input)
        let output = try quoted.parse(input)
        XCTAssertEqual(output, "\"")
    }

    func testSucceedWithLeadingEscapedQuote() throws {
        let input = """
        "\\"asdf"
        """
        print("input", input)
        let output = try quoted.parse(input)
        XCTAssertEqual(output, "\"asdf")
    }

    func testSucceedWithTrailingEscapedQuote() throws {
        let input = """
        "asdf\\""
        """
        print("input", input)
        let output = try quoted.parse(input)
        XCTAssertEqual(output, "asdf\"")
    }

    func testSucceedWithTrailingMiddleEscapedQuote() throws {
        let input = """
        "qwer\\"asdf"
        """
        print("input", input)
        let output = try quoted.parse(input)
        XCTAssertEqual(output, "qwer\"asdf")
    }
}
