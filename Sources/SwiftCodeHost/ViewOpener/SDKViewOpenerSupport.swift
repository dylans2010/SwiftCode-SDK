import AppKit
import Foundation
import SwiftUI
import SwiftCodeModels
import SwiftCodeProjects

// MARK: - SDKViewOpenerSupport

@MainActor
enum SDKActiveProjectResolver {
    static func resolve() throws -> ResolvedProjectMetadata {
        return try ProjectResolver.shared.resolveActiveProject()
    }
}

// MARK: - SDKHostedWindow

@MainActor
public final class SDKHostedWindow<Content: View> {
    private var window: NSWindow?

    public init() {}

    public func show(rootView: Content, title: String, size: NSSize, autosaveName: String, minSize: NSSize = NSSize(width: 200, height: 200)) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = title
        win.minSize = minSize
        win.contentViewController = NSHostingController(rootView: rootView)
        win.setFrameAutosaveName(autosaveName)
        win.center()
        win.makeKeyAndOrderFront(nil)
        self.window = win
    }

    public func close() {
        window?.close()
        window = nil
    }
}
