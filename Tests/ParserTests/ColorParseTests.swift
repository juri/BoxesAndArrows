import Draw
@testable import Parser
import XCTest

final class ColorParseTests: XCTestCase {
    func test() throws {
        let cases: [Subcase<(String, Color)>] = [
            .init(("text-color: #aabbccdd", Color(hex: 0xAA_BB_CC_DD))),
            .init(("text-color: #aabbcc", Color(hex: 0xAA_BB_CC_FF))),
            .init(("text-color: #abcd", Color(hex: 0xAA_BB_CC_DD))),
            .init(("text-color: #abc", Color(hex: 0xAA_BB_CC_FF))),
        ]

        for subcase in cases {
            let parseOutput = try colorParse.parse(subcase.value.0)
            XCTAssertEqual(parseOutput.1, subcase.value.1, file: subcase.file, line: subcase.line)
        }
    }
}
