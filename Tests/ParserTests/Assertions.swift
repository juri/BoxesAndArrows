import XCTest

func assertEqual<C>(
    _ col1: C,
    _ col2: C,
    file: StaticString = #filePath,
    line: UInt = #line
) where C: Collection, C.Element: Equatable {
    for (index, (e1, e2)) in zip(0..., zip(col1, col2)) {
        XCTAssertEqual(e1, e2, "Expected equal elements at index \(index)", file: file, line: line)
    }
    for (index, e1) in col1.enumerated().dropFirst(col2.count) {
        XCTFail("Missing element in col2 at index \(index): \(e1)", file: file, line: line)
    }
    for (index, e2) in col2.enumerated().dropFirst(col1.count) {
        XCTFail("Missing element in col1 at index \(index): \(e2)", file: file, line: line)
    }
}
