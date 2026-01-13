//
//  DictationUIState.swift
//  WhisperDictation
//
//  Стан UI для диктовки: фаза та рівень звуку.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Phase Enum

enum DictationPhase: Equatable {
    case idle
    case recording
    case transcribing
}

// MARK: - UI State

final class DictationUIState: ObservableObject {
    static let shared = DictationUIState()
    
    /// Поточна фаза диктовки
    @Published var phase: DictationPhase = .idle
    
    /// Нормалізований рівень звуку 0...1 для анімації voice spikes
    @Published var level: CGFloat = 0.0
    
    /// Прогрес появи оверлею 0...1 (для haptic-style анімації)
    @Published var overlayProgress: CGFloat = 0.0
    
    /// Чи натиснута кнопка запису
    private(set) var isButtonPressed: Bool = false
    
    /// ID поточної сесії запису (для ігнорування старих операцій)
    private(set) var sessionID: Int = 0
    
    private var animationStartTime: Date?
    private var animationStartProgress: CGFloat = 0.0
    private var animationDirection: AnimationDirection = .none
    
    private let appearDuration: TimeInterval = 0.7 // Час повної появи
    private let disappearDuration: TimeInterval = 0.3 // Час зникнення
    
    private enum AnimationDirection {
        case none
        case appearing
        case disappearing
    }
    
    private init() {}
    
    /// Скидає стан до початкового (повертає true якщо скинуто)
    @discardableResult
    func reset(forSession: Int? = nil) -> Bool {
        guard Thread.isMainThread else {
            var result = false
            DispatchQueue.main.sync { result = self.reset(forSession: forSession) }
            return result
        }
        
        // Якщо вказано сесію і вона не поточна - ігноруємо
        if let requestedSession = forSession, requestedSession != sessionID {
            print("[DictationUIState] Reset ignored - old session \(requestedSession), current \(sessionID)")
            return false
        }
        
        // Якщо кнопка натиснута - не скидаємо (новий запис вже почався)
        guard !isButtonPressed else {
            print("[DictationUIState] Reset ignored - button is pressed, session \(sessionID)")
            return false
        }
        
        print("[DictationUIState] Reset executed - session \(sessionID)")
        stopAnimation()
        phase = .idle
        level = 0.0
        overlayProgress = 0.0
        return true
    }
    
    /// Примусово скидає стан (для завершення транскрибування)
    func forceReset() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.forceReset() }
            return
        }
        
        stopAnimation()
        phase = .idle
        level = 0.0
        overlayProgress = 0.0
        isButtonPressed = false
    }
    
    /// Починає анімацію появи оверлею
    func startOverlayAppear() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.startOverlayAppear() }
            return
        }
        
        // Нова сесія запису
        sessionID += 1
        print("[DictationUIState] startOverlayAppear - session \(sessionID), progress: \(overlayProgress)")
        
        isButtonPressed = true
        animationDirection = .appearing
        animationStartTime = Date()
        animationStartProgress = overlayProgress
        
        startAnimationTimer()
    }
    
    /// Починає анімацію зникнення оверлею
    func startOverlayDisappear() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.startOverlayDisappear() }
            return
        }
        
        isButtonPressed = false
        
        // Якщо вже в процесі транскрибування, не ховаємо
        guard phase != .transcribing else { return }
        
        animationDirection = .disappearing
        animationStartTime = Date()
        animationStartProgress = overlayProgress
        
        startAnimationTimer()
    }
    
    /// Фіксує оверлей на повній видимості (для транскрибування)
    func lockOverlayVisible() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.lockOverlayVisible() }
            return
        }
        
        stopAnimation()
        overlayProgress = 1.0
    }
    
    // MARK: - Animation Timer
    
    private var animationTimer: Timer?
    
    private func startAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationDirection = .none
    }
    
    private func updateAnimation() {
        guard let startTime = animationStartTime else {
            stopAnimation()
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        switch animationDirection {
        case .appearing:
            // Якщо кнопку відпустили під час появи - зупиняємо
            guard isButtonPressed else {
                stopAnimation()
                return
            }
            
            let remainingProgress = 1.0 - animationStartProgress
            let remainingDuration = appearDuration * remainingProgress
            
            guard remainingDuration > 0 else {
                overlayProgress = 1.0
                stopAnimation()
                return
            }
            
            let progress = animationStartProgress + (elapsed / remainingDuration) * remainingProgress
            
            if progress >= 1.0 {
                overlayProgress = 1.0
                stopAnimation()
            } else {
                overlayProgress = progress
            }
            
        case .disappearing:
            // Якщо кнопку натиснули знову - зупиняємо зникнення
            guard !isButtonPressed else {
                stopAnimation()
                return
            }
            
            let remainingDuration = disappearDuration * animationStartProgress
            
            guard remainingDuration > 0 else {
                overlayProgress = 0.0
                phase = .idle
                stopAnimation()
                OverlayWindow.shared.hideImmediately()
                return
            }
            
            let progress = animationStartProgress - (elapsed / remainingDuration) * animationStartProgress
            
            if progress <= 0.0 {
                overlayProgress = 0.0
                phase = .idle
                stopAnimation()
                // Ховаємо вікно негайно коли анімація зникнення завершена
                OverlayWindow.shared.hideImmediately()
            } else {
                overlayProgress = progress
            }
            
        case .none:
            stopAnimation()
        }
    }
}

