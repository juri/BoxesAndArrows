import CustomDump
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
            BlockField.color(BlockField.ColorField(fieldID: .backgroundColor, value: Color(hex: 0xAA_BB_CC_DD)))
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
                BlockField.color(BlockField.ColorField(fieldID: .backgroundColor, value: Color(hex: 0xAA_BB_CC_DD))),
            ]
        )
    }

    func testColorFormats() throws {
        let input = "{ background-color: #aabbccdd; text-color: black; }"
        let output = try blockParser.parse(input)
        XCTAssertEqual(
            output,
            [
                BlockField.color(BlockField.ColorField(fieldID: .backgroundColor, value: Color(hex: 0xAA_BB_CC_DD))),
                BlockField.color(BlockField.ColorField(fieldID: .textColor, value: Color(hex: 0x00_00_00_FF))),
            ]
        )
    }

    func testMultipleFields() throws {
        let inputs: [Subcase<String>] = [
            Subcase(
                """
                { background-color: #aabbccdd; text-color: #11223344; line-width: 3.1; label: "zap"; head1: filled_vee; }
                """,
                description: "One line, terminated last item"
            ),
            Subcase(
                """
                { background-color: #aabbccdd; text-color: #11223344; line-width: 3.1; label: "zap"; head1: filled_vee }
                """,
                description: "One line, unterminated last item"
            ),
            Subcase(
                """
                {
                    background-color: #aabbccdd; text-color: #11223344; line-width: 3.1; label: "zap"; head1: filled_vee;
                }
                """,
                description: "One separate line, terminated last item"
            ),
            Subcase(
                """
                {
                    background-color: #aabbccdd; text-color: #11223344; line-width: 3.1; label: "zap"; head1: filled_vee
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
                    head1: filled_vee;
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
                    head1: filled_vee
                }
                """,
                description: "Separate unterminated lines"
            ),
            Subcase(
                """
                {
                    background-color: #aabbccdd
                    text-color: #11223344; line-width: 3.1;
                    label: "zap"; head1: filled_vee
                }
                """,
                description: "Mixed lines"
            ),
        ]
        for input in inputs {
            let output = try blockParser.parse(input.value)
            XCTAssertNoDifference(
                output,
                [
                    .color(BlockField.ColorField(fieldID: .backgroundColor, value: Color(hex: 0xAA_BB_CC_DD))),
                    .color(BlockField.ColorField(fieldID: .textColor, value: Color(hex: 0x11_22_33_44))),
                    .numeric(BlockField.NumericField(fieldID: .lineWidth, value: 3.1)),
                    .string(BlockField.StringField(fieldID: .label, value: "zap")),
                    .variable(BlockField.VariableField(fieldID: .head1, value: "filled_vee")),
                ],
                "Failing case: \(input.description ?? "(no description)")",
                file: input.file,
                line: input.line
            )
        }
    }
}
