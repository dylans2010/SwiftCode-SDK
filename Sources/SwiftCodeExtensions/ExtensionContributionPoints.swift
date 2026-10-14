import Foundation
import SwiftCodeCore
import SwiftCodeDiagnostics

// MARK: - AnySendable Helper
public struct AnySendable: @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }
}

// MARK: - Extension Commands & Command Registry
public typealias ExtensionCommandHandler = @Sendable ([String: AnySendable]) async throws -> AnySendable?

public final class ExtensionCommandRegistry: @unchecked Sendable {
    public static let shared = ExtensionCommandRegistry()
    private var handlers: [String: ExtensionCommandHandler] = [:]
    private var contributions: [String: ExtensionCommandContribution] = [:]
    private let lock = NSLock()

    public init() {}

    public func registerCommand(
        id: String,
        title: String,
        handler: @escaping ExtensionCommandHandler
    ) -> ExtensionDisposable {
        lock.lock()
        handlers[id] = handler
        contributions[id] = ExtensionCommandContribution(id: id, title: title)
        lock.unlock()

        return ExtensionAnyDisposable { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            self.handlers.removeValue(forKey: id)
            self.contributions.removeValue(forKey: id)
            self.lock.unlock()
        }
    }

    private func getHandler(for id: String) -> ExtensionCommandHandler? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[id]
    }

    public func executeCommand(id: String, parameters: [String: AnySendable] = [:]) async throws -> AnySendable? {
        guard let handler = getHandler(for: id) else {
            throw ExtensionError.executionFailed("Command '\(id)' is not registered.")
        }
        return try await handler(parameters)
    }

    public func getRegisteredCommands() -> [ExtensionCommandContribution] {
        lock.lock()
        defer { lock.unlock() }
        return Array(contributions.values).sorted { $0.id < $1.id }
    }
}

// MARK: - Extension View Locations & Custom View Providers
public enum ExtensionViewLocation: String, Codable, Sendable, CaseIterable {
    case sidebar = "sidebar"
    case inspector = "inspector"
    case editorTab = "editorTab"
    case bottomPanel = "bottomPanel"
    case statusBar = "statusBar"
    case overlay = "overlay"
}

public struct ExtensionViewContribution: Codable, Sendable, Equatable, Identifiable {
    public var id: String { viewID }
    public let viewID: String
    public let title: String
    public let location: ExtensionViewLocation
    public let iconSystemName: String?
    public let priority: Int

    public init(
        viewID: String,
        title: String,
        location: ExtensionViewLocation = .sidebar,
        iconSystemName: String? = nil,
        priority: Int = 100
    ) {
        self.viewID = viewID
        self.title = title
        self.location = location
        self.iconSystemName = iconSystemName
        self.priority = priority
    }
}

public struct ExtensionViewDescriptor: Sendable {
    public enum ViewType: String, Sendable {
        case nativeSwiftUI
        case webContent
        case terminalView
    }

    public let id: String
    public let title: String
    public let viewType: ViewType
    public let initialPayload: [String: String]

    public init(id: String, title: String, viewType: ViewType = .nativeSwiftUI, initialPayload: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.viewType = viewType
        self.initialPayload = initialPayload
    }
}

public protocol ExtensionCustomViewProvider: Sendable {
    func createViewDescriptor(viewID: String, context: ExtensionContext) async throws -> ExtensionViewDescriptor
}

public final class ExtensionViewRegistry: @unchecked Sendable {
    public static let shared = ExtensionViewRegistry()
    private var providers: [String: ExtensionCustomViewProvider] = [:]
    private var viewContributions: [String: ExtensionViewContribution] = [:]
    private let lock = NSLock()

    public init() {}

    public func registerView(
        contribution: ExtensionViewContribution,
        provider: ExtensionCustomViewProvider
    ) -> ExtensionDisposable {
        lock.lock()
        viewContributions[contribution.viewID] = contribution
        providers[contribution.viewID] = provider
        lock.unlock()

        return ExtensionAnyDisposable { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            self.viewContributions.removeValue(forKey: contribution.viewID)
            self.providers.removeValue(forKey: contribution.viewID)
            self.lock.unlock()
        }
    }

    public func getViewProvider(for viewID: String) -> ExtensionCustomViewProvider? {
        lock.lock()
        defer { lock.unlock() }
        return providers[viewID]
    }

    public func getViews(in location: ExtensionViewLocation) -> [ExtensionViewContribution] {
        lock.lock()
        defer { lock.unlock() }
        return viewContributions.values.filter { $0.location == location }.sorted { $0.priority > $1.priority }
    }
}

// MARK: - Extension Menus and Keybindings
public enum ExtensionMenuLocation: String, Codable, Sendable {
    case file = "menu.file"
    case edit = "menu.edit"
    case view = "menu.view"
    case tools = "menu.tools"
    case sourceControl = "menu.sourceControl"
    case contextMenu = "editor.context"
    case editorTitle = "editor.title"
}

public struct ExtensionMenuContribution: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(location.rawValue).\(commandID)" }
    public let location: ExtensionMenuLocation
    public let title: String
    public let commandID: String
    public let group: String?
    public let order: Int

    public init(location: ExtensionMenuLocation, title: String, commandID: String, group: String? = nil, order: Int = 100) {
        self.location = location
        self.title = title
        self.commandID = commandID
        self.group = group
        self.order = order
    }
}

public struct ExtensionKeybindingContribution: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(commandID):\(keyCombination)" }
    public let commandID: String
    public let keyCombination: String // e.g. "cmd+shift+p"
    public let macCombination: String?
    public let whenCondition: String? // e.g. "editorTextFocus"

    public init(commandID: String, keyCombination: String, macCombination: String? = nil, whenCondition: String? = nil) {
        self.commandID = commandID
        self.keyCombination = keyCombination
        self.macCombination = macCombination
        self.whenCondition = whenCondition
    }
}

// MARK: - Extension Settings & Configuration Store
public struct ExtensionSettingContribution: Codable, Sendable, Equatable, Identifiable {
    public var id: String { key }
    public let key: String
    public let title: String
    public let settingType: String // "string", "boolean", "integer", "number"
    public let defaultValue: String
    public let description: String

    public init(key: String, title: String, settingType: String, defaultValue: String, description: String) {
        self.key = key
        self.title = title
        self.settingType = settingType
        self.defaultValue = defaultValue
        self.description = description
    }
}

public final class ExtensionConfigurationStore: @unchecked Sendable {
    public static let shared = ExtensionConfigurationStore()
    private var values: [String: String] = [:]
    private var schemas: [String: ExtensionSettingContribution] = [:]
    private let lock = NSLock()

    public init() {}

    public func registerSetting(_ schema: ExtensionSettingContribution) {
        lock.lock()
        schemas[schema.key] = schema
        if values[schema.key] == nil {
            values[schema.key] = schema.defaultValue
        }
        lock.unlock()
    }

    public func get<T>(_ key: String, as type: T.Type = String.self) -> T? {
        lock.lock()
        defer { lock.unlock() }
        let raw = values[key] ?? schemas[key]?.defaultValue
        guard let raw = raw else { return nil }

        if type == Bool.self {
            return (raw.lowercased() == "true") as? T
        } else if type == Int.self {
            return Int(raw) as? T
        } else if type == Double.self {
            return Double(raw) as? T
        } else if type == String.self {
            return raw as? T
        }
        return nil
    }

    public func set(_ key: String, value: String) {
        lock.lock()
        values[key] = value
        lock.unlock()
    }
}

// MARK: - Extension Diagnostics Provider
public protocol ExtensionDiagnosticProvider: Sendable {
    func provideDiagnostics(for fileURL: URL) async throws -> [Diagnostic]
}

public final class ExtensionDiagnosticRegistry: @unchecked Sendable {
    public static let shared = ExtensionDiagnosticRegistry()
    private var providers: [ExtensionDiagnosticProvider] = []
    private let lock = NSLock()

    public init() {}

    public func registerProvider(_ provider: ExtensionDiagnosticProvider) -> ExtensionDisposable {
        lock.lock()
        providers.append(provider)
        lock.unlock()

        return ExtensionAnyDisposable { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            self.providers.removeAll { ($0 as AnyObject) === (provider as AnyObject) }
            self.lock.unlock()
        }
    }

    private func getProviders() -> [ExtensionDiagnosticProvider] {
        lock.lock()
        defer { lock.unlock() }
        return providers
    }

    public func collectDiagnostics(for fileURL: URL) async -> [Diagnostic] {
        let currentProviders = getProviders()

        var results: [Diagnostic] = []
        for provider in currentProviders {
            if let diags = try? await provider.provideDiagnostics(for: fileURL) {
                results.append(contentsOf: diags)
            }
        }
        return results
    }
}

// MARK: - Extension Assist & AI Providers
public struct ExtensionAssistContext: Sendable {
    public let documentURL: URL
    public let documentContent: String
    public let cursorLine: Int
    public let cursorColumn: Int
    public let selectedText: String?

    public init(documentURL: URL, documentContent: String, cursorLine: Int, cursorColumn: Int, selectedText: String? = nil) {
        self.documentURL = documentURL
        self.documentContent = documentContent
        self.cursorLine = cursorLine
        self.cursorColumn = cursorColumn
        self.selectedText = selectedText
    }
}

public struct ExtensionAssistCompletion: Codable, Sendable, Equatable {
    public let label: String
    public let detail: String?
    public let insertText: String
    public let sortPriority: Int

    public init(label: String, detail: String? = nil, insertText: String, sortPriority: Int = 100) {
        self.label = label
        self.detail = detail
        self.insertText = insertText
        self.sortPriority = sortPriority
    }
}

public struct ExtensionAssistCodeAction: Codable, Sendable, Equatable {
    public let title: String
    public let kind: String // "quickfix", "refactor"
    public let commandID: String?

    public init(title: String, kind: String = "quickfix", commandID: String? = nil) {
        self.title = title
        self.kind = kind
        self.commandID = commandID
    }
}

public struct ExtensionAssistHover: Codable, Sendable, Equatable {
    public let markdownContent: String

    public init(markdownContent: String) {
        self.markdownContent = markdownContent
    }
}

public protocol ExtensionAssistProvider: Sendable {
    func provideCompletions(context: ExtensionAssistContext) async throws -> [ExtensionAssistCompletion]
    func provideCodeActions(context: ExtensionAssistContext) async throws -> [ExtensionAssistCodeAction]
    func provideHover(context: ExtensionAssistContext) async throws -> ExtensionAssistHover?
}

public extension ExtensionAssistProvider {
    func provideCompletions(context: ExtensionAssistContext) async throws -> [ExtensionAssistCompletion] { return [] }
    func provideCodeActions(context: ExtensionAssistContext) async throws -> [ExtensionAssistCodeAction] { return [] }
    func provideHover(context: ExtensionAssistContext) async throws -> ExtensionAssistHover? { return nil }
}

public final class ExtensionAssistRegistry: @unchecked Sendable {
    public static let shared = ExtensionAssistRegistry()
    private var providers: [ExtensionAssistProvider] = []
    private let lock = NSLock()

    public init() {}

    public func registerProvider(_ provider: ExtensionAssistProvider) -> ExtensionDisposable {
        lock.lock()
        providers.append(provider)
        lock.unlock()

        return ExtensionAnyDisposable { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            self.providers.removeAll { ($0 as AnyObject) === (provider as AnyObject) }
            self.lock.unlock()
        }
    }

    private func getProviders() -> [ExtensionAssistProvider] {
        lock.lock()
        defer { lock.unlock() }
        return providers
    }

    public func getCompletions(context: ExtensionAssistContext) async -> [ExtensionAssistCompletion] {
        let activeProviders = getProviders()

        var items: [ExtensionAssistCompletion] = []
        for provider in activeProviders {
            if let completions = try? await provider.provideCompletions(context: context) {
                items.append(contentsOf: completions)
            }
        }
        return items.sorted { $0.sortPriority > $1.sortPriority }
    }
}
