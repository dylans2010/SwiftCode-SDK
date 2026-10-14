import Foundation

public enum ExtensionEvent: Sendable {
    case workspaceOpened(path: String)
    case workspaceClosed(path: String)
    case documentSaved(fileURL: URL)
    case documentOpened(fileURL: URL)
    case documentClosed(fileURL: URL)
    case buildStarted(scheme: String)
    case buildCompleted(scheme: String, success: Bool)
    case gitStatusChanged(repositoryPath: String)
    case custom(name: String, payload: [String: String])

    public var eventName: String {
        switch self {
        case .workspaceOpened: return "workspace.opened"
        case .workspaceClosed: return "workspace.closed"
        case .documentSaved: return "document.saved"
        case .documentOpened: return "document.opened"
        case .documentClosed: return "document.closed"
        case .buildStarted: return "build.started"
        case .buildCompleted: return "build.completed"
        case .gitStatusChanged: return "git.statusChanged"
        case .custom(let name, _): return "custom.\(name)"
        }
    }
}

public typealias ExtensionEventListener = @Sendable (ExtensionEvent) -> Void

public final class ExtensionEventBus: @unchecked Sendable {
    public static let shared = ExtensionEventBus()
    private var listeners: [UUID: ExtensionEventListener] = [:]
    private let lock = NSLock()

    public init() {}

    public func subscribe(_ listener: @escaping ExtensionEventListener) -> ExtensionDisposable {
        let id = UUID()
        lock.lock()
        listeners[id] = listener
        lock.unlock()

        return ExtensionAnyDisposable { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            self.listeners.removeValue(forKey: id)
            self.lock.unlock()
        }
    }

    public func publish(_ event: ExtensionEvent) {
        lock.lock()
        let handlers = Array(listeners.values)
        lock.unlock()

        for handler in handlers {
            handler(event)
        }
    }
}
