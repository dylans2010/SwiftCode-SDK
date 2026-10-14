import AppKit
import Foundation
import SwiftUI

// MARK: - SDKLivePreviewViewOpener

@MainActor
public struct SDKLivePreviewViewOpener {
    /// Capability this opener serves: `preview.live`.
    nonisolated public static let capabilityID: SDKCapabilityID = .previewLive

    /// Opens the live SwiftUI preview surface.
    public static func open() throws {
        NotificationCenter.default.post(
            name: NSNotification.Name("com.swiftcode.openLivePreview"),
            object: nil
        )
    }
}
