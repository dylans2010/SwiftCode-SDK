import Foundation
import SwiftCodeDiagnostics

public final class ExtensionManifestBuilder {
    private var id: String
    private var name: String
    private var version: String = "1.0.0"
    private var descriptionText: String?
    private var type: String = "extension"
    private var language: String = "typescript"
    private var entrypoint: String = "dist/index.js"
    private var minimumSwiftCodeVersion: String = "1.0.0"
    private var capabilities: [ExtensionCapabilityDeclaration] = []
    private var commands: [ExtensionCommandContribution] = []
    private var assistRequested: Bool = false

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    @discardableResult
    public func version(_ version: String) -> Self {
        self.version = version
        return self
    }

    @discardableResult
    public func description(_ description: String) -> Self {
        self.descriptionText = description
        return self
    }

    @discardableResult
    public func runtime(language: String = "typescript", entrypoint: String = "dist/index.js", minimumSwiftCodeVersion: String = "1.0.0") -> Self {
        self.language = language
        self.entrypoint = entrypoint
        self.minimumSwiftCodeVersion = minimumSwiftCodeVersion
        return self
    }

    @discardableResult
    public func addCapability(_ id: ExtensionCapabilityID, reason: String) -> Self {
        self.capabilities.append(ExtensionCapabilityDeclaration(id: id.rawValue, reason: reason))
        return self
    }

    @discardableResult
    public func addCapability(id: String, reason: String) -> Self {
        self.capabilities.append(ExtensionCapabilityDeclaration(id: id, reason: reason))
        return self
    }

    @discardableResult
    public func addCommand(id: String, title: String) -> Self {
        self.commands.append(ExtensionCommandContribution(id: id, title: title))
        return self
    }

    @discardableResult
    public func requestAssist(_ requested: Bool = true) -> Self {
        self.assistRequested = requested
        return self
    }

    public func build() -> ExtensionManifest {
        let runtime = ExtensionRuntime(language: language, entrypoint: entrypoint, minimumSwiftCodeVersion: minimumSwiftCodeVersion)
        let sdk = ExtensionSDKRef()
        let contributes = commands.isEmpty ? nil : ExtensionContributions(commands: commands)
        let assist = ExtensionAssist(requested: assistRequested)

        return ExtensionManifest(
            manifestVersion: 1,
            id: id,
            name: name,
            version: version,
            description: descriptionText,
            type: type,
            runtime: runtime,
            sdk: sdk,
            capabilities: capabilities,
            contributes: contributes,
            assist: assist
        )
    }

    public func buildJSONData() throws -> Data {
        let manifest = build()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }
}
