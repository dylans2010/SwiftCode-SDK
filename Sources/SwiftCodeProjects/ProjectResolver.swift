import Foundation
import Observation
import os.log

/// Strongly typed metadata model representing a fully resolved workspace/project structure
public struct ResolvedProjectMetadata: Sendable, Hashable {
    public let rootURL: URL
    public let projectName: String
    public let isSwiftPackage: Bool
    public let isXcodeProject: Bool
    public let isXcodeWorkspace: Bool
    public let packageSwiftURL: URL?
    public let xcodeprojURL: URL?
    public let xcworkspaceURL: URL?
    public let buildRootURL: URL
    public let buildDestination: String

    public init(
        rootURL: URL,
        projectName: String,
        isSwiftPackage: Bool,
        isXcodeProject: Bool,
        isXcodeWorkspace: Bool,
        packageSwiftURL: URL?,
        xcodeprojURL: URL?,
        xcworkspaceURL: URL?,
        buildRootURL: URL,
        buildDestination: String
    ) {
        self.rootURL = rootURL
        self.projectName = projectName
        self.isSwiftPackage = isSwiftPackage
        self.isXcodeProject = isXcodeProject
        self.isXcodeWorkspace = isXcodeWorkspace
        self.packageSwiftURL = packageSwiftURL
        self.xcodeprojURL = xcodeprojURL
        self.xcworkspaceURL = xcworkspaceURL
        self.buildRootURL = buildRootURL
        self.buildDestination = buildDestination
    }
}

/// Error types that can be encountered during project resolution
public enum ProjectResolutionError: Error, LocalizedError, Sendable {
    case activeProjectNotFound
    case resolutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .activeProjectNotFound:
            return "No active workspace project was detected or linked."
        case .resolutionFailed(let reason):
            return "Failed to resolve project details: \(reason)"
        }
    }
}

/// Centralized, reusable project resolution service to detect and parse active workspace state
@Observable
@MainActor
public final class ProjectResolver: Sendable {
    public static let shared = ProjectResolver()

    private let logger = Logger(subsystem: "com.swiftcode.sdk", category: "ProjectResolver")

    public var activeProjectURL: URL? = nil
    public var selectedDestination: String = "generic/platform=macOS"

    private init() {}

    /// Automatically discovers and resolves the current project metadata from the active session or open files.
    public func resolveActiveProject() throws -> ResolvedProjectMetadata {
        if let active = activeProjectURL {
            return try resolveProject(at: active)
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if let ancestor = findWorkspaceAncestor(of: cwd.appendingPathComponent("dummy.swift")) {
            return try resolveProject(at: ancestor)
        }

        if FileManager.default.fileExists(atPath: cwd.appendingPathComponent("Package.swift").path) {
            return try resolveProject(at: cwd)
        }

        throw ProjectResolutionError.activeProjectNotFound
    }

    /// Resolves project metadata for an explicit root directory URL
    public func resolveProject(at rootURL: URL) throws -> ResolvedProjectMetadata {
        let fm = FileManager.default

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: rootURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw ProjectResolutionError.resolutionFailed("Resolved path '\(rootURL.path)' does not exist or is not a folder.")
        }

        let projectName = rootURL.lastPathComponent
        let packageSwiftURL = rootURL.appendingPathComponent("Package.swift")
        let isSwiftPackage = fm.fileExists(atPath: packageSwiftURL.path)

        var xcodeprojURL: URL? = nil
        var xcworkspaceURL: URL? = nil

        do {
            let files = try fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            xcodeprojURL = files.first { $0.pathExtension == "xcodeproj" }
            xcworkspaceURL = files.first { $0.pathExtension == "xcworkspace" }
        } catch {
            logger.warning("Failed to list files under resolved root URL: \(error.localizedDescription)")
        }

        let isXcodeProject = xcodeprojURL != nil
        let isXcodeWorkspace = xcworkspaceURL != nil

        let buildRootURL = rootURL.appendingPathComponent("build")

        let metadata = ResolvedProjectMetadata(
            rootURL: rootURL,
            projectName: projectName,
            isSwiftPackage: isSwiftPackage,
            isXcodeProject: isXcodeProject,
            isXcodeWorkspace: isXcodeWorkspace,
            packageSwiftURL: isSwiftPackage ? packageSwiftURL : nil,
            xcodeprojURL: xcodeprojURL,
            xcworkspaceURL: xcworkspaceURL,
            buildRootURL: buildRootURL,
            buildDestination: selectedDestination
        )

        return metadata
    }

    /// Recursively traces directories up to find active Package.swift or Xcode project files
    public func findWorkspaceAncestor(of url: URL) -> URL? {
        let fm = FileManager.default
        var currentURL = url.deletingLastPathComponent()

        while currentURL.path != "/" {
            let packageSwift = currentURL.appendingPathComponent("Package.swift")
            let projectJson = currentURL.appendingPathComponent("project.json")

            if fm.fileExists(atPath: packageSwift.path) || fm.fileExists(atPath: projectJson.path) {
                return currentURL
            }

            if let contents = try? fm.contentsOfDirectory(at: currentURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                if contents.contains(where: { $0.pathExtension == "xcodeproj" || $0.pathExtension == "xcworkspace" }) {
                    return currentURL
                }
            }

            currentURL = currentURL.deletingLastPathComponent()
        }

        return nil
    }
}
