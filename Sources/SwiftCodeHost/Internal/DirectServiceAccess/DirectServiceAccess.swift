#if DEBUG

import Foundation
import SwiftCodeSourceControl

/// Direct handles to host services for the internal test harness and
/// Studio debug flows.
public enum DirectServiceAccess {
    /// Direct handle to the SDK's source-control service.
    public static var sourceControlService: SourceControlService {
        SourceControlService()
    }

    /// Direct URL to the pinned Xcode build tool.
    public static var xcodeBuildURL: URL {
        URL(fileURLWithPath: "/usr/bin/xcodebuild")
    }
}

#endif
