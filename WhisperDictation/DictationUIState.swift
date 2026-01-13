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
    
    private init() {}
    
    /// Скидає стан до початкового
    func reset() {
        phase = .idle
        level = 0.0
    }
}

