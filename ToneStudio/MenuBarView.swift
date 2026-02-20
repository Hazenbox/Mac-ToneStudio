import SwiftUI
import ServiceManagement

struct MenuBarView: View {
    @EnvironmentObject var permissionsManager: PermissionsManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showingApiKeyInput = false
    @State private var apiKeyText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusSection
            Divider()
            apiKeySection
            Divider()
            settingsSection
            Divider()
            quitSection
        }
        .padding(4)
        .frame(width: 240)
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(permissionsManager.isAccessibilityGranted ? .green : .yellow)
                .frame(width: 8, height: 8)
            Text(permissionsManager.isAccessibilityGranted ? "Active" : "Needs Permission")
                .font(.system(size: 12))
            Spacer()
            Text("v1.0")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        Group {
            if showingApiKeyInput {
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack {
                        SecureField("Enter API key", text: $apiKeyText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        Button("Save") {
                            if !apiKeyText.isEmpty {
                                KeychainHelper.save(key: apiKeyText)
                                showingApiKeyInput = false
                            }
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            } else {
                Button {
                    apiKeyText = KeychainHelper.load() ?? ""
                    showingApiKeyInput = true
                } label: {
                    HStack {
                        Image(systemName: "key")
                        Text("Configure API Key...")
                        Spacer()
                        if KeychainHelper.load() != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 10))
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 12))
                .onChange(of: launchAtLogin) { _, newValue in
                    toggleLaunchAtLogin(newValue)
                }

            if !permissionsManager.isAccessibilityGranted {
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text("Grant Accessibility...")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Quit

    private var quitSection: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            HStack {
                Image(systemName: "power")
                Text("Quit Tone Studio")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Launch at login

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = !enabled
        }
    }
}
