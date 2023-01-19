import Foundation

extension AttributeScopes {
    public var boxesAndArrows: BoxesAndArrowsAttributes.Type {
        BoxesAndArrowsAttributes.self
    }
}

public struct BoxesAndArrowsAttributes: AttributeScope {
    public let textAlignment: BoxesAndArrowsAttributes.TextAlignmentAttribute
    public let textColor: BoxesAndArrowsAttributes.TextColorAttribute
    public let font: BoxesAndArrowsAttributes.FontAttribute
}

public protocol BoxesAndArrowsAttributedStringKey: AttributedStringKey {}

extension BoxesAndArrowsAttributes {
    public enum TextAlignmentAttribute: BoxesAndArrowsAttributedStringKey {
        public typealias Value = TextAlignment
        public static let name = "TextAlignment"
    }

    public enum TextColorAttribute: BoxesAndArrowsAttributedStringKey {
        public typealias Value = Color
        public static let name = "TextColor"
    }

    public enum FontAttribute: BoxesAndArrowsAttributedStringKey {
        public typealias Value = Font
        public static let name = "Font"
    }
}

public extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<BoxesAndArrowsAttributes, T>) -> T {
        self[T.self]
    }
}
