//
//  AppDelegate.swift
//  WhisperDictation
//
//  Делегат додатка для ініціалізації сервісів.
//

import AppKit
import AVFoundation
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] Application did finish launching")
        
        // Запитуємо дозвіл на мікрофон
        requestMicrophonePermission()
        
        // Перевіряємо дозволи на Accessibility
        checkAccessibilityPermission()
        
        // Налаштовуємо KeyMonitor callbacks
        setupKeyMonitor()
        
        // Запускаємо моніторинг клавіш
        KeyMonitor.shared.start()
        
        // Ініціалізуємо OverlayWindow (але не показуємо)
        _ = OverlayWindow.shared
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("[AppDelegate] Application will terminate")
        KeyMonitor.shared.stop()
    }
    
    // MARK: - Private Methods
    
    private func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("[AppDelegate] Microphone access authorized")
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("[AppDelegate] Microphone access \(granted ? "granted" : "denied")")
            }
            
        case .denied, .restricted:
            print("[AppDelegate] Microphone access denied or restricted")
            DispatchQueue.main.async {
                self.showMicrophoneAlert()
            }
            
        @unknown default:
            break
        }
    }
    
    private func showMicrophoneAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Permission Required"
        alert.informativeText = "WhisperDictation needs microphone access to record your voice.\n\nPlease go to System Settings → Privacy & Security → Microphone and enable WhisperDictation."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !isTrusted {
            print("[AppDelegate] WARNING: Accessibility permissions not granted")
            // Don't show alert immediately on startup, but log it
            // The alert will be shown when user tries to use text injection
        } else {
            print("[AppDelegate] Accessibility permissions granted")
        }
    }
    
    private func setupKeyMonitor() {
        let keyMonitor = KeyMonitor.shared
        
        keyMonitor.onOptionDown = { [weak self] in
            self?.handleOptionDown()
        }
        
        keyMonitor.onOptionUp = { [weak self] in
            self?.handleOptionUp()
        }
    }
    
    private func handleOptionDown() {
        print("[AppDelegate] Option key pressed")
        
        // Перевіряємо чи є API ключ
        guard APIKeyStore.shared.hasValidKey else {
            print("[AppDelegate] No API key configured, skipping recording")
            showNoAPIKeyAlert()
            return
        }
        
        // Перевіряємо чи вже не йде транскрибування
        guard DictationUIState.shared.phase != .transcribing else {
            print("[AppDelegate] Transcribing in progress, ignoring")
            return
        }
        
        // Показуємо вікно (якщо ще не показано)
        OverlayWindow.shared.show()
        
        // Починаємо анімацію появи (продовжує з поточного прогресу)
        // Це також створює нову сесію
        DictationUIState.shared.startOverlayAppear()
        
        // Завжди встановлюємо phase в .recording
        DictationUIState.shared.phase = .recording
        
        // Завжди намагаємось почати запис - AudioRecorder сам вирішить чи можна
        let currentSession = DictationUIState.shared.sessionID
        AudioRecorder.shared.start(session: currentSession)
    }
    
    private func handleOptionUp() {
        print("[AppDelegate] Option key released")
        
        // Запам'ятовуємо сесію з AudioRecorder (це та сесія, яка реально записується)
        let recorderSession = AudioRecorder.shared.activeSession
        
        // Починаємо анімацію зникнення (незалежно від фази)
        DictationUIState.shared.startOverlayDisappear()
        
        // Перевіряємо чи був запис
        guard DictationUIState.shared.phase == .recording else {
            print("[AppDelegate] Not in recording phase, ignoring stop")
            return
        }
        
        // Зупиняємо запис - AudioRecorder сам визначить чи транскрибувати
        AudioRecorder.shared.stopAndTranscribe(session: recorderSession)
    }
    
    private func showNoAPIKeyAlert() {
        let alert = NSAlert()
        alert.messageText = "API Key Required"
        alert.informativeText = "Please configure your OpenAI API key in the menu bar settings before using voice dictation."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

