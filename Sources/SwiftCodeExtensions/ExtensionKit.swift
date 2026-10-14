import Foundation
import SwiftCodeCore
import SwiftCodeDiagnostics

// MARK: - ExtensionKit Namespace
public enum ExtensionKit {}

// MARK: - Extension Errors
public enum ExtensionError: Error, LocalizedError, Sendable {
    case notFound(String)
    case validationFailed(String)
    case executionFailed(String)
    case manifestNotFound(String)
    case invalidManifest(String)
    case activationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let msg): return "Extension not found: \(msg)"
        case .validationFailed(let msg): return "Extension validation failed: \(msg)"
        case .executionFailed(let msg): return "Extension execution failed: \(msg)"
        case .manifestNotFound(let msg): return "Manifest not found: \(msg)"
        case .invalidManifest(let msg): return "Invalid manifest: \(msg)"
        case .activationFailed(let msg): return "Extension activation failed: \(msg)"
        }
    }
}

// MARK: - Extension Lifecycle States
public enum ExtensionState: Sendable, Equatable {
    case unloaded
    case loaded
    case activating
    case active
    case deactivating
    case deactivated
    case failed(reason: String)

    public var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}

// MARK: - Extension Disposable & Subscriptions
public protocol ExtensionDisposable: Sendable {
    func dispose()
}

public final class ExtensionAnyDisposable: ExtensionDisposable, @unchecked Sendable {
    private let onDispose: @Sendable () -> Void
    private var isDisposed = false
    private let lock = NSLock()

    public init(_ onDispose: @escaping @Sendable () -> Void) {
        self.onDispose = onDispose
    }

    public func dispose() {
        lock.lock()
        defer { lock.unlock() }
        guard !isDisposed else { return }
        isDisposed = true
        onDispose()
    }
}

public final class ExtensionSubscriptions: ExtensionDisposable, @unchecked Sendable {
    private var disposables: [ExtensionDisposable] = []
    private let lock = NSLock()
    private var isDisposed = false

    public init() {}

    public func add(_ disposable: ExtensionDisposable) {
        lock.lock()
        defer { lock.unlock() }
        if isDisposed {
            disposable.dispose()
        } else {
            disposables.append(disposable)
        }
    }

    public func dispose() {
        lock.lock()
        let items = disposables
        disposables.removeAll()
        isDisposed = true
        lock.unlock()

        for item in items {
            item.dispose()
        }
    }
}

// MARK: - Extension Environment
public struct ExtensionEnvironment: Codable, Sendable, Equatable {
    public let hostVersion: String
    public let appName: String
    public let osVersion: String
    public let isDarkMode: Bool
    public let activeWorkspacePath: String?

    public init(
        hostVersion: String = "1.0.0",
        appName: String = "SwiftCode",
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        isDarkMode: Bool = true,
        activeWorkspacePath: String? = nil
    ) {
        self.hostVersion = hostVersion
        self.appName = appName
        self.osVersion = osVersion
        self.isDarkMode = isDarkMode
        self.activeWorkspacePath = activeWorkspacePath
    }
}

// MARK: - Extension Context
public final class ExtensionContext: Sendable {
    public let extensionID: String
    public let manifest: ExtensionManifest
    public let extensionPath: URL
    public let storagePath: URL
    public let globalStoragePath: URL
    public let logPath: URL
    public let subscriptions: ExtensionSubscriptions
    public let environment: ExtensionEnvironment
    public let commands: ExtensionCommandRegistry
    public let views: ExtensionViewRegistry
    public let events: ExtensionEventBus
    public let diagnostics: ExtensionDiagnosticRegistry
    public let assist: ExtensionAssistRegistry
    public let configuration: ExtensionConfigurationStore

    public init(
        extensionID: String,
        manifest: ExtensionManifest,
        extensionPath: URL,
        storagePath: URL,
        globalStoragePath: URL,
        logPath: URL,
        environment: ExtensionEnvironment = ExtensionEnvironment(),
        commands: ExtensionCommandRegistry = ExtensionCommandRegistry.shared,
        views: ExtensionViewRegistry = ExtensionViewRegistry.shared,
        events: ExtensionEventBus = ExtensionEventBus.shared,
        diagnostics: ExtensionDiagnosticRegistry = ExtensionDiagnosticRegistry.shared,
        assist: ExtensionAssistRegistry = ExtensionAssistRegistry.shared,
        configuration: ExtensionConfigurationStore = ExtensionConfigurationStore.shared
    ) {
        self.extensionID = extensionID
        self.manifest = manifest
        self.extensionPath = extensionPath
        self.storagePath = storagePath
        self.globalStoragePath = globalStoragePath
        self.logPath = logPath
        self.subscriptions = ExtensionSubscriptions()
        self.environment = environment
        self.commands = commands
        self.views = views
        self.events = events
        self.diagnostics = diagnostics
        self.assist = assist
        self.configuration = configuration
    }
}

// MARK: - Extension Plugin Protocol
public protocol ExtensionPlugin: AnyObject, Sendable {
    var manifest: ExtensionManifest { get }
    func activate(context: ExtensionContext) async throws
    func deactivate(context: ExtensionContext) async throws
}

public extension ExtensionPlugin {
    func deactivate(context: ExtensionContext) async throws {
        context.subscriptions.dispose()
    }
}

// MARK: - Extension Lifecycle Delegate
public protocol ExtensionLifecycleDelegate: AnyObject, Sendable {
    func extensionWillActivate(_ extensionID: String)
    func extensionDidActivate(_ extensionID: String)
    func extensionWillDeactivate(_ extensionID: String)
    func extensionDidDeactivate(_ extensionID: String)
    func extensionDidFail(_ extensionID: String, error: Error)
}
