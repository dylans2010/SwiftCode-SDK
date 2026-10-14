import Foundation
import SwiftCodeCore
import SwiftCodeDiagnostics

public struct ExtensionRecord: Sendable, Identifiable {
    public var id: String { manifest.id }
    public let manifest: ExtensionManifest
    public let location: URL
    public var state: ExtensionState
    public var pluginInstance: (any ExtensionPlugin)?
    public var context: ExtensionContext?

    public init(
        manifest: ExtensionManifest,
        location: URL,
        state: ExtensionState = .unloaded,
        pluginInstance: (any ExtensionPlugin)? = nil,
        context: ExtensionContext? = nil
    ) {
        self.manifest = manifest
        self.location = location
        self.state = state
        self.pluginInstance = pluginInstance
        self.context = context
    }
}

public actor ExtensionRegistry {
    public static let shared = ExtensionRegistry()
    private var extensions: [String: ExtensionRecord] = [:]

    public init() {}

    public func register(manifest: ExtensionManifest, location: URL, plugin: (any ExtensionPlugin)? = nil) {
        extensions[manifest.id] = ExtensionRecord(
            manifest: manifest,
            location: location,
            state: .loaded,
            pluginInstance: plugin
        )
    }

    public func get(extensionID: String) -> ExtensionRecord? {
        return extensions[extensionID]
    }

    public func getAll() -> [ExtensionRecord] {
        return Array(extensions.values).sorted { $0.manifest.name < $1.manifest.name }
    }

    public func updateState(extensionID: String, state: ExtensionState, context: ExtensionContext? = nil) {
        if var record = extensions[extensionID] {
            record.state = state
            if let ctx = context {
                record.context = ctx
            }
            extensions[extensionID] = record
        }
    }

    public func remove(extensionID: String) {
        extensions.removeValue(forKey: extensionID)
    }
}

public actor ExtensionHostRuntime {
    public static let shared = ExtensionHostRuntime()
    private let registry = ExtensionRegistry.shared
    private let validator = ExtensionValidator()
    private var lifecycleDelegates: [any ExtensionLifecycleDelegate] = []

    public init() {}

    public func addLifecycleDelegate(_ delegate: any ExtensionLifecycleDelegate) {
        lifecycleDelegates.append(delegate)
    }

    public func loadExtension(from folderURL: URL) async throws -> ExtensionManifest {
        let manifestURL = folderURL.appendingPathComponent("swiftcode.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw ExtensionError.manifestNotFound("swiftcode.json manifest not found at \(folderURL.path)")
        }

        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(ExtensionManifest.self, from: data)

        let diagnostics = validator.validate(manifest: manifest, packageRoot: folderURL.path)
        let errors = diagnostics.filter { $0.severity == .error }
        if !errors.isEmpty {
            throw ExtensionError.validationFailed("Extension manifest validation failed with \(errors.count) error(s): \(errors.map(\.message).joined(separator: "; "))")
        }

        await registry.register(manifest: manifest, location: folderURL)
        return manifest
    }

    public func activateExtension(extensionID: String, baseStorageURL: URL? = nil) async throws {
        guard let record = await registry.get(extensionID: extensionID) else {
            throw ExtensionError.notFound("Extension '\(extensionID)' is not registered.")
        }

        for delegate in lifecycleDelegates {
            delegate.extensionWillActivate(extensionID)
        }

        await registry.updateState(extensionID: extensionID, state: .activating)

        let storageRoot = baseStorageURL ?? FileManager.default.temporaryDirectory
        let extStorage = storageRoot.appendingPathComponent("extensions").appendingPathComponent(extensionID)
        let globalStorage = storageRoot.appendingPathComponent("global-extensions")
        let logPath = extStorage.appendingPathComponent("extension.log")

        try? FileManager.default.createDirectory(at: extStorage, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: globalStorage, withIntermediateDirectories: true)

        let context = ExtensionContext(
            extensionID: extensionID,
            manifest: record.manifest,
            extensionPath: record.location,
            storagePath: extStorage,
            globalStoragePath: globalStorage,
            logPath: logPath
        )

        do {
            if let plugin = record.pluginInstance {
                try await plugin.activate(context: context)
            }
            await registry.updateState(extensionID: extensionID, state: .active, context: context)
            for delegate in lifecycleDelegates {
                delegate.extensionDidActivate(extensionID)
            }
        } catch {
            await registry.updateState(extensionID: extensionID, state: .failed(reason: error.localizedDescription))
            for delegate in lifecycleDelegates {
                delegate.extensionDidFail(extensionID, error: error)
            }
            throw error
        }
    }

    public func deactivateExtension(extensionID: String) async throws {
        guard let record = await registry.get(extensionID: extensionID) else { return }

        for delegate in lifecycleDelegates {
            delegate.extensionWillDeactivate(extensionID)
        }

        await registry.updateState(extensionID: extensionID, state: .deactivating)

        if let plugin = record.pluginInstance, let context = record.context {
            try await plugin.deactivate(context: context)
        }
        record.context?.subscriptions.dispose()

        await registry.updateState(extensionID: extensionID, state: .deactivated)
        for delegate in lifecycleDelegates {
            delegate.extensionDidDeactivate(extensionID)
        }
    }
}
