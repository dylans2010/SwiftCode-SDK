import Foundation
import SwiftCodeCore

public actor GitService {
    public static let shared = GitService()
    private let scService: SourceControlService

    public init(scService: SourceControlService = SourceControlService()) {
        self.scService = scService
    }

    public func isGitInstalled() -> Bool {
        return scService.isGitInstalled()
    }

    public func getGitVersion() throws -> String {
        return try scService.getGitVersion()
    }

    public func isGitRepository(at url: URL) -> Bool {
        return scService.isGitRepository(at: url.path)
    }

    public func getStatus(for repositoryURL: URL) throws -> GitStatusSnapshot {
        return try scService.getSnapshot(at: repositoryURL.path)
    }

    public func getFullStatus(for repositoryURL: URL) throws -> GitStatus {
        return try scService.getStatus(at: repositoryURL.path)
    }

    public func stage(path: URL, repositoryURL: URL) throws {
        let relPath = repoRelativePath(path.path, root: repositoryURL.path)
        try scService.stage(paths: [relPath], in: repositoryURL.path)
    }

    public func stage(path: String, repositoryURL: URL) throws {
        try scService.stage(paths: [path], in: repositoryURL.path)
    }

    public func stageAll(repositoryURL: URL) throws {
        try scService.stageAll(in: repositoryURL.path)
    }

    public func unstage(path: URL, repositoryURL: URL) throws {
        let relPath = repoRelativePath(path.path, root: repositoryURL.path)
        try scService.unstage(paths: [relPath], in: repositoryURL.path)
    }

    public func unstage(path: String, repositoryURL: URL) throws {
        try scService.unstage(paths: [path], in: repositoryURL.path)
    }

    public func unstageAll(repositoryURL: URL) throws {
        try scService.unstageAll(in: repositoryURL.path)
    }

    public func discardChanges(path: URL, repositoryURL: URL) throws {
        let relPath = repoRelativePath(path.path, root: repositoryURL.path)
        try scService.discardChanges(paths: [relPath], in: repositoryURL.path)
    }

    public func discardChanges(path: String, repositoryURL: URL) throws {
        try scService.discardChanges(paths: [path], in: repositoryURL.path)
    }

    public func discardAllChanges(repositoryURL: URL) throws {
        try scService.discardAllChanges(in: repositoryURL.path)
    }

    public func commit(message: String, repositoryURL: URL, amend: Bool = false) throws -> GitCommit {
        return try scService.commit(message: message, in: repositoryURL.path, amend: amend)
    }

    public func getLog(repositoryURL: URL, limit: Int = 100, branch: String? = nil, file: String? = nil) throws -> [GitCommit] {
        return try scService.getLog(at: repositoryURL.path, limit: limit, branch: branch, file: file)
    }

    public func getCommitDetail(hash: String, repositoryURL: URL) throws -> GitCommitDetail {
        return try scService.getCommitDetail(hash: hash, in: repositoryURL.path)
    }

    public func getBranches(repositoryURL: URL) throws -> [GitBranch] {
        return try scService.getBranches(at: repositoryURL.path)
    }

    public func createBranch(name: String, repositoryURL: URL, startPoint: String? = nil, checkout: Bool = true) throws {
        try scService.createBranch(name: name, in: repositoryURL.path, startPoint: startPoint, checkout: checkout)
    }

    public func checkout(branch: String, repositoryURL: URL) throws {
        try scService.checkout(branch: branch, in: repositoryURL.path)
    }

    public func deleteBranch(name: String, repositoryURL: URL, force: Bool = false) throws {
        try scService.deleteBranch(name: name, in: repositoryURL.path, force: force)
    }

    public func renameBranch(oldName: String, newName: String, repositoryURL: URL) throws {
        try scService.renameBranch(oldName: oldName, newName: newName, in: repositoryURL.path)
    }

    public func getTags(repositoryURL: URL) throws -> [GitTag] {
        return try scService.getTags(at: repositoryURL.path)
    }

    public func createTag(name: String, message: String? = nil, repositoryURL: URL) throws {
        try scService.createTag(name: name, message: message, in: repositoryURL.path)
    }

    public func deleteTag(name: String, repositoryURL: URL) throws {
        try scService.deleteTag(name: name, in: repositoryURL.path)
    }

    public func getRemotes(repositoryURL: URL) throws -> [GitRemote] {
        return try scService.getRemotes(at: repositoryURL.path)
    }

    public func addRemote(name: String, url: String, repositoryURL: URL) throws {
        try scService.addRemote(name: name, url: url, in: repositoryURL.path)
    }

    public func removeRemote(name: String, repositoryURL: URL) throws {
        try scService.removeRemote(name: name, in: repositoryURL.path)
    }

    public func fetch(remote: String? = nil, repositoryURL: URL) throws {
        try scService.fetch(remote: remote, in: repositoryURL.path)
    }

    public func pull(remote: String? = nil, branch: String? = nil, repositoryURL: URL, rebase: Bool = false) throws {
        try scService.pull(remote: remote, branch: branch, in: repositoryURL.path, rebase: rebase)
    }

    public func push(remote: String? = nil, branch: String? = nil, repositoryURL: URL, setUpstream: Bool = false, force: Bool = false) throws {
        try scService.push(remote: remote, branch: branch, in: repositoryURL.path, setUpstream: setUpstream, force: force)
    }

    public func forcePush(branch: String, repositoryURL: URL) throws {
        try scService.forcePush(branch: branch, in: repositoryURL.path)
    }

    public func getDiff(repositoryURL: URL, staged: Bool = false, file: String? = nil) throws -> [GitDiffHunk] {
        return try scService.getDiffHunks(at: repositoryURL.path, staged: staged, file: file)
    }

    public func getRawDiff(repositoryURL: URL, staged: Bool = false, file: String? = nil) throws -> String {
        return try scService.getDiff(at: repositoryURL.path, staged: staged, file: file)
    }

    public func blame(file: String, repositoryURL: URL) throws -> [GitBlameLine] {
        return try scService.blame(file: file, in: repositoryURL.path)
    }

    public func stash(message: String? = nil, repositoryURL: URL, includeUntracked: Bool = true) throws {
        try scService.stash(message: message, in: repositoryURL.path, includeUntracked: includeUntracked)
    }

    public func stashPop(index: Int? = nil, repositoryURL: URL) throws {
        try scService.stashPop(index: index, in: repositoryURL.path)
    }

    public func stashList(repositoryURL: URL) throws -> [GitStashItem] {
        return try scService.stashList(in: repositoryURL.path)
    }

    public func stashDrop(index: Int = 0, repositoryURL: URL) throws {
        try scService.stashDrop(index: index, in: repositoryURL.path)
    }

    public func stashClear(repositoryURL: URL) throws {
        try scService.stashClear(in: repositoryURL.path)
    }

    public func merge(branch: String, repositoryURL: URL) throws -> GitMergeResult {
        return try scService.merge(branch: branch, in: repositoryURL.path)
    }

    public func abortMerge(repositoryURL: URL) throws {
        try scService.abortMerge(in: repositoryURL.path)
    }

    public func rollback(to sha: String, repositoryURL: URL, hard: Bool = true) throws {
        try scService.rollback(to: sha, in: repositoryURL.path, hard: hard)
    }

    public func clone(remoteURL: URL, destinationURL: URL, token: String? = nil) throws {
        try scService.clone(remoteURL: remoteURL.absoluteString, destinationPath: destinationURL.path, token: token)
    }

    private func repoRelativePath(_ path: String, root: String) -> String {
        let cleanRoot = root.hasSuffix("/") ? root : root + "/"
        if path.hasPrefix(cleanRoot) {
            return String(path.dropFirst(cleanRoot.count))
        }
        return path
    }
}
