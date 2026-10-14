import AppKit
import Foundation
import SwiftUI

// MARK: - SDKCIWorkflowViewOpener

@MainActor
public struct SDKCIWorkflowViewOpener {
    /// Capability this opener serves: `ci.VisualWF`.
    nonisolated public static let capabilityID: SDKCapabilityID = .ciVisualWF

    /// Opens the CI / visual-workflows dashboard.
    public static func open() throws {
        let metadata = try SDKActiveProjectResolver.resolve()
        NotificationCenter.default.post(
            name: NSNotification.Name("com.swiftcode.openCIWorkflow"),
            object: nil,
            userInfo: ["projectURL": metadata.rootURL]
        )
    }
}
