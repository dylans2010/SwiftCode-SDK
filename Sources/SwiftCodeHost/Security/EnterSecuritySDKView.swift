import Foundation
import SwiftUI
import SwiftCodeCore

// MARK: - EnterSecuritySDKView
//
// The native macOS popup where the USER types a secret so an app
// (extension) can have it stored in its private Keychain namespace without
// ever seeing the plaintext (the `security.addValue` flow, spec
// `SDK/Documentation/Security-Keychain.md` §"The secure-prompt entry flow").
//
// PRESENTED BY THE HOST ONLY — never by extension code. Extensions run
// out-of-process and cannot reach this type; `SDKSensitiveValuePrompt` is
// the only presenter, and it is called from host-owned code (the IPC layer
// or Studio).

public struct EnterSecuritySDKView: View {

    // MARK: - Request (host-supplied)

    private let securityID: String
    private let appDisplayName: String
    private let valueID: String
    private let label: String?
    private let prompt: String?

    // MARK: - Outcome (payload-free)

    private let onStored: () -> Void
    private let onCancelled: () -> Void

    // MARK: - State (view-local)

    @State private var secret = ""
    @State private var storeError: SDKError?
    @State private var isStoring = false
    @State private var replacesExistingValue = false
    @FocusState private var secretFieldFocused: Bool

    public init(
        securityID: String,
        appDisplayName: String,
        valueID: String,
        label: String?,
        prompt: String?,
        onStored: @escaping () -> Void,
        onCancelled: @escaping () -> Void
    ) {
        self.securityID = securityID
        self.appDisplayName = appDisplayName
        self.valueID = valueID
        self.label = label
        self.prompt = prompt
        self.onStored = onStored
        self.onCancelled = onCancelled
    }

    private var isBlankInput: Bool {
        secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayLabel: String {
        if let label = label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return label
        }
        return "Secret Value"
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            requestingApp

            if let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(prompt)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            secretField

            if replacesExistingValue {
                Label(
                    label != nil ? "A value is already stored for “\(displayLabel)” — storing replaces it." : "A secret value is already stored for this item — storing replaces it.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            if let storeError {
                inlineError(storeError)
            }

            Spacer(minLength: 8)

            Divider()

            buttons
        }
        .padding(28)
        .frame(minWidth: 520, minHeight: 480, alignment: .top)
        .onAppear {
            secretFieldFocused = true
            replacesExistingValue =
                (try? KeychainSDK.hasValue(securityID: securityID, valueID: valueID)) ?? false
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "key.fill")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text("Store a Secret")
                    .font(.title2)
                    .bold()
                Text(label != nil ? "\(appDisplayName) wants to store “\(displayLabel)”" : "\(appDisplayName) wants to store a secret")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var requestingApp: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Requesting app")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(appDisplayName)
                .font(.headline)
            Text("The extension will never see this value — SwiftCode stores it in the Mac’s Keychain under this app’s private namespace, and only uses it for the operations you approve.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var secretField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayLabel)
                .font(.headline)
            SecureField("Type or paste the secret", text: $secret)
                .focused($secretFieldFocused)
                .disabled(isStoring)
                .accessibilityLabel(Text(displayLabel))
        }
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button("Cancel") { cancel() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .disabled(isStoring)

            Spacer()

            Button("Store") { store() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isBlankInput || isStoring)
        }
    }

    private func inlineError(_ error: SDKError) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(error.message)
                    .font(.callout)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
            }
            .foregroundStyle(.red)
            if let suggestion = error.suggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(error.correlationId)
                .font(.caption2)
                .monospaced()
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private func store() {
        storeError = nil
        guard !isBlankInput else {
            storeError = SDKError(
                code: .invalidArgument,
                message: "Enter a value before storing it.",
                suggestion: "Type or paste the secret into the field above, then press Store."
            )
            return
        }
        guard !isStoring else { return }
        isStoring = true
        defer { isStoring = false }

        do {
            try KeychainSDK.addValue(
                securityID: securityID,
                valueID: valueID,
                data: Data(secret.utf8),
                label: label
            )
            secret = ""
            onStored()
        } catch let sdkError as SDKError {
            storeError = sdkError
        } catch {
            storeError = SDKError(
                code: .serviceUnavailable,
                message: "Could not store the secret.",
                suggestion: "The macOS Keychain could not be reached. Check that the Keychain is unlocked and try again."
            )
        }
    }

    private func cancel() {
        secret = ""
        onCancelled()
    }
}
