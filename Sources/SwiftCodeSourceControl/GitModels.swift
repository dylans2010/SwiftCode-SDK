import Foundation
import SwiftCodeCore

public struct GitFileStatus: Codable, Sendable, Equatable {
    public enum StatusType: String, Codable, Sendable {
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

public struct GitStatusSnapshot: Sendable, Codable {
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

public struct GitStatus: Codable, Sendable {
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

public struct GitCommit: Codable, Sendable {
    public let hash: String
    public let shortHash: String
    public let authorName: String
    public let authorEmail: String
    public let date: Date
    public let message: String

    public init(
        hash: String,
        shortHash: String,
        authorName: String,
        authorEmail: String,
        date: Date,
        message: String
    ) {
        self.hash = hash
        self.shortHash = shortHash
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.date = date
        self.message = message
    }
}

public struct GitBranch: Codable, Sendable {
    public let name: String
    public let isCurrent: Bool
    public let isRemote: Bool

    public init(name: String, isCurrent: Bool, isRemote: Bool) {
        self.name = name
        self.isCurrent = isCurrent
        self.isRemote = isRemote
    }
}

public struct GitRemote: Codable, Sendable {
    public let name: String
    public let fetchURL: String
    public let pushURL: String

    public init(name: String, fetchURL: String, pushURL: String) {
        self.name = name
        self.fetchURL = fetchURL
        self.pushURL = pushURL
    }
}

public actor GitService {
    public static let shared = GitService()
    private let scService = SourceControlService()

    public init() {}

    public func getStatus(for repositoryURL: URL) async throws -> GitStatusSnapshot {
        let status = try scService.getStatus(at: repositoryURL.path)
        return GitStatusSnapshot(
            branchName: status.currentBranch,
            ahead: status.aheadCount,
            behind: status.behindCount,
            files: status.files
        )
    }

    public func getDiff(repositoryURL: URL) async throws -> [GitDiffHunk] {
        return []
    }
}
