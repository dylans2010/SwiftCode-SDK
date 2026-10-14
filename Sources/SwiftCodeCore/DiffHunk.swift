import Foundation

public struct DiffHunk: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let oldStart: Int
    public let oldCount: Int
    public let newStart: Int
    public let newCount: Int
    public let lines: [String]

    public init(id: UUID = UUID(), oldStart: Int, oldCount: Int, newStart: Int, newCount: Int, lines: [String]) {
        self.id = id
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.lines = lines
    }

    public var header: String {
        return "@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@"
    }
}

public struct UnifiedDiffResult: Codable, Sendable, Equatable {
    public let filePath: String
    public let hunks: [DiffHunk]
    public let addedLines: Int
    public let removedLines: Int
    public let unifiedText: String

    public var hasChanges: Bool {
        return addedLines > 0 || removedLines > 0
    }

    public init(filePath: String, hunks: [DiffHunk], addedLines: Int, removedLines: Int, unifiedText: String) {
        self.filePath = filePath
        self.hunks = hunks
        self.addedLines = addedLines
        self.removedLines = removedLines
        self.unifiedText = unifiedText
    }
}

public enum DiffConflictError: Error, LocalizedError, Sendable {
    case targetNotFound(target: String, file: String)
    case multipleMatches(target: String, count: Int, file: String)
    case staleFileState(file: String)

    public var errorDescription: String? {
        switch self {
        case .targetNotFound(let target, let file):
            let preview = target.count > 60 ? String(target.prefix(60)) + "..." : target
            return "Target text '\(preview)' was not found in \(file). Verify current file contents before editing."
        case .multipleMatches(let target, let count, let file):
            let preview = target.count > 60 ? String(target.prefix(60)) + "..." : target
            return "Target text '\(preview)' matched \(count) locations in \(file). Provide more surrounding context to disambiguate."
        case .staleFileState(let file):
            return "File '\(file)' changed since diff was computed."
        }
    }
}
