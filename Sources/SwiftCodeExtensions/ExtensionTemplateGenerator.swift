import Foundation

public struct ExtensionTemplateGenerator {
    public enum TemplateKind: String, Sendable, CaseIterable {
        case typescript = "typescript"
        case javascript = "javascript"
        case nativePlugin = "native-plugin"
    }

    public static func generateTemplate(
        name: String,
        id: String,
        kind: TemplateKind = .typescript,
        destinationDirectory: URL
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let manifestBuilder = ExtensionManifestBuilder(id: id, name: name)
            .description("A custom SwiftCode extension")
            .addCapability(.workspaceRead, reason: "Inspect open workspace files")
            .addCommand(id: "\(id).hello", title: "Say Hello from \(name)")

        let manifestData = try manifestBuilder.buildJSONData()
        let manifestURL = destinationDirectory.appendingPathComponent("swiftcode.json")
        try manifestData.write(to: manifestURL)

        switch kind {
        case .typescript:
            let srcDir = destinationDirectory.appendingPathComponent("src")
            try fileManager.createDirectory(at: srcDir, withIntermediateDirectories: true)
            let indexTS = """
            import * as swiftcode from '@swiftcode/sdk';

            export async function activate(context: swiftcode.ExtensionContext) {
                console.log('Extension \(name) is active');
                context.commands.registerCommand('\(id).hello', async () => {
                    console.log('Hello from \(name)!');
                });
            }

            export async function deactivate() {
                console.log('Extension \(name) deactivated');
            }
            """
            try indexTS.write(to: srcDir.appendingPathComponent("index.ts"), atomically: true, encoding: .utf8)

            let packageJSON = """
            {
              "name": "\(id)",
              "version": "1.0.0",
              "description": "SwiftCode extension \(name)",
              "main": "dist/index.js",
              "scripts": {
                "build": "tsc"
              },
              "devDependencies": {
                "typescript": "^5.0.0"
              }
            }
            """
            try packageJSON.write(to: destinationDirectory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        case .javascript:
            let distDir = destinationDirectory.appendingPathComponent("dist")
            try fileManager.createDirectory(at: distDir, withIntermediateDirectories: true)
            let indexJS = """
            const swiftcode = require('@swiftcode/sdk');

            exports.activate = async function(context) {
                console.log('Extension \(name) activated');
            };

            exports.deactivate = async function() {};
            """
            try indexJS.write(to: distDir.appendingPathComponent("index.js"), atomically: true, encoding: .utf8)

        case .nativePlugin:
            let pluginSwift = """
            import Foundation
            import SwiftCode

            public final class \(name.replacingOccurrences(of: " ", with: ""))Plugin: ExtensionPlugin {
                public let manifest: ExtensionManifest

                public init(manifest: ExtensionManifest) {
                    self.manifest = manifest
                }

                public func activate(context: ExtensionContext) async throws {
                    context.commands.registerCommand(id: "\(id).hello", title: "Hello from Native Plugin") { _ in
                        return AnySendable("Hello from native SwiftCode extension!")
                    }
                }
            }
            """
            try pluginSwift.write(to: destinationDirectory.appendingPathComponent("Plugin.swift"), atomically: true, encoding: .utf8)
        }
    }
}
