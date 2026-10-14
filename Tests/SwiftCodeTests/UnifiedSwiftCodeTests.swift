import XCTest
import SwiftCode

private final class TestBox<T>: @unchecked Sendable {
    var value: T
    private let lock = NSLock()

    init(_ value: T) {
        self.value = value
    }

    func set(_ newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        self.value = newValue
    }

    func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return self.value
    }
}

final class UnifiedSwiftCodeTests: XCTestCase {

    func testUnifiedSDKCoordinatorInitialization() {
        let coordinator = SwiftCodeSDKCoordinator()
        XCTAssertNotNil(coordinator.git)
        XCTAssertNotNil(coordinator.sourceControl)
        XCTAssertNotNil(coordinator.extensionRuntime)
        XCTAssertNotNil(coordinator.extensionValidator)
        XCTAssertNotNil(coordinator.doctor)
    }

    func testExtensionManifestDSL() throws {
        let manifest = ExtensionManifestBuilder(id: "com.swiftcode.testext", name: "Test Extension")
            .version("2.1.0")
            .description("A high-performance extension")
            .runtime(language: "typescript", entrypoint: "dist/bundle.js", minimumSwiftCodeVersion: "1.0.0")
            .addCapability(.workspaceRead, reason: "Read workspace directory contents")
            .addCapability(.sourceControlRead, reason: "Inspect Git branch and status")
            .addCommand(id: "com.swiftcode.testext.format", title: "Format Current Document")
            .requestAssist(true)
            .build()

        XCTAssertEqual(manifest.id, "com.swiftcode.testext")
        XCTAssertEqual(manifest.name, "Test Extension")
        XCTAssertEqual(manifest.version, "2.1.0")
        XCTAssertEqual(manifest.capabilities.count, 2)
        XCTAssertEqual(manifest.contributes?.commands.count, 1)
        XCTAssertTrue(manifest.assist.requested)
    }

    func testExtensionCommandRegistry() async throws {
        let registry = ExtensionCommandRegistry()
        let executed = TestBox(false)

        let disposable = registry.registerCommand(id: "test.command", title: "Test Command") { params in
            executed.set(true)
            return AnySendable("Success")
        }

        let result = try await registry.executeCommand(id: "test.command")
        XCTAssertTrue(executed.get())
        XCTAssertEqual(result?.value as? String, "Success")

        disposable.dispose()

        do {
            _ = try await registry.executeCommand(id: "test.command")
            XCTFail("Should have thrown after dispose")
        } catch {
            // Expected
        }
    }

    func testExtensionEventBus() {
        let bus = ExtensionEventBus()
        let receivedEvent = TestBox<String?>(nil)

        let disposable = bus.subscribe { event in
            receivedEvent.set(event.eventName)
        }

        bus.publish(.buildCompleted(scheme: "App", success: true))
        XCTAssertEqual(receivedEvent.get(), "build.completed")

        disposable.dispose()
        bus.publish(.workspaceOpened(path: "/tmp/project"))
        XCTAssertEqual(receivedEvent.get(), "build.completed", "Listener should not receive events after disposal")
    }

    func testExtensionTemplateGenerator() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try ExtensionTemplateGenerator.generateTemplate(
            name: "MyCustomExtension",
            id: "com.example.custom",
            kind: .typescript,
            destinationDirectory: tempDir
        )

        let manifestFile = tempDir.appendingPathComponent("swiftcode.json")
        let packageFile = tempDir.appendingPathComponent("package.json")
        let sourceFile = tempDir.appendingPathComponent("src/index.ts")

        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testGitModelsAndServiceContracts() async throws {
        let service = SourceControlService()
        XCTAssertTrue(service.isGitInstalled())

        let commit = GitCommit(
            hash: "abcdef1234567890",
            shortHash: "abcdef1",
            authorName: "Developer",
            authorEmail: "dev@example.com",
            date: Date(),
            message: "Initial commit",
            parentHashes: ["1234567"]
        )

        XCTAssertEqual(commit.author, "Developer")
        XCTAssertEqual(commit.email, "dev@example.com")
        XCTAssertEqual(commit.parentHashes.count, 1)

        let branch = GitBranch(name: "feature/unified-sdk", isCurrent: true, isRemote: false, trackingRemote: "origin/feature/unified-sdk")
        XCTAssertTrue(branch.isCurrent)
        XCTAssertFalse(branch.isRemote)
        XCTAssertEqual(branch.trackingRemote, "origin/feature/unified-sdk")

        let tag = GitTag(name: "v1.0.0", commitHash: "abcdef1", message: "Release 1.0.0")
        XCTAssertEqual(tag.name, "v1.0.0")

        let stash = GitStashItem(index: 0, hash: "stash123", message: "WIP work")
        XCTAssertEqual(stash.index, 0)
    }
}
