# SwiftCode SDK

Official Swift SDK and Extension Development Kit for **SwiftCode**.

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform macOS 14+](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg)](https://apple.com)
[![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## Overview

The **SwiftCode SDK** enables developers to build extensions, integrate workspace and project inspection services, invoke sandboxed build pipelines, manage source control repositories, query structured diagnostics, and interface with host services provided by the SwiftCode IDE.

---

## Installation & Integration

### Swift Package Manager

Add the package dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dylans2010/SwiftCode-SDK.git", from: "1.0.0")
]
```

Then import `SwiftCode` in your target:

```swift
import SwiftCode

let coordinator = SwiftCodeSDKCoordinator()
let doctorReport = coordinator.doctor.diagnose()
print("SDK Version: \(SDKVersion.current)")
```

---

## Modular Targets

When using `import SwiftCode`, all underlying SDK modules are re-exported. If fine-grained imports are preferred, you can import individual targets:

- `SwiftCodeCore` — Base logger, diff engine, text buffer algorithms, syntax tokenizers.
- `SwiftCodeModels` — Core domain models (`Project`, `FileNode`, `AppSettings`, etc.).
- `SwiftCodeDiagnostics` — Structured diagnostic engine and formatting.
- `SwiftCodeWorkspace` — Sandboxed workspace path resolution and file access.
- `SwiftCodeProjects` — Project scaffolding, inspection, and validation.
- `SwiftCodeBuild` — Process-level build orchestration and toolchain discovery.
- `SwiftCodeSourceControl` — Git repository discovery, status, and diffs.
- `SwiftCodeExtensions` — Manifest parsing, schema validation, and package creation.
- `SwiftCodeAI` — Local and remote model provider abstractions.
- `SwiftCodeHost` — IPC transport, security keychain, and capability broker contracts.

---

## Command Line Interface (`swiftcode-sdk`)

The SDK includes a built-in CLI executable for development and CI automation:

```bash
# Environment diagnostic check
swiftcode-sdk doctor

# Initialize a new project or extension from template
swiftcode-sdk init typescript-extension MyExtension

# Validate an extension manifest
swiftcode-sdk validate ./MyExtension

# Build a project or extension
swiftcode-sdk build ./MyExtension

# Package an extension into .swiftcode-extension
swiftcode-sdk package ./MyExtension --out ./dist
```

---

## TypeScript SDK & Extensions

For TypeScript extension developers, the package includes `@swiftcode/sdk` in `TypeScript/package`:

```typescript
import type { SwiftCodeExtension, SwiftCodeContext } from "@swiftcode/sdk";

export function activate(context: SwiftCodeContext) {
  context.commands.registerCommand("myext.inspect", async () => {
    const project = await context.workspace.getCurrentProject();
    console.log("Current Project:", project?.name);
  });
}
```

---

## Architecture & Execution Modes

1. **Standalone Mode:** Operations such as project inspection, manifest validation, local git commands, and code formatting run directly without needing the SwiftCode host app.
2. **Host-Integrated Mode:** Operations such as cloud model queries, terminal virtualization, and UI view openers communicate over IPC with the active SwiftCode host application. Unhandled operations return explicit `SDKError` codes (e.g., `SDKErrorCode.serviceUnavailable`).

---

## Documentation & References

See the detailed guides in the `Documentation/` directory:
- [SDK Architecture](Documentation/SDK-Architecture.md)
- [Extension Manifest Specification](Documentation/Extension-Manifest.md)
- [Capabilities & Permissions](Documentation/Capabilities-and-Permissions.md)
- [TypeScript Extensions](Documentation/TypeScript-Extensions.md)
- [Runtime & Security Model](Documentation/Runtime-and-Security.md)

---

## License

MIT License. See [LICENSE](LICENSE) for details.
