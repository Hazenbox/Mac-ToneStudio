import Cocoa
import Carbon
import OSLog

@MainActor
final class HotkeyManager {
    
    typealias HotkeyCallback = () -> Void
    
    private var monitor: Any?
    var onTrigger: HotkeyCallback?
    var onEditorTrigger: HotkeyCallback?
    
    func start(callback: @escaping HotkeyCallback, editorCallback: @escaping HotkeyCallback) {
        self.onTrigger = callback
        self.onEditorTrigger = editorCallback
        
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            
            // J key = keyCode 38
            guard event.keyCode == 38 else { return }
            
            let hasCmd = event.modifierFlags.contains(.command)
            let hasOption = event.modifierFlags.contains(.option)
            let hasShift = event.modifierFlags.contains(.shift)
            let hasControl = event.modifierFlags.contains(.control)
            
            // Cmd+Option+J (no shift, no control) - Quick rephrase
            if hasCmd && hasOption && !hasShift && !hasControl {
                DispatchQueue.main.async {
                    self.onTrigger?()
                }
                return
            }
            
            // Cmd+Shift+J (no option, no control) - Open editor
            if hasCmd && hasShift && !hasOption && !hasControl {
                DispatchQueue.main.async {
                    self.onEditorTrigger?()
                }
                return
            }
        }
        
        Logger.hotkey.info("HotkeyManager started (Cmd+Option+J for rephrase, Cmd+Shift+J for editor)")
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        onTrigger = nil
        onEditorTrigger = nil
        Logger.hotkey.info("HotkeyManager stopped")
    }
}
