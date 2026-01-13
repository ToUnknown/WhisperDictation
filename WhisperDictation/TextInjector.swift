//
//  TextInjector.swift
//  WhisperDictation
//
//  Вставка тексту через буфер обміну та симуляцію Cmd+V.
//

import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

final class TextInjector {
    static let shared = TextInjector()
    
    private init() {}
    
    // MARK: - Public Methods
    
    func insert(text: String) {
        // Переконуємося що працюємо на main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.insert(text: text) }
            return
        }
        
        print("[TextInjector] Inserting text (\(text.count) chars): \(text.prefix(100))\(text.count > 100 ? "..." : "")")
        
        // Перевіряємо дозволи на Accessibility
        guard hasAccessibilityPermissions() else {
            print("[TextInjector] ERROR: Accessibility permissions not granted")
            showAccessibilityPermissionAlert()
            DictationUIState.shared.forceReset()
            OverlayWindow.shared.hide()
            return
        }
        
        let pasteboard = NSPasteboard.general
        
        // Очищаємо і записуємо новий текст
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        print("[TextInjector] Pasteboard set: \(success)")
        
        // Verify what's on the pasteboard
        if let pasteboardText = pasteboard.string(forType: .string) {
            print("[TextInjector] Pasteboard contains (\(pasteboardText.count) chars)")
        }
        
        // Затримка перед вставкою щоб pasteboard був готовий
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // Симулюємо Cmd+V
            self?.simulatePaste()
            
            // Завершуємо - скидаємо стан і ховаємо overlay
            // Не відновлюємо pasteboard - залишаємо текст для можливості повторної вставки
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                DictationUIState.shared.forceReset()
                OverlayWindow.shared.hide()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Перевіряє чи є дозволи на Accessibility
    private func hasAccessibilityPermissions() -> Bool {
        // Перевіряємо чи процес має довіру для Accessibility
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Показує діалог про необхідність дозволів на Accessibility
    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "WhisperDictation needs Accessibility permissions to paste transcribed text.\n\nPlease go to System Settings → Privacy & Security → Accessibility and enable WhisperDictation."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func simulatePaste() {
        // Створюємо події для Cmd+V з новим event source
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Command down
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) else {
            print("[TextInjector] Failed to create command down event")
            return
        }
        cmdDown.flags = .maskCommand
        
        // V down (keycode 9)
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else {
            print("[TextInjector] Failed to create V down event")
            return
        }
        vDown.flags = .maskCommand
        
        // V up
        guard let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            print("[TextInjector] Failed to create V up event")
            return
        }
        vUp.flags = .maskCommand
        
        // Command up
        guard let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            print("[TextInjector] Failed to create command up event")
            return
        }
        
        // Відправляємо події з невеликими затримками
        cmdDown.post(tap: .cghidEventTap)
        usleep(10000) // 10ms
        vDown.post(tap: .cghidEventTap)
        usleep(10000) // 10ms
        vUp.post(tap: .cghidEventTap)
        usleep(10000) // 10ms
        cmdUp.post(tap: .cghidEventTap)
        
        print("[TextInjector] Paste simulated with delays")
    }
}
