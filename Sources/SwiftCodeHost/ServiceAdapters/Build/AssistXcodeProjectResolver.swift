import Foundation

/// Resolves the *user's* Xcode project for Assist tools and Build Service.
public enum AssistXcodeProjectResolver {

    /// A located Xcode project or workspace belonging to the user.
    public struct LocatedProject: Sendable {
        public let url: URL
        public let isWorkspace: Bool

        /// Project name without extension, e.g. "MyApp".
        public var name: String { url.deletingPathExtension().lastPathComponent }

        /// The `xcodebuild -project/-workspace` argument pair.
        public var xcodebuildArgs: [String] {
            isWorkspace ? ["-workspace", url.path] : ["-project", url.path]
        }

        /// The `project.pbxproj` inside the bundle (nil for workspaces that
        /// wrap multiple projects; callers should handle that case).
        public var pbxprojURL: URL? {
            guard !isWorkspace else { return nil }
            let pbx = url.appendingPathComponent("project.pbxproj")
            return FileManager.default.fileExists(atPath: pbx.path) ? pbx : nil
        }
    }

    // MARK: - Locate

    /// Finds the user's `.xcworkspace` or `.xcodeproj` at the top level of
    /// `workspaceRoot`. Prefers a workspace over a project. Returns nil when
    /// no project bundle is present.
    public static func locate(in workspaceRoot: URL) -> LocatedProject? {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: workspaceRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let workspaces = entries.filter { $0.pathExtension == "xcworkspace" }
        let projects = entries.filter { $0.pathExtension == "xcodeproj" }

        if let ws = workspaces.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first {
            return LocatedProject(url: ws, isWorkspace: true)
        }
        if let proj = projects.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first {
            return LocatedProject(url: proj, isWorkspace: false)
        }
        return nil
    }

    /// Resolves a workspace-relative project path supplied by the caller
    public static func locate(relativePath: String, in workspaceRoot: URL) -> LocatedProject? {
        let url = workspaceRoot.appendingPathComponent(relativePath)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        switch url.pathExtension {
        case "xcworkspace": return LocatedProject(url: url, isWorkspace: true)
        case "xcodeproj": return LocatedProject(url: url, isWorkspace: false)
        default: return nil
        }
    }

    // MARK: - Scheme

    /// Resolves the scheme to build: explicit parameter wins, otherwise the
    /// first scheme reported by `xcodebuild -list -json`, otherwise the
    /// project bundle's base name.
    public static func resolveScheme(for project: LocatedProject, explicit: String?) async -> String {
        if let explicit, !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicit
        }
        if let listed = await firstListedScheme(for: project) {
            return listed
        }
        return project.name
    }

    private static func firstListedScheme(for project: LocatedProject) async -> String? {
        #if os(macOS)
        let xcodebuild = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        guard FileManager.default.fileExists(atPath: xcodebuild.path) else { return nil }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = xcodebuild
                process.arguments = project.xcodebuildArgs + ["-list", "-json"]
                process.currentDirectoryURL = project.url.deletingLastPathComponent()

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    guard process.terminationStatus == 0,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        continuation.resume(returning: nil)
                        return
                    }

                    if let proj = json["project"] as? [String: Any],
                       let schemes = proj["schemes"] as? [String], let first = schemes.first {
                        continuation.resume(returning: first)
                        return
                    }
                    if let ws = json["workspace"] as? [String: Any],
                       let schemes = ws["schemes"] as? [String], let first = schemes.first {
                        continuation.resume(returning: first)
                        return
                    }
                    continuation.resume(returning: nil)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
        #else
        return nil
        #endif
    }

    // MARK: - pbxproj introspection

    private struct PbxGroup {
        let id: String
        let pathComponent: String?
        let children: [String]
    }

    private static func parseGroups(in pbxproj: String) -> [String: PbxGroup] {
        var groups: [String: PbxGroup] = [:]
        let pattern = #"^\t\t([0-9A-Fa-f]{24}) /\* [^*]*? \*/ = \{\n\s*isa = PBXGroup;\n\s*children = \(\s*(.*?)\s*\);(?:\n\s*(?:path|name) = "?([^";\n]+)"?;)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .dotMatchesLineSeparators]) else {
            return groups
        }
        let range = NSRange(pbxproj.startIndex..., in: pbxproj)
        for match in regex.matches(in: pbxproj, range: range) {
            guard let idRange = Range(match.range(at: 1), in: pbxproj),
                  let childrenRange = Range(match.range(at: 2), in: pbxproj) else { continue }
            let id = String(pbxproj[idRange])
            let childrenBlock = String(pbxproj[childrenRange])
            let childPattern = #"^\s*([0-9A-Fa-f]{24}) /\*"#
            let childRegex = try? NSRegularExpression(pattern: childPattern, options: .anchorsMatchLines)
            var children: [String] = []
            if let childRegex {
                let cRange = NSRange(childrenBlock.startIndex..., in: childrenBlock)
                for cm in childRegex.matches(in: childrenBlock, range: cRange) {
                    if let cr = Range(cm.range(at: 1), in: childrenBlock) {
                        children.append(String(childrenBlock[cr]))
                    }
                }
            }
            var pathComponent: String?
            if match.range(at: 3).location != NSNotFound,
               let pr = Range(match.range(at: 3), in: pbxproj) {
                pathComponent = String(pbxproj[pr])
            }
            groups[id] = PbxGroup(id: id, pathComponent: pathComponent, children: children)
        }
        return groups
    }

    public static func groupID(forFileDirectory fileDir: String, inPbxproj pbxproj: String) -> String? {
        let groups = parseGroups(in: pbxproj)
        guard !groups.isEmpty else { return nil }

        var parentOf: [String: String] = [:]
        for (id, group) in groups {
            for child in group.children where groups[child] != nil {
                parentOf[child] = id
            }
        }
        func fullPath(of id: String) -> String {
            var components: [String] = []
            var current: String? = id
            var guardCount = 0
            while let c = current, let g = groups[c], guardCount < 64 {
                guardCount += 1
                if let pc = g.pathComponent, !pc.isEmpty { components.append(pc) }
                current = parentOf[c]
            }
            return components.reversed().joined(separator: "/")
        }

        let normalized = fileDir.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var best: (id: String, depth: Int)?
        for (id, _) in groups {
            let p = fullPath(of: id)
            guard !p.isEmpty else { continue }
            if p == normalized {
                return id
            }
            if normalized.hasPrefix(p + "/") || normalized == p {
                let depth = p.count
                if best == nil || depth > best!.depth {
                    best = (id, depth)
                }
            }
        }
        return best?.id
    }

    public static func sourcesBuildPhaseID(inPbxproj pbxproj: String) -> String? {
        let pattern = #"^\t\t([0-9A-Fa-f]{24}) /\* Sources \*/ = \{\s*isa = PBXSourcesBuildPhase;"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
              let match = regex.firstMatch(in: pbxproj, range: NSRange(pbxproj.startIndex..., in: pbxproj)),
              let r = Range(match.range(at: 1), in: pbxproj) else {
            return nil
        }
        return String(pbxproj[r])
    }
}
