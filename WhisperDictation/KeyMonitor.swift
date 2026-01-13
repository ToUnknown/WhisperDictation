//
//  KeyMonitor.swift
//  WhisperDictation
//
//  Глобальний моніторинг ПРАВОЇ клавіші Option через CGEventTap.
//

import Foundation
import AppKit
import CoreGraphics

final class KeyMonitor {
    static let shared = KeyMonitor()
    
    var onOptionDown: (() -> Void)?
    var onOptionUp: (() -> Void)?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRightOptionPressed = false
    
    // Keycode для правої клавіші Option
    private let rightOptionKeyCode: Int64 = 61
    
    private init() {}
    
    // MARK: - Public Methods
    
    func start() {
        guard eventTap == nil else {
            print("[KeyMonitor] Already running")
            return
        }
        
        // Створюємо event tap для flagsChanged подій
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
        
        // Використовуємо Unmanaged для передачі self в callback
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                
                // Перевіряємо чи tap був вимкнений системою
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    print("[KeyMonitor] Event tap was disabled, re-enabling...")
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return nil
                }
                
                monitor.handleEvent(event)
                
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPointer
        ) else {
            print("[KeyMonitor] Failed to create event tap. Please grant Accessibility permissions.")
            showAccessibilityAlert()
            return
        }
        
        self.eventTap = tap
        
        // Додаємо до run loop
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        
        // Вмикаємо tap
        CGEvent.tapEnable(tap: tap, enable: true)
        
        print("[KeyMonitor] Started successfully")
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        isRightOptionPressed = false
        
        print("[KeyMonitor] Stopped")
    }
    
    // MARK: - Private Methods
    
    private func handleEvent(_ event: CGEvent) {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let optionPressed = flags.contains(.maskAlternate)
        
        // Ігноруємо якщо Option натиснутий разом з іншими модифікаторами (крім Shift)
        let otherModifiers: CGEventFlags = [.maskCommand, .maskControl]
        let hasOtherModifiers = !flags.intersection(otherModifiers).isEmpty
        
        if hasOtherModifiers {
            // Якщо Option відпущено під час комбінації - скидаємо стан
            if !optionPressed && isRightOptionPressed {
                isRightOptionPressed = false
            }
            return
        }
        
        // Перевіряємо чи це ПРАВА клавіша Option (keycode 61)
        let isRightOptionEvent = keyCode == rightOptionKeyCode
        
        if isRightOptionEvent && optionPressed && !isRightOptionPressed {
            // Права Option щойно натиснута
            isRightOptionPressed = true
            DispatchQueue.main.async { [weak self] in
                self?.onOptionDown?()
            }
        } else if !optionPressed && isRightOptionPressed {
            // Option відпущено (будь-яка, але скидаємо тільки якщо права була натиснута)
            isRightOptionPressed = false
            DispatchQueue.main.async { [weak self] in
                self?.onOptionUp?()
            }
        }
    }
    
    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "WhisperDictation needs Accessibility access to monitor the Option key globally.\n\nPlease go to System Settings → Privacy & Security → Accessibility and enable WhisperDictation."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Відкриваємо налаштування Accessibility
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
