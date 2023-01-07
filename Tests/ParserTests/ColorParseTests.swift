import Draw
@testable import Parser
import XCTest

final class ColorParseTests: XCTestCase {
    func test() throws {
        let cases: [Subcase<(String, (ColorFieldID, Color))>] = [
            .init(("text-color: #aabbccdd", (.textColor, Color(hex: 0xAA_BB_CC_DD)))),
            .init(("text-color: #aabbcc", (.textColor, Color(hex: 0xAA_BB_CC_FF)))),
            .init(("text-color: #abcd", (.textColor, Color(hex: 0xAA_BB_CC_DD)))),
            .init(("text-color: #abc", (.textColor, Color(hex: 0xAA_BB_CC_FF)))),
            .init(("text-color: clear", (.textColor, .clear))),
            .init(("text-color: black", (.textColor, .black))),
            .init(("text-color: white", (.textColor, .white))),
            .init(("text-color: red", (.textColor, .red))),
            .init(("text-color: blue", (.textColor, .blue))),
            .init(("text-color: magenta", (.textColor, .magenta))),
            .init(("text-color: cyan", (.textColor, .cyan))),
            .init(("text-color: yellow", (.textColor, .yellow))),
        ]

        for subcase in cases {
            let (input, (fieldID, color)) = subcase.value
            let parseOutput = try colorParse.parse(input)
            XCTAssertEqual(parseOutput.0, fieldID, file: subcase.file, line: subcase.line)
            XCTAssertEqual(parseOutput.1, color, file: subcase.file, line: subcase.line)
        }
    }
}
