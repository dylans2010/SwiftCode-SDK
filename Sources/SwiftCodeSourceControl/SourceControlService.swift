import Foundation
import SwiftCodeCore
import SwiftCodeDiagnostics
import SwiftCodeWorkspace

public enum GitError: Error, LocalizedError, Sendable {
    case notARepository(String)
    case commandFailed(command: String, exitCode: Int32, output: String)
    case invalidBranch(String)
    case mergeConflict(conflictedFiles: [String], output: String)
    case authenticationRequired(String)

    public var errorDescription: String? {
        switch self {
        case .notARepository(let path):
            return "Path is not inside a Git repository: \(path)"
        case .commandFailed(let cmd, let code, let out):
            return "Git command '\(cmd)' failed with exit code \(code): \(out)"
        case .invalidBranch(let branch):
            return "Invalid Git branch: \(branch)"
        case .mergeConflict(let files, let output):
            return "Merge conflict in \(files.count) files: \(files.joined(separator: ", ")). Output: \(output)"
        case .authenticationRequired(let remote):
            return "Git remote requires authentication: \(remote)"
        }
    }
}

public final class SourceControlService: Sendable {
    private let gitPath: String

    public init(gitPath: String = "/usr/bin/git") {
        if FileManager.default.isExecutableFile(atPath: gitPath) {
            self.gitPath = gitPath
        } else {
            let commonPaths = [
                "/usr/local/bin/git",
                "/opt/homebrew/bin/git",
                "/Library/Developer/CommandLineTools/usr/bin/git",
                "/usr/bin/git"
            ]
            self.gitPath = commonPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) ?? gitPath
        }
    }

    @discardableResult
    public func runGit(args: [String], in directory: String, environment: [String: String]? = nil) throws -> String {
        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.standardOutput = outPipe
        process.standardError = errPipe

        if let environment = environment {
            var fullEnv = ProcessInfo.processInfo.environment
            for (key, val) in environment {
                fullEnv[key] = val
            }
            process.environment = fullEnv
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw GitError.commandFailed(command: args.joined(separator: " "), exitCode: -1, output: error.localizedDescription)
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let out = stderr.isEmpty ? stdout : stderr
            if out.lowercased().contains("conflict") || out.lowercased().contains("unmerged") {
                let conflicts = getConflictedFileList(in: directory)
                throw GitError.mergeConflict(conflictedFiles: conflicts, output: out)
            }
            throw GitError.commandFailed(
                command: args.joined(separator: " "),
                exitCode: process.terminationStatus,
                output: out
            )
        }
        return stdout
    }

    public func isGitInstalled() -> Bool {
        return FileManager.default.isExecutableFile(atPath: gitPath)
    }

    public func getGitVersion() throws -> String {
        let out = try runGit(args: ["--version"], in: FileManager.default.currentDirectoryPath)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func isGitRepository(at path: String) -> Bool {
        do {
            let out = try runGit(args: ["rev-parse", "--is-inside-work-tree"], in: path)
            return out.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch {
            return false
        }
    }

    public func initRepository(at path: String, initialBranch: String = "main") throws {
        _ = try runGit(args: ["init", "-b", initialBranch], in: path)
    }

    public func clone(remoteURL: String, destinationPath: String, branch: String? = nil, token: String? = nil) throws {
        var args = ["clone"]
        if let branch = branch, !branch.isEmpty {
            args.append(contentsOf: ["-b", branch])
        }
        args.append(contentsOf: [remoteURL, destinationPath])

        var env: [String: String]? = nil
        if token != nil {
            env = ["GIT_TERMINAL_PROMPT": "0"]
        }

        let parentDir = (destinationPath as NSString).deletingLastPathComponent
        _ = try runGit(args: args, in: parentDir, environment: env)
    }

    public func getStatus(at path: String) throws -> GitStatus {
        guard isGitRepository(at: path) else {
            throw GitError.notARepository(path)
        }

        let raw = try runGit(args: ["status", "--porcelain=v1", "-b"], in: path)
        let lines = raw.components(separatedBy: .newlines)

        var currentBranch = "main"
        var upstream: String? = nil
        var ahead = 0
        var behind = 0
        var files: [GitFileStatus] = []

        for line in lines {
            if line.hasPrefix("## ") {
                let header = String(line.dropFirst(3))
                let parts = header.components(separatedBy: "...")
                currentBranch = parts.first?.trimmingCharacters(in: .whitespaces) ?? "HEAD"
                if parts.count > 1 {
                    let rest = parts[1]
                    if let openBracket = rest.firstIndex(of: "[") {
                        upstream = String(rest[..<openBracket]).trimmingCharacters(in: .whitespaces)
                        let bracketContent = rest[openBracket...].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                        if bracketContent.contains("ahead") {
                            ahead = 1
                        }
                        if bracketContent.contains("behind") {
                            behind = 1
                        }
                    } else {
                        upstream = rest.trimmingCharacters(in: .whitespaces)
                    }
                }
            } else if line.count >= 3 {
                let indexStatus = line[line.startIndex]
                let workTreeStatus = line[line.index(line.startIndex, offsetBy: 1)]
                let filePath = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)

                if indexStatus == "?" && workTreeStatus == "?" {
                    files.append(GitFileStatus(path: filePath, status: .untracked, isStaged: false))
                } else if indexStatus == "U" || workTreeStatus == "U" {
                    files.append(GitFileStatus(path: filePath, status: .conflicted, isStaged: false))
                } else {
                    if indexStatus != " " && indexStatus != "?" {
                        let statusType: GitFileStatus.StatusType = indexStatus == "A" ? .added : (indexStatus == "D" ? .deleted : (indexStatus == "R" ? .renamed : .modified))
                        files.append(GitFileStatus(path: filePath, status: statusType, isStaged: true))
                    }
                    if workTreeStatus != " " && workTreeStatus != "?" {
                        let statusType: GitFileStatus.StatusType = workTreeStatus == "A" ? .added : (workTreeStatus == "D" ? .deleted : .modified)
                        files.append(GitFileStatus(path: filePath, status: statusType, isStaged: false))
                    }
                }
            }
        }

        return GitStatus(
            isClean: files.isEmpty,
            currentBranch: currentBranch,
            upstreamBranch: upstream,
            aheadCount: ahead,
            behindCount: behind,
            files: files
        )
    }

    public func getSnapshot(at path: String) throws -> GitStatusSnapshot {
        let status = try getStatus(at: path)
        return GitStatusSnapshot(
            branchName: status.currentBranch,
            ahead: status.aheadCount,
            behind: status.behindCount,
            files: status.files
        )
    }

    public func stage(paths: [String], in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        guard !paths.isEmpty else { return }
        var args = ["add", "--"]
        args.append(contentsOf: paths)
        _ = try runGit(args: args, in: directory)
    }

    public func stageAll(in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        _ = try runGit(args: ["add", "-A"], in: directory)
    }

    public func unstage(paths: [String], in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        guard !paths.isEmpty else { return }
        var args = ["restore", "--staged", "--"]
        args.append(contentsOf: paths)
        _ = try runGit(args: args, in: directory)
    }

    public func unstageAll(in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        _ = try runGit(args: ["restore", "--staged", "."], in: directory)
    }

    public func discardChanges(paths: [String], in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        guard !paths.isEmpty else { return }
        var restoreArgs = ["restore", "--"]
        restoreArgs.append(contentsOf: paths)
        _ = try? runGit(args: restoreArgs, in: directory)

        var cleanArgs = ["clean", "-f", "--"]
        cleanArgs.append(contentsOf: paths)
        _ = try? runGit(args: cleanArgs, in: directory)
    }

    public func discardAllChanges(in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        _ = try? runGit(args: ["restore", "."], in: directory)
        _ = try? runGit(args: ["clean", "-fd"], in: directory)
    }

    public func commit(message: String, in directory: String, amend: Bool = false, author: String? = nil) throws -> GitCommit {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        var args = ["commit", "-m", message]
        if amend { args.append("--amend") }
        if let author = author, !author.isEmpty {
            args.append(contentsOf: ["--author", author])
        }
        _ = try runGit(args: args, in: directory)

        let commits = try getLog(at: directory, limit: 1)
        guard let latest = commits.first else {
            throw GitError.commandFailed(command: "commit", exitCode: -1, output: "Failed to retrieve committed revision")
        }
        return latest
    }

    public func getLog(at path: String, limit: Int = 50, branch: String? = nil, file: String? = nil) throws -> [GitCommit] {
        guard isGitRepository(at: path) else {
            throw GitError.notARepository(path)
        }
        let format = "%H|%h|%an|%ae|%at|%s|%P"
        var args = ["log", "-n", "\(limit)", "--pretty=format:\(format)"]
        if let branch = branch, !branch.isEmpty {
            args.append(branch)
        }
        if let file = file, !file.isEmpty {
            args.append(contentsOf: ["--", file])
        }

        let raw = try runGit(args: args, in: path)
        var commits: [GitCommit] = []

        for line in raw.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 6 else { continue }
            let hash = parts[0]
            let shortHash = parts[1]
            let name = parts[2]
            let email = parts[3]
            let timestamp = Double(parts[4]) ?? 0
            let message = parts[5]
            let parents = parts.count >= 7 ? parts[6].components(separatedBy: " ").filter { !$0.isEmpty } : []

            commits.append(GitCommit(
                hash: hash,
                shortHash: shortHash,
                authorName: name,
                authorEmail: email,
                date: Date(timeIntervalSince1970: timestamp),
                message: message,
                parentHashes: parents
            ))
        }
        return commits
    }

    public func getCommitDetail(hash: String, in directory: String) throws -> GitCommitDetail {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        let logList = try getLog(at: directory, limit: 1, branch: hash)
        guard let commit = logList.first else {
            throw GitError.commandFailed(command: "log \(hash)", exitCode: -1, output: "Commit not found: \(hash)")
        }

        let numstat = try runGit(args: ["show", "--numstat", "--pretty=format:", hash], in: directory)
        var files: [GitFileStatus] = []
        var totalAdditions = 0
        var totalDeletions = 0

        for line in numstat.components(separatedBy: .newlines) where !line.isEmpty {
            let cols = line.components(separatedBy: "\t")
            guard cols.count >= 3 else { continue }
            let adds = Int(cols[0]) ?? 0
            let dels = Int(cols[1]) ?? 0
            let path = cols[2]
            totalAdditions += adds
            totalDeletions += dels
            files.append(GitFileStatus(path: path, status: .modified, isStaged: true))
        }

        let fullDiff = try runGit(args: ["show", hash], in: directory)

        return GitCommitDetail(
            commit: commit,
            filesChanged: files,
            additions: totalAdditions,
            deletions: totalDeletions,
            fullDiff: fullDiff
        )
    }

    public func getBranches(at path: String) throws -> [GitBranch] {
        guard isGitRepository(at: path) else { throw GitError.notARepository(path) }
        let raw = try runGit(args: ["branch", "-a", "--format=%(refname:short)|%(HEAD)|%(upstream:short)"], in: path)
        return raw.components(separatedBy: .newlines).compactMap { (line: String) -> GitBranch? in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 2 else { return nil }
            let name = parts[0].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            let isCurrent = parts[1].trimmingCharacters(in: .whitespaces) == "*"
            let tracking = parts.count >= 3 ? parts[2].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let trackingRemote = tracking.isEmpty ? nil : tracking
            return GitBranch(
                name: name,
                isCurrent: isCurrent,
                isRemote: name.hasPrefix("origin/") || name.hasPrefix("remotes/"),
                trackingRemote: trackingRemote
            )
        }
    }

    public func createBranch(name: String, in directory: String, startPoint: String? = nil, checkout: Bool = true) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        var args = checkout ? ["checkout", "-b", name] : ["branch", name]
        if let startPoint = startPoint, !startPoint.isEmpty {
            args.append(startPoint)
        }
        _ = try runGit(args: args, in: directory)
    }

    public func checkout(branch: String, in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        _ = try runGit(args: ["checkout", branch], in: directory)
    }

    public func deleteBranch(name: String, in directory: String, force: Bool = false) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        let flag = force ? "-D" : "-d"
        _ = try runGit(args: ["branch", flag, name], in: directory)
    }

    public func renameBranch(oldName: String, newName: String, in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        _ = try runGit(args: ["branch", "-m", oldName, newName], in: directory)
    }

    public func getTags(at path: String) throws -> [GitTag] {
        guard isGitRepository(at: path) else { throw GitError.notARepository(path) }
        let raw = try runGit(args: ["tag", "-l", "--format=%(refname:short)|%(objectname)|%(taggername)|%(taggerdate:unix)|%(subject)"], in: path)
        return raw.components(separatedBy: .newlines).compactMap { (line: String) -> GitTag? in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 2 else { return nil }
            let name = parts[0]
            guard !name.isEmpty else { return nil }
            let hash = parts[1]
            let tagger = parts.count >= 3 && !parts[2].isEmpty ? parts[2] : nil
            var date: Date? = nil
            if parts.count >= 4, let stamp = Double(parts[3]) {
                date = Date(timeIntervalSince1970: stamp)
            }
            let msg = parts.count >= 5 && !parts[4].isEmpty ? parts[4] : nil
            return GitTag(name: name, commitHash: hash, message: msg, taggerName: tagger, date: date)
        }
    }

    public func createTag(name: String, message: String? = nil, in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        var args = ["tag"]
        if let msg = message, !msg.isEmpty {
            args.append(contentsOf: ["-a", name, "-m", msg])
        } else {
            args.append(name)
        }
        _ = try runGit(args: args, in: directory)
    }

    public func deleteTag(name: String, in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        _ = try runGit(args: ["tag", "-d", name], in: directory)
    }

    public func getRemotes(at path: String) throws -> [GitRemote] {
        guard isGitRepository(at: path) else { throw GitError.notARepository(path) }
        let raw = try runGit(args: ["remote", "-v"], in: path)
        var remotes: [String: (fetch: String, push: String)] = [:]

        for line in raw.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.split(separator: "\t")
            guard parts.count == 2 else { continue }
            let name = String(parts[0])
            let rest = parts[1]
            if let spaceIndex = rest.firstIndex(of: " ") {
                let url = String(rest[..<spaceIndex])
                let type = String(rest[spaceIndex...])
                var current = remotes[name] ?? ("", "")
                if type.contains("(fetch)") {
                    current.fetch = url
                } else if type.contains("(push)") {
                    current.push = url
                }
                remotes[name] = current
            }
        }

        return remotes.map { key, val in
            GitRemote(name: key, fetchURL: val.fetch.isEmpty ? val.push : val.fetch, pushURL: val.push.isEmpty ? val.fetch : val.push)
        }.sorted { $0.name < $1.name }
    }

    public func addRemote(name: String, url: String, in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        _ = try runGit(args: ["remote", "add", name, url], in: directory)
    }

    public func removeRemote(name: String, in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        _ = try runGit(args: ["remote", "remove", name], in: directory)
    }

    public func fetch(remote: String? = nil, in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        var args = ["fetch"]
        if let remote = remote, !remote.isEmpty {
            args.append(remote)
        }
        _ = try runGit(args: args, in: directory)
    }

    public func pull(remote: String? = nil, branch: String? = nil, in directory: String, rebase: Bool = false) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        var args = ["pull"]
        if rebase { args.append("--rebase") }
        if let remote = remote, !remote.isEmpty {
            args.append(remote)
            if let branch = branch, !branch.isEmpty {
                args.append(branch)
            }
        }
        _ = try runGit(args: args, in: directory)
    }

    public func push(remote: String? = nil, branch: String? = nil, in directory: String, setUpstream: Bool = false, force: Bool = false) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        var args = ["push"]
        if force { args.append("--force") }
        if setUpstream { args.append("-u") }
        if let remote = remote, !remote.isEmpty {
            args.append(remote)
            if let branch = branch, !branch.isEmpty {
                args.append(branch)
            }
        }
        _ = try runGit(args: args, in: directory)
    }

    public func forcePush(branch: String, in directory: String) throws {
        try push(remote: "origin", branch: branch, in: directory, force: true)
    }

    public func getDiff(at path: String, staged: Bool = false, file: String? = nil) throws -> String {
        guard isGitRepository(at: path) else {
            throw GitError.notARepository(path)
        }
        var args = ["diff"]
        if staged {
            args.append("--cached")
        }
        if let file = file, !file.isEmpty {
            args.append(contentsOf: ["--", file])
        }
        return try runGit(args: args, in: path)
    }

    public func getDiffHunks(at path: String, staged: Bool = false, file: String? = nil) throws -> [GitDiffHunk] {
        let diffOutput = try getDiff(at: path, staged: staged, file: file)
        return parseDiff(diffOutput)
    }

    public func blame(file: String, in directory: String) throws -> [GitBlameLine] {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        let raw = try runGit(args: ["blame", "-p", "--", file], in: directory)
        return parsePorcelainBlame(raw)
    }

    public func stash(message: String? = nil, in directory: String, includeUntracked: Bool = true) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        var args = ["stash", "push"]
        if includeUntracked { args.append("-u") }
        if let msg = message, !msg.isEmpty {
            args.append(contentsOf: ["-m", msg])
        }
        _ = try runGit(args: args, in: directory)
    }

    public func stashPop(index: Int? = nil, in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        var args = ["stash", "pop"]
        if let index = index {
            args.append("stash@{\(index)}")
        }
        _ = try runGit(args: args, in: directory)
    }

    public func stashList(in directory: String) throws -> [GitStashItem] {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        let raw = try runGit(args: ["stash", "list", "--format=%gd|%H|%gs|%at"], in: directory)
        var items: [GitStashItem] = []

        for line in raw.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 4 else { continue }
            let ref = parts[0]
            let hash = parts[1]
            let msg = parts[2]
            let timestamp = Double(parts[3]) ?? 0

            var index = 0
            if let start = ref.firstIndex(of: "{"), let end = ref.firstIndex(of: "}") {
                let numStr = ref[ref.index(after: start)..<end]
                index = Int(numStr) ?? 0
            }

            items.append(GitStashItem(
                index: index,
                hash: hash,
                message: msg,
                date: Date(timeIntervalSince1970: timestamp)
            ))
        }
        return items
    }

    public func stashDrop(index: Int = 0, in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        _ = try runGit(args: ["stash", "drop", "stash@{\(index)}"], in: directory)
    }

    public func stashClear(in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        _ = try runGit(args: ["stash", "clear"], in: directory)
    }

    public func merge(branch: String, in directory: String) throws -> GitMergeResult {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        do {
            let out = try runGit(args: ["merge", branch], in: directory)
            let commits = try getLog(at: directory, limit: 1)
            return GitMergeResult(
                success: true,
                message: out,
                conflictedFiles: [],
                mergeCommitHash: commits.first?.hash
            )
        } catch let GitError.mergeConflict(conflictedFiles, output) {
            return GitMergeResult(
                success: false,
                message: output,
                conflictedFiles: conflictedFiles,
                mergeCommitHash: nil
            )
        }
    }

    public func abortMerge(in directory: String) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        _ = try runGit(args: ["merge", "--abort"], in: directory)
    }

    public func rollback(to sha: String, in directory: String, hard: Bool = true) throws {
        guard isGitRepository(at: directory) else { throw GitError.notARepository(directory) }
        let flag = hard ? "--hard" : "--soft"
        _ = try runGit(args: ["reset", flag, sha], in: directory)
    }

    private func getConflictedFileList(in directory: String) -> [String] {
        guard let raw = try? runGit(args: ["diff", "--name-only", "--diff-filter=U"], in: directory) else {
            return []
        }
        return raw.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func parseDiff(_ output: String) -> [GitDiffHunk] {
        var hunks: [GitDiffHunk] = []
        let lines = output.components(separatedBy: .newlines)
        var currentHeader: String?
        var currentLines: [String] = []

        for line in lines {
            if line.hasPrefix("@@ ") {
                if let header = currentHeader {
                    hunks.append(GitDiffHunk(header: header, lines: currentLines))
                }
                currentHeader = line
                currentLines = []
            } else if currentHeader != nil {
                currentLines.append(line)
            }
        }
        if let header = currentHeader {
            hunks.append(GitDiffHunk(header: header, lines: currentLines))
        }
        return hunks
    }

    private func parsePorcelainBlame(_ raw: String) -> [GitBlameLine] {
        var result: [GitBlameLine] = []
        let lines = raw.components(separatedBy: .newlines)

        var currentHash = ""
        var currentAuthor = ""
        var currentTime: Double = 0
        var currentLineNumber = 0

        for line in lines {
            if line.range(of: "^[0-9a-f]{40} ", options: .regularExpression) != nil {
                let parts = line.components(separatedBy: " ")
                if parts.count >= 3 {
                    currentHash = parts[0]
                    currentLineNumber = Int(parts[2]) ?? currentLineNumber + 1
                }
            } else if line.hasPrefix("author ") {
                currentAuthor = String(line.dropFirst(7))
            } else if line.hasPrefix("author-time ") {
                currentTime = Double(line.dropFirst(12)) ?? 0
            } else if line.hasPrefix("\t") {
                let code = String(line.dropFirst(1))
                result.append(GitBlameLine(
                    lineNumber: currentLineNumber,
                    commitHash: currentHash,
                    authorName: currentAuthor,
                    date: Date(timeIntervalSince1970: currentTime),
                    content: code
                ))
            }
        }
        return result
    }
}
