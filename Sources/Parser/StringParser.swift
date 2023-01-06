import Parsing

enum Strings {
    static let escaped = ParsePrint {
        "\\"
        Prefix(1)
    }

    static let notQuote = Prefix(while: { $0 != "\"" && $0 != "\\" }).filter { !$0.isEmpty }

    static let stringPart = OneOf {
        escaped
        notQuote
    }

    struct StringJoinConversion: Conversion {
        func apply(_ input: [Substring]) throws -> String { input.joined() }
        func unapply(_ output: String) throws -> [Substring] { [output[...]] }
    }

    static let oneOrMoreStringContent = Many {
        stringPart
    }.map(StringJoinConversion())

    static let stringContent = oneOrMoreStringContent
        .replaceError(with: "")

    static let quoted = Parse {
        "\""
        stringContent
        "\""
    }
}
