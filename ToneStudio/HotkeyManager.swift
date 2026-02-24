import Cocoa
import HotKey
import OSLog

@MainActor
final class HotkeyManager {
    
    typealias HotkeyCallback = () -> Void
    
    private var rephraseHotKey: HotKey?
    private var editorHotKey: HotKey?
    
    var onTrigger: HotkeyCallback?
    var onEditorTrigger: HotkeyCallback?
    
    func start(callback: @escaping HotkeyCallback, editorCallback: @escaping HotkeyCallback) {
        self.onTrigger = callback
        self.onEditorTrigger = editorCallback
        
        // Control+Option+R for quick rephrase
        rephraseHotKey = HotKey(key: .r, modifiers: [.control, .option])
        rephraseHotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.onTrigger?()
            }
        }
        
        // Cmd+Shift+J for editor
        editorHotKey = HotKey(key: .j, modifiers: [.command, .shift])
        editorHotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.onEditorTrigger?()
            }
        }
        
        Logger.hotkey.info("HotkeyManager started (Control+Option+R for rephrase, Cmd+Shift+J for editor)")
    }
    
    func stop() {
        rephraseHotKey = nil
        editorHotKey = nil
        onTrigger = nil
        onEditorTrigger = nil
        Logger.hotkey.info("HotkeyManager stopped")
    }
}
