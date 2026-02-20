import Cocoa
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let permissionsManager = PermissionsManager()
    let selectionMonitor = SelectionMonitor()
    let tooltipWindow = TooltipWindow()
    let rewriteService = RewriteService()
    let accessibilityManager = AccessibilityManager()

    private var selectedText: String = ""
    private var currentTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        permissionsManager.requestAccessibility()

        if permissionsManager.isAccessibilityGranted {
            startMonitoring()
        } else {
            permissionsManager.startPolling()
            permissionsManager.showManualInstructions()
        }

        NotificationCenter.default.addObserver(
            forName: .accessibilityPermissionGranted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.startMonitoring()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        selectionMonitor.stop()
        currentTask?.cancel()
    }

    // MARK: - Start monitoring

    private func startMonitoring() {
        selectionMonitor.start { [weak self] result in
            guard let self else { return }
            self.handleSelection(result)
        }
        Logger.permissions.info("Selection monitoring active")
    }

    // MARK: - Selection handling

    private func handleSelection(_ result: SelectionResult) {
        if tooltipWindow.isVisible && tooltipWindow.isInteracting && result.text == selectedText {
            return
        }

        currentTask?.cancel()
        currentTask = nil

        selectedText = result.text

        if tooltipWindow.isVisible {
            tooltipWindow.hide()
        }

        tooltipWindow.show(near: result.screenRect)

        tooltipWindow.onRephrase = { [weak self] in
            self?.performRephrase()
        }

        tooltipWindow.onReplace = { [weak self] text in
            self?.accessibilityManager.replaceSelectedText(with: text)
            self?.tooltipWindow.hide()
        }

        tooltipWindow.onCopy = { [weak self] text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            self?.tooltipWindow.hide()
        }

        tooltipWindow.onCancel = { [weak self] in
            self?.currentTask?.cancel()
            self?.currentTask = nil
        }

        tooltipWindow.onRetry = { [weak self] in
            self?.performRephrase()
        }
    }

    // MARK: - Rephrase

    private func performRephrase() {
        currentTask?.cancel()

        tooltipWindow.updateUI(.loading)

        let text = selectedText
        currentTask = Task {
            do {
                let result = try await rewriteService.rewrite(text: text)
                guard !Task.isCancelled else { return }
                tooltipWindow.updateUI(.result(result))
            } catch is CancellationError {
                // User cancelled — do nothing
            } catch {
                guard !Task.isCancelled else { return }
                let message = (error as? RewriteService.RewriteError)?.errorDescription ?? error.localizedDescription
                tooltipWindow.updateUI(.error(message))
            }
        }
    }
}
