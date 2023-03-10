import CustomDump
import Draw
@testable import Parser
import XCTest

final class TopLevelTests: XCTestCase {
    func test() throws {
        let input = """
        box-style style1 { background-color: #11223344 }

        box n1 { style: style1 }
        box n2 { style: style1 }
        box n3

        // this is a comment
        connect n1 n2 { head1: filledVee }
        constrain n1.left == n2.right + 30.0        
        """
        let output = try topLevelParser.parse(input)
        XCTAssertNoDifference(
            [
                .boxStyle(
                    TopLevelDecl.BoxStyle(
                        name: "style1",
                        fields: [
                            .color(BlockField.ColorField(fieldID: .backgroundColor, value: Color(hex: 0x11_22_33_44))),
                        ],
                        endOfLine: .none
                    )
                ),
                .box(
                    TopLevelDecl.Box(
                        name: "n1",
                        fields: [.variable(BlockField.VariableField(fieldID: .style, value: "style1"))],
                        endOfLine: .none
                    )
                ),
                .box(
                    TopLevelDecl.Box(
                        name: "n2",
                        fields: [.variable(BlockField.VariableField(fieldID: .style, value: "style1"))],
                        endOfLine: .none
                    )
                ),
                .box(TopLevelDecl.Box(name: "n3", fields: [], endOfLine: .none)),
                .lineComment(TopLevelDecl.LineComment(comment: " this is a comment")),
                .arrow(
                    TopLevelDecl.Arrow(
                        box1: "n1",
                        box2: "n2",
                        fields: [.variable(BlockField.VariableField(fieldID: .head1, value: "filledVee"))],
                        endOfLine: .none
                    )
                ),
                .constraint(
                    Equation(
                        relation: .eq,
                        left: [
                            .variable(Parser.Equation.Variable(head: "n1", tail: ["left"])),
                        ],
                        right: [
                            .variable(Parser.Equation.Variable(head: "n2", tail: ["right"])),
                            .operation(Parser.Equation.Operation.add),
                            .constant(30.0),
                        ]
                    )
                ),
            ],
            output
        )
    }

    func testWhitespacePrefixed() throws {
        let input = """
          box-style style1 { background-color: #11223344 }

          box n1 { style: style1 }
          box n2 { style: style1 }
          box n3

          // this is a comment
          connect n1 n2 { head1: filledVee }
          constrain n1.left == n2.right + 30.0
        """
        let output = try topLevelParser.parse(input)
        XCTAssertNoDifference(
            [
                .boxStyle(
                    TopLevelDecl.BoxStyle(
                        name: "style1",
                        fields: [
                            .color(BlockField.ColorField(fieldID: .backgroundColor, value: Color(hex: 0x11_22_33_44))),
                        ],
                        endOfLine: .none
                    )
                ),
                .box(
                    TopLevelDecl.Box(
                        name: "n1",
                        fields: [.variable(BlockField.VariableField(fieldID: .style, value: "style1"))],
                        endOfLine: .none
                    )
                ),
                .box(
                    TopLevelDecl.Box(
                        name: "n2",
                        fields: [.variable(BlockField.VariableField(fieldID: .style, value: "style1"))],
                        endOfLine: .none
                    )
                ),
                .box(TopLevelDecl.Box(name: "n3", fields: [], endOfLine: .none)),
                .lineComment(TopLevelDecl.LineComment(comment: " this is a comment")),
                .arrow(
                    TopLevelDecl.Arrow(
                        box1: "n1",
                        box2: "n2",
                        fields: [.variable(BlockField.VariableField(fieldID: .head1, value: "filledVee"))],
                        endOfLine: .none
                    )
                ),
                .constraint(
                    Equation(
                        relation: .eq,
                        left: [
                            .variable(Parser.Equation.Variable(head: "n1", tail: ["left"])),
                        ],
                        right: [
                            .variable(Parser.Equation.Variable(head: "n2", tail: ["right"])),
                            .operation(Parser.Equation.Operation.add),
                            .constant(30.0),
                        ]
                    )
                ),
            ],
            output
        )
    }

    func testTrailingComments() throws {
        let input = """
        box-style style1 { background-color: #11223344 } // trailing comment 1

        box n1 { style: style1 } // trailing comment 2
        box n2 { style: style1 } // trailing comment 3
        box n3 // trailing comment 4

        // this is a comment
        connect n1 n2 { head1: filledVee } // trailing comment 5
        constrain n1.left == n2.right + 30.0 // trailing comment 6
        """
        let output = try topLevelParser.parse(input)
        XCTAssertNoDifference(
            [
                .boxStyle(
                    TopLevelDecl.BoxStyle(
                        name: "style1",
                        fields: [
                            .color(BlockField.ColorField(fieldID: .backgroundColor, value: Color(hex: 0x11_22_33_44))),
                        ],
                        endOfLine: .lineComment(TopLevelDecl.LineComment(comment: " trailing comment 1"))
                    )
                ),
                .box(
                    TopLevelDecl.Box(
                        name: "n1",
                        fields: [.variable(BlockField.VariableField(fieldID: .style, value: "style1"))],
                        endOfLine: .lineComment(TopLevelDecl.LineComment(comment: " trailing comment 2"))
                    )
                ),
                .box(
                    TopLevelDecl.Box(
                        name: "n2",
                        fields: [.variable(BlockField.VariableField(fieldID: .style, value: "style1"))],
                        endOfLine: .lineComment(TopLevelDecl.LineComment(comment: " trailing comment 3"))
                    )
                ),
                .box(
                    TopLevelDecl.Box(
                        name: "n3",
                        fields: [],
                        endOfLine: .lineComment(TopLevelDecl.LineComment(comment: " trailing comment 4"))
                    )
                ),
                .lineComment(TopLevelDecl.LineComment(comment: " this is a comment")),
                .arrow(
                    TopLevelDecl.Arrow(
                        box1: "n1",
                        box2: "n2",
                        fields: [.variable(BlockField.VariableField(fieldID: .head1, value: "filledVee"))],
                        endOfLine: .lineComment(TopLevelDecl.LineComment(comment: " trailing comment 5"))
                    )
                ),
                .constraint(
                    Equation(
                        relation: .eq,
                        left: [
                            .variable(Parser.Equation.Variable(head: "n1", tail: ["left"])),
                        ],
                        right: [
                            .variable(Parser.Equation.Variable(head: "n2", tail: ["right"])),
                            .operation(Parser.Equation.Operation.add),
                            .constant(30.0),
                        ],
                        lineComment: Parser.Equation.LineComment(
                            text: " trailing comment 6"
                        )
                    )
                ),
            ],
            output
        )
    }
}
