import Cocoa
import OSLog

@MainActor
final class ServiceProvider: NSObject {
    
    private weak var appDelegate: AppDelegate?
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
    }
    
    @objc func rephraseText(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>?) {
        guard let text = pboard.string(forType: .string),
              !text.isEmpty else {
            Logger.services.warning("Service called with no text")
            error?.pointee = "No text provided" as NSString
            return
        }
        
        Logger.services.info("Service: rephrase text (\(text.count) chars)")
        
        Task { @MainActor in
            await appDelegate?.handleServiceRephrase(text: text, pasteboard: pboard)
        }
    }
    
    @objc func openEditorWithText(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>?) {
        let text = pboard.string(forType: .string)
        
        Logger.services.info("Service: open editor with text (\(text?.count ?? 0) chars)")
        
        Task { @MainActor in
            if let text = text, !text.isEmpty {
                appDelegate?.openEditorWithText(text)
            } else {
                appDelegate?.openEditor()
            }
        }
    }
}
