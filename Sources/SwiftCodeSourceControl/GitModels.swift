import Foundation
import SwiftCodeCore

public struct GitFileStatus: Codable, Sendable, Equatable, Identifiable {
    public var id: String { path }

    public enum StatusType: String, Codable, Sendable, CaseIterable {
        case modified = "modified"
        case added = "added"
        case deleted = "deleted"
        case untracked = "untracked"
        case renamed = "renamed"
        case copied = "copied"
        case ignored = "ignored"
        case conflicted = "conflicted"
    }

    public typealias Status = StatusType

    public let path: String
    public let status: StatusType
    public let isStaged: Bool

    public init(path: String, status: StatusType, isStaged: Bool) {
        self.path = path
        self.status = status
        self.isStaged = isStaged
    }
}

public struct GitStatusSnapshot: Sendable, Codable, Equatable {
    public let branchName: String
    public let ahead: Int
    public let behind: Int
    public let files: [GitFileStatus]

    public var stagedFiles: [GitFileStatus] {
        files.filter { $0.isStaged }
    }

    public var unstagedFiles: [GitFileStatus] {
        files.filter { !$0.isStaged }
    }

    public init(branchName: String, ahead: Int, behind: Int, files: [GitFileStatus]) {
        self.branchName = branchName
        self.ahead = ahead
        self.behind = behind
        self.files = files
    }
}

public struct GitStatus: Codable, Sendable, Equatable {
    public let isClean: Bool
    public let currentBranch: String
    public let upstreamBranch: String?
    public let aheadCount: Int
    public let behindCount: Int
    public let files: [GitFileStatus]

    public init(
        isClean: Bool,
        currentBranch: String,
        upstreamBranch: String? = nil,
        aheadCount: Int = 0,
        behindCount: Int = 0,
        files: [GitFileStatus] = []
    ) {
        self.isClean = isClean
        self.currentBranch = currentBranch
        self.upstreamBranch = upstreamBranch
        self.aheadCount = aheadCount
        self.behindCount = behindCount
        self.files = files
    }
}

public struct GitCommit: Codable, Sendable, Equatable, Identifiable {
    public var id: String { hash }

    public let hash: String
    public let shortHash: String
    public let authorName: String
    public let authorEmail: String
    public let date: Date
    public let message: String
    public let parentHashes: [String]

    public var author: String { authorName }
    public var email: String { authorEmail }

    public init(
        hash: String,
        shortHash: String = "",
        authorName: String,
        authorEmail: String = "",
        date: Date = Date(),
        message: String,
        parentHashes: [String] = []
    ) {
        self.hash = hash
        self.shortHash = shortHash.isEmpty ? String(hash.prefix(7)) : shortHash
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.date = date
        self.message = message
        self.parentHashes = parentHashes
    }

    // Convenience initializer matching SwiftCode-Mac internal patterns
    public init(
        hash: String,
        author: String,
        email: String,
        date: Date,
        message: String,
        parentHashes: [String] = []
    ) {
        self.init(
            hash: hash,
            shortHash: String(hash.prefix(7)),
            authorName: author,
            authorEmail: email,
            date: date,
            message: message,
            parentHashes: parentHashes
        )
    }
}

public struct GitBranch: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }

    public let name: String
    public let isCurrent: Bool
    public let isRemote: Bool
    public let trackingRemote: String?

    public init(name: String, isCurrent: Bool, isRemote: Bool, trackingRemote: String? = nil) {
        self.name = name
        self.isCurrent = isCurrent
        self.isRemote = isRemote
        self.trackingRemote = trackingRemote
    }
}

public struct GitRemote: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }

    public let name: String
    public let fetchURL: String
    public let pushURL: String

    public init(name: String, fetchURL: String, pushURL: String) {
        self.name = name
        self.fetchURL = fetchURL
        self.pushURL = pushURL
    }
}

public struct GitTag: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }

    public let name: String
    public let commitHash: String
    public let message: String?
    public let taggerName: String?
    public let date: Date?

    public init(
        name: String,
        commitHash: String,
        message: String? = nil,
        taggerName: String? = nil,
        date: Date? = nil
    ) {
        self.name = name
        self.commitHash = commitHash
        self.message = message
        self.taggerName = taggerName
        self.date = date
    }
}

public struct GitStashItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(index)-\(hash)" }

    public let index: Int
    public let hash: String
    public let message: String
    public let date: Date

    public init(index: Int, hash: String, message: String, date: Date = Date()) {
        self.index = index
        self.hash = hash
        self.message = message
        self.date = date
    }
}

public struct GitBlameLine: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(lineNumber)-\(commitHash)" }

    public let lineNumber: Int
    public let commitHash: String
    public let authorName: String
    public let date: Date
    public let content: String

    public init(
        lineNumber: Int,
        commitHash: String,
        authorName: String,
        date: Date,
        content: String
    ) {
        self.lineNumber = lineNumber
        self.commitHash = commitHash
        self.authorName = authorName
        self.date = date
        self.content = content
    }
}

public struct GitCommitDetail: Codable, Sendable, Equatable {
    public let commit: GitCommit
    public let filesChanged: [GitFileStatus]
    public let additions: Int
    public let deletions: Int
    public let fullDiff: String

    public init(
        commit: GitCommit,
        filesChanged: [GitFileStatus] = [],
        additions: Int = 0,
        deletions: Int = 0,
        fullDiff: String = ""
    ) {
        self.commit = commit
        self.filesChanged = filesChanged
        self.additions = additions
        self.deletions = deletions
        self.fullDiff = fullDiff
    }
}

public struct GitMergeResult: Codable, Sendable, Equatable {
    public let success: Bool
    public let message: String
    public let conflictedFiles: [String]
    public let mergeCommitHash: String?

    public init(
        success: Bool,
        message: String,
        conflictedFiles: [String] = [],
        mergeCommitHash: String? = nil
    ) {
        self.success = success
        self.message = message
        self.conflictedFiles = conflictedFiles
        self.mergeCommitHash = mergeCommitHash
    }
}
