import Cocoa
import ApplicationServices
import OSLog
import SelectedTextKit
import IOKit.hid

struct SelectionResult {
    let text: String
    let selectionBounds: CGRect      // Full selection bounds (from AX API or fallback)
    let firstLineBounds: CGRect      // Bounds of first line (for multi-line selections)
    let fallbackPoint: CGPoint       // Mouse position as fallback
    let hasPreciseBounds: Bool       // Whether we got real AX bounds or using fallback
    
    /// The position where tooltip should appear (left edge of first line)
    var tooltipAnchorPoint: CGPoint {
        if hasPreciseBounds {
            // Left edge of the first line, vertically centered
            return CGPoint(
                x: firstLineBounds.minX,
                y: firstLineBounds.midY
            )
        } else {
            // Fallback to mouse position
            return fallbackPoint
        }
    }
    
    /// Height of the selection's first line (for vertical alignment)
    var lineHeight: CGFloat {
        return hasPreciseBounds ? firstLineBounds.height : 20
    }
}

@MainActor
final class SelectionMonitor {

    typealias SelectionCallback = (SelectionResult) -> Void

    private var callback: SelectionCallback?
    private var tapThread: Thread?
    private var machPort: CFMachPort?
    private var pendingWork: DispatchWorkItem?
    private var lastMousePosition: CGPoint = .zero
    private var healthCheckTimer: Timer?
    
    private let textManager = SelectedTextManager.shared
    private let accessibilityManager = AccessibilityManager()

    func start(callback: @escaping SelectionCallback) {
        self.callback = callback
        
        let isTrusted = AXIsProcessTrusted()
        let inputMonitoringStatus = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        let hasInputMonitoring = (inputMonitoringStatus == kIOHIDAccessTypeGranted)
        
        NSLog("👁️ SelectionMonitor.start()")
        NSLog("   Accessibility: %d", isTrusted ? 1 : 0)
        NSLog("   Input Monitoring: %d (status: %d)", hasInputMonitoring ? 1 : 0, inputMonitoringStatus.rawValue)
        
        Logger.selection.info("SelectionMonitor starting — AXIsProcessTrusted: \(isTrusted), InputMonitoring: \(hasInputMonitoring) (status: \(inputMonitoringStatus.rawValue))")
        
        if !hasInputMonitoring {
            NSLog("   ⚠️ Input Monitoring not granted - requesting...")
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            NSLog("   Request result: %d", granted ? 1 : 0)
        }
        
        // Delay tap installation slightly to help with Launch Services timing issues
        NSLog("   ⏳ Will install event tap in 0.5s...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startEventTap()
        }
        
        observeSessionChanges()
        startHealthChecks()
    }

    func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        
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
    
    // MARK: - Health Checks (verify tap is still working)
    
    private func startHealthChecks() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.verifyTapHealth()
            }
        }
        Logger.selection.info("Started tap health checks (every 5s)")
    }
    
    private func verifyTapHealth() {
        guard let port = machPort else {
            Logger.selection.warning("Health check: No event tap exists, reinstalling...")
            reinstallEventTap()
            return
        }
        
        if !CGEvent.tapIsEnabled(tap: port) {
            Logger.selection.warning("Health check: Tap is disabled, attempting to re-enable...")
            CGEvent.tapEnable(tap: port, enable: true)
            
            // Check again after re-enable attempt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, let currentPort = self.machPort else { return }
                if !CGEvent.tapIsEnabled(tap: currentPort) {
                    Logger.selection.error("Health check: Tap still disabled after re-enable, reinstalling...")
                    self.reinstallEventTap()
                } else {
                    Logger.selection.info("Health check: Tap successfully re-enabled")
                }
            }
        }
    }
    
    private func reinstallEventTap() {
        Logger.selection.info("Reinstalling event tap...")
        
        if let port = machPort {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        machPort = nil
        tapThread?.cancel()
        tapThread = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startEventTap()
        }
    }

    // MARK: - CGEventTap (runs on background thread)

    private func startEventTap(retryCount: Int = 0) {
        NSLog("👁️ startEventTap() called (retry: %d)", retryCount)
        
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
                        NSLog("👁️ Event tap disabled by timeout - re-enabling")
                        DispatchQueue.main.async {
                            monitor.reEnableTapIfNeeded()
                        }
                        return Unmanaged.passRetained(event)
                    }

                    if type == .leftMouseUp {
                        NSLog("👁️ Mouse up detected!")
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
                    NSLog("❌ Failed to create CGEventTap — Accessibility: %d, retry: %d", isTrusted ? 1 : 0, retryCount)
                    Logger.selection.error("Failed to create CGEventTap — AXIsProcessTrusted: \(isTrusted), retry: \(retryCount)")
                    
                    if retryCount < 3 {
                        NSLog("   Retrying in 1 second...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            monitor.startEventTap(retryCount: retryCount + 1)
                        }
                    } else {
                        NSLog("❌ Giving up on event tap after 3 retries")
                    }
                }
                return
            }

            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            
            let isEnabled = CGEvent.tapIsEnabled(tap: tap)

            DispatchQueue.main.async {
                monitor.machPort = tap
                NSLog("✅ CGEventTap created! Enabled: %d", isEnabled ? 1 : 0)
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
                
                // Try to get precise selection bounds from Accessibility API
                let result: SelectionResult
                if let bounds = accessibilityManager.getSelectionBounds() {
                    Logger.selection.info("Got precise selection bounds: \(String(describing: bounds.rect))")
                    result = SelectionResult(
                        text: trimmedText,
                        selectionBounds: bounds.rect,
                        firstLineBounds: bounds.firstLineRect,
                        fallbackPoint: appKitMousePos,
                        hasPreciseBounds: true
                    )
                } else {
                    // Fallback to mouse position
                    Logger.selection.info("Using mouse position as fallback for bounds")
                    let fallbackRect = CGRect(x: appKitMousePos.x, y: appKitMousePos.y, width: 1, height: 20)
                    result = SelectionResult(
                        text: trimmedText,
                        selectionBounds: fallbackRect,
                        firstLineBounds: fallbackRect,
                        fallbackPoint: appKitMousePos,
                        hasPreciseBounds: false
                    )
                }
                
                Logger.selection.info("Got selected text via SelectedTextKit (\(trimmedText.count) chars)")
                callback?(result)
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
