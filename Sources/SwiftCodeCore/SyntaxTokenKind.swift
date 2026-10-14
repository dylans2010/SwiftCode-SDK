import Foundation

public enum SyntaxTokenKind: String, Sendable, Codable, CaseIterable {
    case keyword
    case string
    case comment
    case number
    case type
    case plain
}
