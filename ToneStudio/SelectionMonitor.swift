import Cocoa
import ApplicationServices
import OSLog
import SelectedTextKit

struct SelectionResult {
    let text: String
    let screenRect: CGRect
}

@MainActor
final class SelectionMonitor {

    typealias SelectionCallback = (SelectionResult) -> Void

    private var callback: SelectionCallback?
    private var tapThread: Thread?
    private var machPort: CFMachPort?
    private var pendingWork: DispatchWorkItem?
    private var lastMousePosition: CGPoint = .zero
    
    private let textManager = SelectedTextManager.shared

    func start(callback: @escaping SelectionCallback) {
        self.callback = callback
        let isTrusted = AXIsProcessTrusted()
        Logger.selection.info("SelectionMonitor starting — AXIsProcessTrusted: \(isTrusted)")
        startEventTap()
        observeSessionChanges()
    }

    func stop() {
        if let port = machPort {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        machPort = nil
        tapThread?.cancel()
        tapThread = nil
        pendingWork?.cancel()
        pendingWork = nil
        callback = nil
        Logger.selection.info("SelectionMonitor stopped")
    }

    // MARK: - CGEventTap (runs on background thread)

    private func startEventTap(retryCount: Int = 0) {
        let monitor = self
        let thread = Thread {
            let mask = CGEventMask(1 << CGEventType.leftMouseUp.rawValue)

            let refcon = Unmanaged.passUnretained(monitor).toOpaque()
            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                    guard let refcon else { return Unmanaged.passRetained(event) }
                    let monitor = Unmanaged<SelectionMonitor>.fromOpaque(refcon).takeUnretainedValue()

                    if type == .tapDisabledByTimeout {
                        DispatchQueue.main.async {
                            monitor.reEnableTapIfNeeded()
                        }
                        return Unmanaged.passRetained(event)
                    }

                    if type == .leftMouseUp {
                        let mousePos = event.location
                        DispatchQueue.main.async {
                            monitor.handleMouseUp(mousePosition: mousePos)
                        }
                    }

                    return Unmanaged.passRetained(event)
                },
                userInfo: refcon
            ) else {
                DispatchQueue.main.async {
                    let isTrusted = AXIsProcessTrusted()
                    Logger.selection.error("Failed to create CGEventTap — AXIsProcessTrusted: \(isTrusted), retry: \(retryCount)")
                    
                    if retryCount < 3 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            monitor.startEventTap(retryCount: retryCount + 1)
                        }
                    }
                }
                return
            }

            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)

            DispatchQueue.main.async {
                monitor.machPort = tap
                Logger.selection.info("CGEventTap created successfully")
            }

            CFRunLoopRun()
        }
        thread.name = "com.upen.ToneStudio.EventTap"
        thread.qualityOfService = .userInitiated
        thread.start()
        tapThread = thread
    }

    // MARK: - Session change observer (re-enable tap after screen lock)

    nonisolated private func observeSessionChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.reEnableTapIfNeeded()
            }
        }
    }

    private func reEnableTapIfNeeded() {
        guard let port = machPort else {
            Logger.selection.warning("No event tap to re-enable after session change; restarting")
            if let cb = callback {
                stop()
                start(callback: cb)
            }
            return
        }
        CGEvent.tapEnable(tap: port, enable: true)
        Logger.selection.info("Re-enabled event tap after session became active")
    }

    // MARK: - Debounce

    private func handleMouseUp(mousePosition: CGPoint) {
        lastMousePosition = mousePosition
        pendingWork?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.performTextRetrieval()
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.debounceInterval, execute: work)
    }

    // MARK: - Text retrieval using SelectedTextKit

    private func performTextRetrieval() {
        Task {
            await getSelectedTextWithMultipleStrategies()
        }
    }
    
    private func getSelectedTextWithMultipleStrategies() async {
        do {
            let strategies: [TextStrategy] = [
                .accessibility,
                .appleScript,
                .menuAction,
                .shortcut
            ]
            
            if let text = try await textManager.getSelectedText(strategies: strategies) {
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard trimmedText.count >= AppConstants.minSelectionLength,
                      trimmedText.count <= AppConstants.maxSelectionLength else {
                    Logger.selection.debug("Text length \(trimmedText.count) outside valid range")
                    return
                }
                
                let appKitMousePos = cgPointToAppKit(lastMousePosition)
                let selectionRect = CGRect(x: appKitMousePos.x, y: appKitMousePos.y, width: 1, height: 1)
                
                Logger.selection.info("Got selected text via SelectedTextKit (\(trimmedText.count) chars)")
                callback?(SelectionResult(text: trimmedText, screenRect: selectionRect))
            } else {
                Logger.selection.debug("No text selected")
            }
        } catch {
            Logger.selection.error("SelectedTextKit error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Get selected text via hotkey (for manual trigger)
    
    func getSelectedText() async -> String? {
        do {
            let strategies: [TextStrategy] = [
                .accessibility,
                .appleScript,
                .menuAction,
                .shortcut
            ]
            
            if let text = try await textManager.getSelectedText(strategies: strategies) {
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                Logger.selection.info("Got selected text on demand (\(trimmedText.count) chars)")
                return trimmedText
            }
        } catch {
            Logger.selection.error("SelectedTextKit error on demand: \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Coordinate conversion (CG top-left origin -> AppKit bottom-left origin)

    private func cgPointToAppKit(_ cgPoint: CGPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 900
        return CGPoint(x: cgPoint.x, y: primaryHeight - cgPoint.y)
    }
}
