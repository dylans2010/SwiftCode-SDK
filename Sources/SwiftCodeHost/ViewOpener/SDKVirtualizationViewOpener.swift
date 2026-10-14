import AppKit
import Foundation
import SwiftUI

// MARK: - SDKVirtualizationViewOpener

@MainActor
public struct SDKVirtualizationViewOpener {
    /// Capability this opener serves: `virtualization.view`.
    nonisolated public static let capabilityID: SDKCapabilityID = .virtualizationView

    /// Opens the Virtualization Console surface.
    public static func open() throws {
        let metadata = try SDKActiveProjectResolver.resolve()
        NotificationCenter.default.post(
            name: NSNotification.Name("com.swiftcode.openVirtualization"),
            object: nil,
            userInfo: ["projectURL": metadata.rootURL]
        )
    }
}
