import Cocoa
import HotKey
import OSLog

@MainActor
final class HotkeyManager {
    
    typealias HotkeyCallback = () -> Void
    
    private var rephraseHotKey: HotKey?
    private var editorHotKey: HotKey?
    private var stressTestHotKey: HotKey?
    
    var onTrigger: HotkeyCallback?
    var onEditorTrigger: HotkeyCallback?
    var onStressTestTrigger: HotkeyCallback?
    
    func start(callback: @escaping HotkeyCallback, editorCallback: @escaping HotkeyCallback) {
        self.onTrigger = callback
        self.onEditorTrigger = editorCallback
        
        NSLog("🔑 HotkeyManager.start() - registering hotkeys...")
        
        // Control+Option+R for quick rephrase
        rephraseHotKey = HotKey(key: .r, modifiers: [.control, .option])
        rephraseHotKey?.keyDownHandler = { [weak self] in
            NSLog("🔑 Control+Option+R pressed!")
            DispatchQueue.main.async {
                self?.onTrigger?()
            }
        }
        NSLog("   ✓ Registered Control+Option+R for rephrase")
        
        // Cmd+Shift+J for editor
        editorHotKey = HotKey(key: .j, modifiers: [.command, .shift])
        editorHotKey?.keyDownHandler = { [weak self] in
            NSLog("🔑 Cmd+Shift+J pressed!")
            DispatchQueue.main.async {
                self?.onEditorTrigger?()
            }
        }
        NSLog("   ✓ Registered Cmd+Shift+J for editor")
        
        // Cmd+Shift+T for stress tests (debug)
        stressTestHotKey = HotKey(key: .t, modifiers: [.command, .shift, .control])
        stressTestHotKey?.keyDownHandler = { [weak self] in
            NSLog("🔑 Cmd+Shift+Control+T pressed - Running Stress Tests!")
            DispatchQueue.main.async {
                self?.onStressTestTrigger?()
            }
        }
        NSLog("   ✓ Registered Cmd+Shift+Control+T for stress tests")
        
        Logger.hotkey.info("HotkeyManager started (Control+Option+R for rephrase, Cmd+Shift+J for editor)")
    }
    
    func stop() {
        rephraseHotKey = nil
        editorHotKey = nil
        stressTestHotKey = nil
        onTrigger = nil
        onEditorTrigger = nil
        onStressTestTrigger = nil
        Logger.hotkey.info("HotkeyManager stopped")
    }
    
    func setStressTestCallback(_ callback: @escaping HotkeyCallback) {
        self.onStressTestTrigger = callback
    }
}
