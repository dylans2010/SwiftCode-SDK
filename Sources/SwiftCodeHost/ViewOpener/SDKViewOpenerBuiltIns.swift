import Foundation

// MARK: - SDKViewOpener built-in openers

extension SDKViewOpener {

    private static let notificationBridges: [(viewID: SDKCapabilityID, toolID: String)] = [
        (.deviceConnectOpen, "deviceConnect"),
        (.simulatorView, "simulatorMain"),
        (.symbolsBrowse, "sfSymbolsBrowser"),
        (.sandboxView, "terminal"),
        (.deployConsoleView, "deployments"),
    ]

    public func registerBuiltInOpeners() async throws {
        // --- 1. Native AppKit windows: post host notifications ---
        register(viewID: .dbExploreView) {
            NotificationCenter.default.post(name: NSNotification.Name("com.swiftcode.openDatabaseExplorer"), object: nil)
        }

        register(viewID: .docsSearch) {
            NotificationCenter.default.post(name: NSNotification.Name("com.swiftcode.openDocumentationBrowser"), object: nil)
        }

        register(viewID: .dictionaryOpen) {
            NotificationCenter.default.post(name: NSNotification.Name("com.swiftcode.openCodingDictionary"), object: nil)
        }

        register(viewID: .uiBuilderOpen) {
            NotificationCenter.default.post(name: NSNotification.Name("com.swiftcode.openVisualUIBuilder"), object: nil)
        }

        // --- 2. Sheet views: the app's toolbar notification path ---
        for bridge in Self.notificationBridges {
            let toolID = bridge.toolID
            register(viewID: bridge.viewID) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("com.swiftcode.toolbarToolActivated"),
                    object: nil,
                    userInfo: ["toolID": toolID]
                )
            }
        }

        // --- 3. Sibling openers: CI workflows, virtualization, live preview ---
        register(viewID: SDKCIWorkflowViewOpener.capabilityID) {
            try SDKCIWorkflowViewOpener.open()
        }
        register(viewID: SDKVirtualizationViewOpener.capabilityID) {
            try SDKVirtualizationViewOpener.open()
        }
        register(viewID: SDKLivePreviewViewOpener.capabilityID) {
            try SDKLivePreviewViewOpener.open()
        }
    }
}
