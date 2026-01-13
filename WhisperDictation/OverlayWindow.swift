//
//  OverlayWindow.swift
//  WhisperDictation
//
//  Прозоре вікно для відображення оверлею запису.
//

import AppKit
import SwiftUI

final class OverlayWindow: NSWindow {
    static let shared = OverlayWindow()
    
    private let windowWidth: CGFloat = 200
    private let windowHeight: CGFloat = 100
    
    /// Лічильник для відміни відкладеного hide
    private var showCounter: Int = 0
    
    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        configure()
    }
    
    // MARK: - Configuration
    
    private func configure() {
        // Прозорий фон
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        
        // Рівень вікна - над усіма, але під системними елементами
        level = .statusBar
        
        // Ігнорує події миші
        ignoresMouseEvents = true
        
        // Не з'являється в списку вікон
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // Анімація не потрібна для стандартної поведінки
        animationBehavior = .none
        
        // SwiftUI контент
        contentView = NSHostingView(rootView: OverlayView())
    }
    
    // MARK: - Positioning
    
    private func positionWindow() {
        // Використовуємо екран з курсором миші, або main screen як fallback
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        
        guard let screen = screen else { return }
        
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        // Точний центр екрану по ширині
        let x = screenFrame.minX + (screenFrame.width - windowWidth) / 2
        
        // Прямо під menu bar
        let y = visibleFrame.maxY - windowHeight
        
        setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
    }
    
    // MARK: - Public Methods
    
    func show() {
        // Завжди на main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.show() }
            return
        }
        
        // Збільшуємо лічильник щоб відмінити відкладений hide
        showCounter += 1
        
        positionWindow()
        alphaValue = 1
        orderFrontRegardless()
    }
    
    func hide() {
        // Завжди на main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.hide() }
            return
        }
        
        // Запам'ятовуємо поточний лічильник
        let counterAtHide = showCounter
        
        // Даємо час для анімації вильоту (але відміняємо якщо show() був викликаний)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            // Якщо show() був викликаний після hide() - не ховаємо
            if self.showCounter == counterAtHide {
                self.orderOut(nil)
            }
        }
    }
    
    /// Приховує вікно негайно без затримки
    func hideImmediately() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.hideImmediately() }
            return
        }
        
        orderOut(nil)
    }
}
