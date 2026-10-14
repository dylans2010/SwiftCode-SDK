# Changelog

All notable changes to the **SwiftCode SDK** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-06

### Added
- Official Swift Package SPM structure supporting `import SwiftCode`.
- Modular internal architecture: `SwiftCodeCore`, `SwiftCodeModels`, `SwiftCodeDiagnostics`, `SwiftCodeWorkspace`, `SwiftCodeProjects`, `SwiftCodeBuild`, `SwiftCodeSourceControl`, `SwiftCodeExtensions`, `SwiftCodeAI`, `SwiftCodeHost`.
- Command line interface tools: `swiftcode-sdk`, `project-generator`, `project-inspector`, `extension-validator`, `diagnostics`, `documentation-indexer`.
- `@swiftcode/sdk` TypeScript package, runtime adapter, and CLI utilities.
- Comprehensive DocC and Markdown documentation for architecture, capabilities, manifest schema, and security.
- Standalone and Host-Integrated execution modes with strict capability permissions.
