//
//  OverlayView.swift
//  WhisperDictation
//
//  Мінімалістичний індикатор запису з аудіовізуалізатором.
//

import SwiftUI

struct OverlayView: View {
    @StateObject private var viewModel: OverlayViewModel

    init(viewModel: OverlayViewModel = OverlayViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // Розміри
    private let lineWidth: CGFloat = 120
    private let lineHeight: CGFloat = 5
    private let expandedHeight: CGFloat = 36
    private let cornerRadius: CGFloat = 18
    private let barCount = 9
    private let barWidth: CGFloat = 2.5
    private let barSpacing: CGFloat = 4
    
    // Стан для анімацій
    @State private var isVisible = false      // Контролює наявність view в ієрархії
    @State private var isShowing = false      // Контролює анімацію появи (scale/opacity)
    @State private var isExpanded = false
    @State private var barsAppeared = false
    @State private var processingOffset: CGFloat = 0
    @State private var exitOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            if isVisible {
                mainView
                    .offset(y: exitOffset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 20)
        .onChange(of: viewModel.phase) { oldValue, newValue in
            handlePhaseChange(from: oldValue, to: newValue)
        }
    }
    
    // MARK: - Main View
    
    private var mainView: some View {
        ZStack {
            // Фон - чорний прямокутник/лінія
            RoundedRectangle(cornerRadius: isExpanded ? cornerRadius : lineHeight / 2)
                .fill(Color.black)
                .frame(width: lineWidth, height: isExpanded ? expandedHeight : lineHeight)
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
            
            // Аудіовізуалізатор (при записі)
            if viewModel.phase == .recording && isExpanded {
                audioVisualizerBars
                    .scaleEffect(y: barsAppeared ? 1 : 0, anchor: .center)
                    .opacity(barsAppeared ? 1 : 0)
            }
            
            // Анімація обробки (при транскрибуванні)
            if viewModel.phase == .transcribing && !isExpanded {
                processingLayer
            }
        }
        .scaleEffect(isShowing ? 1 : 0.5)
        .opacity(isShowing ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isShowing)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
        .animation(.easeIn(duration: 0.3), value: exitOffset)
    }
    
    // MARK: - Audio Visualizer Bars
    
    private var audioVisualizerBars: some View {
        let maxBarHeight = expandedHeight - 12
        
        return HStack(alignment: .center, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(Color.white)
                    .frame(width: barWidth, height: barHeight(for: index))
                    .frame(height: maxBarHeight) // Фіксована висота контейнера
            }
        }
        .frame(height: maxBarHeight) // Фіксована висота всього HStack
        .animation(.easeOut(duration: 0.1), value: viewModel.level)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = expandedHeight - 12
        
        let level = viewModel.level
        
        // Центральний бар найвищий, крайні - нижчі (симетрично)
        let center = CGFloat(barCount - 1) / 2.0
        let distance = abs(CGFloat(index) - center) / center
        let centerMultiplier = 1.0 - distance * 0.5
        
        let adjustedLevel = level * centerMultiplier
        let height = minHeight + (maxHeight - minHeight) * adjustedLevel
        
        return max(minHeight, min(maxHeight, height))
    }
    
    // MARK: - Processing Layer
    
    private var processingLayer: some View {
        ZStack {
            // Плавна хвиля що переливається зі сторони в сторону
            RoundedRectangle(cornerRadius: lineHeight / 2)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.1), location: 0),
                            .init(color: .white.opacity(0.15), location: max(0, processingOffset - 0.25)),
                            .init(color: .white.opacity(0.85), location: processingOffset),
                            .init(color: .white.opacity(0.15), location: min(1, processingOffset + 0.25)),
                            .init(color: .white.opacity(0.1), location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: lineWidth, height: lineHeight)
            
            // М'яке зовнішнє світіння що рухається разом
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 20, height: 20)
                .blur(radius: 8)
                .offset(x: (processingOffset - 0.5) * lineWidth)
        }
    }
    
    // MARK: - Animations
    
    private func handlePhaseChange(from oldPhase: DictationPhase, to newPhase: DictationPhase) {
        switch newPhase {
        case .idle:
            // Вилітає за екран вгору
            withAnimation(.easeIn(duration: 0.3)) {
                exitOffset = -150
            }
            // Прибираємо view після завершення анімації
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isVisible = false
                isShowing = false
                barsAppeared = false
                exitOffset = 0
                processingOffset = 0
                isExpanded = false
            }
            
        case .recording:
            // Скидаємо стан
            exitOffset = 0
            processingOffset = 0
            barsAppeared = false
            isExpanded = false
            
            // Додаємо view в ієрархію
            isVisible = true
            
            // Анімація появи
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isShowing = true
                }
            }
            
            // Розширюється
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isExpanded = true
                }
            }
            
            // Бари з'являються
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    barsAppeared = true
                }
            }
            
        case .transcribing:
            // Бари зникають
            withAnimation(.easeOut(duration: 0.15)) {
                barsAppeared = false
            }
            
            // Стискається до лінії
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isExpanded = false
                }
            }
            
            // Запускаємо анімацію обробки після стиснення
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                startProcessingAnimation()
            }
        }
    }
    
    private func startProcessingAnimation() {
        processingOffset = 0
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            processingOffset = 1.0
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        
        VStack(spacing: 50) {
            OverlayView()
                .onAppear {
                    DictationUIState.shared.phase = .recording
                    DictationUIState.shared.level = 0.7
                }
        }
    }
    .frame(width: 300, height: 200)
}
