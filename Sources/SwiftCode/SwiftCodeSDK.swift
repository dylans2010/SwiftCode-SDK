import Foundation
@_exported import SwiftCodeCore
@_exported import SwiftCodeModels
@_exported import SwiftCodeDiagnostics
@_exported import SwiftCodeWorkspace
@_exported import SwiftCodeProjects
@_exported import SwiftCodeBuild
@_exported import SwiftCodeSourceControl
@_exported import SwiftCodeExtensions
@_exported import SwiftCodeAI
@_exported import SwiftCodeHost

/// SwiftCode Unified SDK Coordinator
/// Provides a single entry point for all IDE subsystems: projects, build, source control, extensions, diagnostics, and AI assist.
public final class SwiftCodeSDKCoordinator: Sendable {
    public let configuration: SDKConfiguration
    public let projectInspector: ProjectInspector
    public let projectGenerator: ProjectGenerator
    public let projectValidator: ProjectValidator
    public let buildService: BuildService
    public let sourceControl: SourceControlService
    public let git: GitService
    public let extensionValidator: ExtensionValidator
    public let extensionPackager: ExtensionPackager
    public let extensionRuntime: ExtensionHostRuntime
    public let doctor: SDKDoctor

    public init(configuration: SDKConfiguration = .standard()) {
        self.configuration = configuration
        self.projectInspector = ProjectInspector()
        self.projectGenerator = ProjectGenerator()
        self.projectValidator = ProjectValidator()
        self.buildService = BuildService()
        let sc = SourceControlService()
        self.sourceControl = sc
        self.git = GitService.shared
        self.extensionValidator = ExtensionValidator()
        self.extensionPackager = ExtensionPackager()
        self.extensionRuntime = ExtensionHostRuntime.shared
        self.doctor = SDKDoctor()
    }
}
