import XCTest

struct Subcase<T> {
    let value: T
    let description: String?
    let file: StaticString
    let line: UInt

    init(_ value: T, description: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        self.value = value
        self.description = description
        self.file = file
        self.line = line
    }

    var sourceCodeLocation: XCTSourceCodeLocation {
        .init(filePath: self.file, lineNumber: self.line)
    }

    var sourceCodeContext: XCTSourceCodeContext {
        .init(location: self.sourceCodeLocation)
    }
}
