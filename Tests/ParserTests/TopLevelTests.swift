import Draw
@testable import Parser
import XCTest

final class TopLevelTests: XCTestCase {
    func test() throws {
        let input = """
        node-style style1 { background-color: #11223344 }

        node n1 { style: style1 }
        node n2 { style: style1 }

        connect n1 n2 { head1: filledVee }
        constrain n1.left == n2.right + 30.0
        """
        let output = try topLevelParser.parse(input)
        assertEqual(
            output,
            [
                .nodeStyle(
                    TopLevelDecl.NodeStyle(
                        name: "style1",
                        fields: [
                            .color(BlockField.ColorField(fieldID: .backgroundColor, value: Color(hex: 0x11_22_33_44))),
                        ]
                    )
                ),
                .node(
                    TopLevelDecl.Node(
                        name: "n1", fields: [.variable(BlockField.VariableField(fieldID: .style, value: "style1"))]
                    )
                ),
                .node(
                    TopLevelDecl.Node(
                        name: "n2", fields: [.variable(BlockField.VariableField(fieldID: .style, value: "style1"))]
                    )
                ),
                .connection(
                    TopLevelDecl.Connection(
                        node1: "n1",
                        node2: "n2",
                        fields: [.variable(BlockField.VariableField(fieldID: .head1, value: "filledVee"))]
                    )
                ),
                .constraint([
                    .variable(.init(head: "n1", tail: ["left"])),
                    .relation(.eq),
                    .variable(.init(head: "n2", tail: ["right"])),
                    .operation(.add),
                    .constant(30.0),
                ]),
            ]
        )
    }
}
