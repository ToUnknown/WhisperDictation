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
    
    private var previousContents: PasteboardContents?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func insert(text: String) {
        // Переконуємося що працюємо на main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.insert(text: text) }
            return
        }
        
        // Перевіряємо дозволи на Accessibility
        guard hasAccessibilityPermissions() else {
            print("[TextInjector] ERROR: Accessibility permissions not granted")
            showAccessibilityPermissionAlert()
            DictationUIState.shared.reset()
            OverlayWindow.shared.hide()
            return
        }
        
        let pasteboard = NSPasteboard.general
        
        // Зберігаємо поточний вміст буфера обміну
        previousContents = savePasteboardContents(pasteboard)
        
        // Очищаємо і записуємо новий текст
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Невелика затримка перед вставкою
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            // Симулюємо Cmd+V
            self?.simulatePaste()
            
            // Відновлюємо попередній вміст буфера через затримку
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                if let contents = self?.previousContents {
                    self?.restorePasteboardContents(pasteboard, contents: contents)
                    self?.previousContents = nil
                }
                
                // Завершуємо - скидаємо стан і ховаємо overlay
                DictationUIState.shared.reset()
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
        // Створюємо події для Cmd+V
        let source = CGEventSource(stateID: .combinedSessionState)
        
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
        
        // Відправляємо події
        cmdDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)
        
        print("[TextInjector] Paste simulated")
    }
    
    // MARK: - Pasteboard Backup/Restore
    
    private struct PasteboardContents {
        var items: [[NSPasteboard.PasteboardType: Data]] = []
    }
    
    private func savePasteboardContents(_ pasteboard: NSPasteboard) -> PasteboardContents {
        var contents = PasteboardContents()
        
        guard let items = pasteboard.pasteboardItems else {
            return contents
        }
        
        for item in items {
            var itemData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData[type] = data
                }
            }
            if !itemData.isEmpty {
                contents.items.append(itemData)
            }
        }
        
        return contents
    }
    
    private func restorePasteboardContents(_ pasteboard: NSPasteboard, contents: PasteboardContents) {
        guard !contents.items.isEmpty else { return }
        
        pasteboard.clearContents()
        
        for itemData in contents.items {
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }
}
