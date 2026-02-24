import Cocoa
import Carbon
import OSLog

@MainActor
final class HotkeyManager {
    
    typealias HotkeyCallback = () -> Void
    
    private var monitor: Any?
    var onTrigger: HotkeyCallback?
    
    func start(callback: @escaping HotkeyCallback) {
        self.onTrigger = callback
        
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            
            // Cmd+Option+J: keyCode 38 (J key)
            let requiredFlags: NSEvent.ModifierFlags = [.command, .option]
            let hasRequiredFlags = event.modifierFlags.contains(requiredFlags)
            let noExtraModifiers = !event.modifierFlags.contains(.shift) && !event.modifierFlags.contains(.control)
            
            if event.keyCode == 38 && hasRequiredFlags && noExtraModifiers {
                DispatchQueue.main.async {
                    self.onTrigger?()
                }
            }
        }
        
        Logger.hotkey.info("HotkeyManager started (Cmd+Option+J)")
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        onTrigger = nil
        Logger.hotkey.info("HotkeyManager stopped")
    }
}
