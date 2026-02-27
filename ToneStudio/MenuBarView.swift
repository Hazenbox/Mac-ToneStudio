import SwiftUI

// MARK: - No Hover Button Style

struct NoHoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
    }
}

struct MenuBarView: View {
    @EnvironmentObject var permissionsManager: PermissionsManager
    @State private var showingApiKeyInput = false
    @State private var apiKeyText = ""
    
    var onRestartMonitoring: (() -> Void)?
    var onOpenEditor: (() -> Void)?
    
    private let iconLabelSpacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 10
    private let verticalPadding: CGFloat = 6
    private let iconSize: CGFloat = 12
    private let iconContainerWidth: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            openToneStudioSection
            
            Divider()
            
            configurationSection
            
            Divider()
            
            utilitiesSection
        }
        .padding(6)
        .frame(width: 240)
    }

    // MARK: - Open Tone Studio (First Option)
    
    private var openToneStudioSection: some View {
        Button {
            onOpenEditor?()
        } label: {
            HStack(spacing: iconLabelSpacing) {
                Image("StatusBarIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconContainerWidth, height: iconSize)
                Text("Open Tone Studio")
                    .font(.system(size: iconSize))
                Spacer()
                Text("⌘⇧J")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(NoHoverButtonStyle())
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
    }

    // MARK: - Configuration (API Key)

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showingApiKeyInput {
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: iconLabelSpacing) {
                        SecureField("Enter API Key", text: $apiKeyText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: iconSize))
                        Button("Save") {
                            if !apiKeyText.isEmpty {
                                KeychainHelper.save(key: apiKeyText)
                                showingApiKeyInput = false
                            }
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            } else {
                Button {
                    apiKeyText = KeychainHelper.load() ?? ""
                    showingApiKeyInput = true
                } label: {
                    HStack(spacing: iconLabelSpacing) {
                        Image(systemName: "key")
                            .font(.system(size: iconSize))
                            .frame(width: iconContainerWidth, alignment: .center)
                        Text("Configure API Key...")
                            .font(.system(size: iconSize))
                        Spacer()
                        if KeychainHelper.load() != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 10))
                        }
                    }
                }
                .buttonStyle(NoHoverButtonStyle())
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
        }
    }

    // MARK: - Utilities (Grant Accessibility, Restart Monitoring, Quit)

    private var utilitiesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !permissionsManager.isAccessibilityGranted {
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: iconLabelSpacing) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: iconSize))
                            .frame(width: iconContainerWidth, alignment: .center)
                        Text("Grant Accessibility...")
                            .font(.system(size: iconSize))
                    }
                }
                .buttonStyle(NoHoverButtonStyle())
                .foregroundStyle(.orange)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
            
            Button {
                onRestartMonitoring?()
            } label: {
                HStack(spacing: iconLabelSpacing) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: iconSize))
                        .frame(width: iconContainerWidth, alignment: .center)
                    Text("Restart Monitoring")
                        .font(.system(size: iconSize))
                }
            }
            .buttonStyle(NoHoverButtonStyle())
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: iconLabelSpacing) {
                    Image(systemName: "power")
                        .font(.system(size: iconSize))
                        .frame(width: iconContainerWidth, alignment: .center)
                    Text("Quit Tone Studio")
                        .font(.system(size: iconSize))
                }
            }
            .buttonStyle(NoHoverButtonStyle())
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
        }
    }
}
