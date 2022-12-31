import Draw
@testable import Parser
import XCTest

final class KeyValueTests: XCTestCase {
    func test() throws {
        let input = """
        {}
        """
        let output = try blockParser.parse(input)
        XCTAssertEqual(output, [])
    }

    func testBlockField() throws {
        let input = "background-color: #aabbccdd"
        let output = try blockFieldParser.parse(input)
        XCTAssertEqual(
            output,
            BlockField.color(ColorField(fieldID: .backgroundColor, value: Color(hex: 0xAA_BB_CC_DD)))
        )
    }

    func testOneField() throws {
        let input = """
        {
            background-color: #aabbccdd
        }
        """
        let output = try blockParser.parse(input)
        XCTAssertEqual(
            output,
            [
                BlockField.color(ColorField(fieldID: .backgroundColor, value: Color(hex: 0xAA_BB_CC_DD))),
            ]
        )
    }

    func testMultipleFields() throws {
        let inputs: [Subcase<String>] = [
            Subcase(
                """
                { background-color: #aabbccdd; text-color: #11223344; line-width: 3.1; label: "zap"; }
                """,
                description: "One line, terminated last item"
            ),
            Subcase(
                """
                { background-color: #aabbccdd; text-color: #11223344; line-width: 3.1; label: "zap" }
                """,
                description: "One line, unterminated last item"
            ),
            Subcase(
                """
                {
                    background-color: #aabbccdd; text-color: #11223344; line-width: 3.1; label: "zap";
                }
                """,
                description: "One separate line, terminated last item"
            ),
            Subcase(
                """
                {
                    background-color: #aabbccdd; text-color: #11223344; line-width: 3.1; label: "zap"
                }
                """,
                description: "One separate line, unterminated last item"
            ),
            Subcase(
                """
                {
                    background-color: #aabbccdd;
                    text-color: #11223344;
                    line-width: 3.1;
                    label: "zap";
                }
                """,
                description: "Separate terminated lines"
            ),
            Subcase(
                """
                {
                    background-color: #aabbccdd
                    text-color: #11223344
                    line-width: 3.1
                    label: "zap"
                }
                """,
                description: "Separate unterminated lines"
            ),
            Subcase(
                """
                {
                    background-color: #aabbccdd
                    text-color: #11223344; line-width: 3.1;
                    label: "zap";
                }
                """,
                description: "Mixed lines"
            ),
        ]
        for input in inputs {
            let output = try blockParser.parse(input.value)
            XCTAssertEqual(
                output,
                [
                    .color(ColorField(fieldID: .backgroundColor, value: Color(hex: 0xAA_BB_CC_DD))),
                    .color(ColorField(fieldID: .textColor, value: Color(hex: 0x11_22_33_44))),
                    .numeric(NumericField(fieldID: .lineWidth, value: 3.1)),
                    .string(StringField(fieldID: .label, value: "zap")),
                ],
                "Failing case: \(input.description ?? "(no description)")",
                file: input.file,
                line: input.line
            )
        }
    }
}
