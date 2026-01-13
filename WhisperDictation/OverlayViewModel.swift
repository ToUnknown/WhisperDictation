//
//  OverlayViewModel.swift
//  WhisperDictation
//
//  ViewModel for the overlay indicator.
//

import Combine
import CoreGraphics
import Foundation

final class OverlayViewModel: ObservableObject {
    @Published private(set) var phase: DictationPhase
    @Published private(set) var level: CGFloat

    private let state: DictationUIState
    init(state: DictationUIState = .shared) {
        self.state = state
        self.phase = state.phase
        self.level = state.level
        bindState()
    }

    private func bindState() {
        state.$phase
            .receive(on: DispatchQueue.main)
            .assign(to: &$phase)

        state.$level
            .receive(on: DispatchQueue.main)
            .assign(to: &$level)
    }
}
