import Foundation

extension AttributeScopes {
    public var boxesAndArrows: AttributeScopes.BoxesAndArrowsAttributes.Type {
        BoxesAndArrowsAttributes.self
    }

    public struct BoxesAndArrowsAttributes: AttributeScope {
        public let textColor: AttributeScopes.BoxesAndArrowsAttributes.TextColorAttribute
    }
}

extension AttributeScopes.BoxesAndArrowsAttributes {
    public enum TextColorAttribute: AttributedStringKey {
        public typealias Value = Color
        public static let name = "TextColor"
    }
}

public extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.BoxesAndArrowsAttributes, T>) -> T {
        self[T.self]
    }
}
