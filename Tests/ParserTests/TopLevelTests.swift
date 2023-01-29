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
                        ]
                    )
                ),
                .box(
                    TopLevelDecl.Box(
                        name: "n1", fields: [.variable(BlockField.VariableField(fieldID: .style, value: "style1"))]
                    )
                ),
                .box(
                    TopLevelDecl.Box(
                        name: "n2", fields: [.variable(BlockField.VariableField(fieldID: .style, value: "style1"))]
                    )
                ),
                .box(TopLevelDecl.Box(name: "n3", fields: [])),
                .arrow(
                    TopLevelDecl.Arrow(
                        box1: "n1",
                        box2: "n2",
                        fields: [.variable(BlockField.VariableField(fieldID: .head1, value: "filledVee"))]
                    )
                ),
                .constraint(
                    [
                        .variable(Parser.EquationPart.Variable(head: "n1", tail: ["left"])),
                        .relation(Parser.EquationPart.Relation.eq),
                        .variable(Parser.EquationPart.Variable(head: "n2", tail: ["right"])),
                        .operation(Parser.EquationPart.Operation.add),
                        .constant(30.0),
                    ]
                ),
            ],
            output
        )
    }
}
