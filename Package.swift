// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftCode-SDK",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // The unified SwiftCode framework: import SwiftCode provides everything (ExtensionKit, SourceControl, Projects, Build, etc.)
        .library(name: "SwiftCode", targets: ["SwiftCode"]),

        // Tool Executables
        .executable(name: "swiftcode-sdk", targets: ["CLI"]),
        .executable(name: "project-generator", targets: ["ProjectGenerator"]),
        .executable(name: "project-inspector", targets: ["ProjectInspector"]),
        .executable(name: "extension-validator", targets: ["ExtensionValidator"]),
        .executable(name: "diagnostics", targets: ["DiagnosticsTool"]),
        .executable(name: "documentation-indexer", targets: ["DocumentationIndexer"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        .package(url: "https://github.com/JohnSundell/Splash.git", from: "0.16.0"),
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "SwiftCodeCore",
            dependencies: [],
            path: "Sources/SwiftCodeCore"
        ),
        .target(
            name: "SwiftCodeModels",
            dependencies: ["SwiftCodeCore"],
            path: "Sources/SwiftCodeModels"
        ),
        .target(
            name: "SwiftCodeDiagnostics",
            dependencies: ["SwiftCodeCore"],
            path: "Sources/SwiftCodeDiagnostics"
        ),
        .target(
            name: "SwiftCodeWorkspace",
            dependencies: ["SwiftCodeCore", "SwiftCodeDiagnostics"],
            path: "Sources/SwiftCodeWorkspace"
        ),
        .target(
            name: "SwiftCodeProjects",
            dependencies: [
                "SwiftCodeCore",
                "SwiftCodeModels",
                "SwiftCodeWorkspace",
                "SwiftCodeDiagnostics",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Sources/SwiftCodeProjects"
        ),
        .target(
            name: "SwiftCodeBuild",
            dependencies: ["SwiftCodeCore", "SwiftCodeModels", "SwiftCodeDiagnostics", "SwiftCodeWorkspace"],
            path: "Sources/SwiftCodeBuild"
        ),
        .target(
            name: "SwiftCodeSourceControl",
            dependencies: ["SwiftCodeCore", "SwiftCodeDiagnostics", "SwiftCodeWorkspace"],
            path: "Sources/SwiftCodeSourceControl"
        ),
        .target(
            name: "SwiftCodeExtensions",
            dependencies: [
                "SwiftCodeCore",
                "SwiftCodeDiagnostics",
                "SwiftCodeWorkspace",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Sources/SwiftCodeExtensions",
            resources: [
                .copy("Resources")
            ]
        ),
        .target(
            name: "SwiftCodeAI",
            dependencies: ["SwiftCodeCore", "SwiftCodeModels", "SwiftCodeDiagnostics"],
            path: "Sources/SwiftCodeAI"
        ),
        .target(
            name: "SwiftCodeHost",
            dependencies: [
                "SwiftCodeCore",
                "SwiftCodeModels",
                "SwiftCodeDiagnostics",
                "SwiftCodeWorkspace",
                "SwiftCodeProjects",
                "SwiftCodeBuild",
                "SwiftCodeSourceControl",
                "SwiftCodeExtensions",
                "SwiftCodeAI"
            ],
            path: "Sources/SwiftCodeHost",
            exclude: [
                "Contracts/Manifest/ExampleManifests/repository-build-extension.swiftcode.json",
                "Contracts/Manifest/swiftcode-extension-v1.schema.json",
                "Internal/SDKConfigStore/SwiftCodeSDK.json",
                "ServiceAdapters/Terminal/sandbox_validation_test.py"
            ]
        ),
        // Primary facade module: import SwiftCode
        .target(
            name: "SwiftCode",
            dependencies: [
                "SwiftCodeCore",
                "SwiftCodeModels",
                "SwiftCodeDiagnostics",
                "SwiftCodeWorkspace",
                "SwiftCodeProjects",
                "SwiftCodeBuild",
                "SwiftCodeSourceControl",
                "SwiftCodeExtensions",
                "SwiftCodeAI",
                "SwiftCodeHost"
            ],
            path: "Sources/SwiftCode"
        ),

        // Executable Targets
        .executableTarget(
            name: "CLI",
            dependencies: ["SwiftCode"],
            path: "Sources/CLI"
        ),
        .executableTarget(
            name: "ProjectGenerator",
            dependencies: ["SwiftCodeProjects", "SwiftCode"],
            path: "Sources/Tools/ProjectGenerator"
        ),
        .executableTarget(
            name: "ProjectInspector",
            dependencies: ["SwiftCodeProjects", "SwiftCode"],
            path: "Sources/Tools/ProjectInspector"
        ),
        .executableTarget(
            name: "ExtensionValidator",
            dependencies: ["SwiftCodeExtensions", "SwiftCode"],
            path: "Sources/Tools/ExtensionValidator"
        ),
        .executableTarget(
            name: "DiagnosticsTool",
            dependencies: ["SwiftCodeDiagnostics", "SwiftCode"],
            path: "Sources/Tools/DiagnosticsTool"
        ),
        .executableTarget(
            name: "DocumentationIndexer",
            dependencies: ["SwiftCodeWorkspace", "SwiftCode"],
            path: "Sources/Tools/DocumentationIndexer"
        ),

        // Tests
        .testTarget(
            name: "SwiftCodeTests",
            dependencies: ["SwiftCode"],
            path: "Tests/SwiftCodeTests"
        )
    ]
)
