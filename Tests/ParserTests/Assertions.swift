import XCTest

func assertEqual<C>(
    _ col1: C,
    _ col2: C,
    file: StaticString = #filePath,
    line: UInt = #line
) where C: Collection, C.Element: Equatable {
    XCTAssertEqual(col1.count, col2.count, "Expected equal number of elements", file: file, line: line)
    guard col1.count == col2.count else { return }
    for (index, (e1, e2)) in zip(0..., zip(col1, col2)) {
        XCTAssertEqual(e1, e2, "Expected equal elements at index \(index)", file: file, line: line)
        guard e1 == e2 else { return }
    }
}
