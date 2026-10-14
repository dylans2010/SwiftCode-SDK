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

public final class SwiftCodeSDKCoordinator: Sendable {
    public let configuration: SDKConfiguration
    public let projectInspector: ProjectInspector
    public let projectGenerator: ProjectGenerator
    public let projectValidator: ProjectValidator
    public let buildService: BuildService
    public let sourceControl: SourceControlService
    public let extensionValidator: ExtensionValidator
    public let extensionPackager: ExtensionPackager
    public let doctor: SDKDoctor

    public init(configuration: SDKConfiguration = .standard()) {
        self.configuration = configuration
        self.projectInspector = ProjectInspector()
        self.projectGenerator = ProjectGenerator()
        self.projectValidator = ProjectValidator()
        self.buildService = BuildService()
        self.sourceControl = SourceControlService()
        self.extensionValidator = ExtensionValidator()
        self.extensionPackager = ExtensionPackager()
        self.doctor = SDKDoctor()
    }
}
