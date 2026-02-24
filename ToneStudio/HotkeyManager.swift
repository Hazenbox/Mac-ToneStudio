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
            
            let hasCmd = event.modifierFlags.contains(.command)
            let hasOption = event.modifierFlags.contains(.option)
            let hasShift = event.modifierFlags.contains(.shift)
            let hasControl = event.modifierFlags.contains(.control)
            
            // Space key = keyCode 49: Cmd+Option+Space - Quick rephrase
            if event.keyCode == 49 && hasCmd && hasOption && !hasShift && !hasControl {
                DispatchQueue.main.async {
                    self.onTrigger?()
                }
                return
            }
            
            // J key = keyCode 38: Cmd+Shift+J - Open editor
            if event.keyCode == 38 && hasCmd && hasShift && !hasOption && !hasControl {
                DispatchQueue.main.async {
                    self.onEditorTrigger?()
                }
                return
            }
        }
        
        Logger.hotkey.info("HotkeyManager started (Cmd+Option+Space for rephrase, Cmd+Shift+J for editor)")
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
