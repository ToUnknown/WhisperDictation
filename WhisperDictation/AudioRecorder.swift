//
//  AudioRecorder.swift
//  WhisperDictation
//
//  Запис аудіо з мікрофона через AVAudioEngine.
//

import Foundation
import AVFoundation
import Accelerate
import CoreAudio
import AppKit

final class AudioRecorder {
    static let shared = AudioRecorder()
    
    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private let microphoneManager = MicrophoneManager.shared
    
    // Thread-safe state management
    private let stateLock = NSLock()
    private var _state: RecordingState = .idle
    private var state: RecordingState {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _state
        }
        set {
            stateLock.lock()
            _state = newValue
            lastStateChangeTime = Date()
            stateLock.unlock()
        }
    }
    
    private enum RecordingState {
        case idle
        case starting
        case recording
        case stopping
    }
    
    private let recordingQueue = DispatchQueue(label: "com.whisper.recording", qos: .userInitiated)
    
    // Для плавної анімації рівня звуку
    private var previousLevel: CGFloat = 0
    
    // Для відновлення системного пристрою за замовчуванням
    private var originalDefaultDevice: AudioDeviceID?
    
    // Для відстеження тривалості запису
    private var recordingStartTime: Date?
    
    
    /// Callback для передачі URL записаного файлу
    var onRecordingComplete: ((URL) -> Void)?
    
    /// Поточна сесія запису
    private var currentSession: Int = 0
    
    /// Час останньої зміни стану (для timeout)
    private var lastStateChangeTime: Date = Date()
    
    private init() {}
    
    // MARK: - Public Methods
    
    func start(session: Int = 0) {
        stateLock.lock()
        
        // Якщо вже йде запис для цієї ж сесії - нічого не робимо
        if _state == .recording && currentSession == session {
            print("[AudioRecorder] Already recording for session \(session)")
            stateLock.unlock()
            return
        }
        
        // Якщо стан не idle - спочатку очищаємо попередній запис
        if _state != .idle {
            print("[AudioRecorder] Cleaning up previous state \(_state) before starting session \(session)")
            
            // Очищаємо ресурси синхронно
            if let eng = engine {
                eng.stop()
                eng.inputNode.removeTap(onBus: 0)
                engine = nil
            }
            audioFile = nil
            if let url = recordingURL {
                try? FileManager.default.removeItem(at: url)
                recordingURL = nil
            }
            recordingStartTime = nil
        }
        
        _state = .starting
        lastStateChangeTime = Date()
        currentSession = session
        stateLock.unlock()
        
        print("[AudioRecorder] Starting recording for session \(session)")
        
        recordingQueue.async { [weak self] in
            self?.startRecording()
        }
    }
    
    /// Повертає поточну сесію запису
    var activeSession: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return currentSession
    }
    
    /// Примусово скидає стан рекордера
    func forceReset() {
        stateLock.lock()
        print("[AudioRecorder] Force reset from state \(_state)")
        
        // Зупиняємо engine якщо є
        if let engine = engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            self.engine = nil
        }
        
        // Закриваємо файл
        audioFile = nil
        
        // Видаляємо тимчасовий файл
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
        
        // Відновлюємо мікрофон
        restoreOriginalDefaultDevice()
        
        // Скидаємо стан
        _state = .idle
        lastStateChangeTime = Date()
        recordingStartTime = nil
        
        stateLock.unlock()
    }
    
    func stopAndTranscribe(session: Int = 0) {
        stateLock.lock()
        let currentState = _state
        let recordingSession = currentSession
        
        print("[AudioRecorder] stopAndTranscribe - session \(session), recorder session \(recordingSession), state \(currentState)")
        
        switch currentState {
        case .recording:
            // Normal case - stop recording and transcribe
            _state = .stopping
            lastStateChangeTime = Date()
            let sessionToStop = recordingSession
            stateLock.unlock()
            recordingQueue.async { [weak self] in
                self?.stopRecording(session: sessionToStop)
            }
            
        case .starting:
            // Recording is being set up - wait a bit and try again
            let startTime = lastStateChangeTime
            stateLock.unlock()
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < 2.0 {
                print("[AudioRecorder] Recording is starting (\(String(format: "%.1f", elapsed))s), waiting...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.stopAndTranscribe(session: session)
                }
            } else {
                print("[AudioRecorder] Starting timeout, resetting")
                forceReset()
                DispatchQueue.main.async {
                    DictationUIState.shared.forceReset()
                    OverlayWindow.shared.hide()
                }
            }
            
        case .stopping:
            // Already stopping, nothing to do
            stateLock.unlock()
            print("[AudioRecorder] Already stopping")
            
        case .idle:
            // Not recording, just reset UI
            stateLock.unlock()
            print("[AudioRecorder] Not recording, resetting UI for session \(session)")
            DispatchQueue.main.async {
                if DictationUIState.shared.reset(forSession: session) {
                    OverlayWindow.shared.hide()
                }
            }
        }
    }
    
    // MARK: - Private Recording Methods
    
    private func startRecording() {
        // Скидаємо рівень звуку для нового запису
        previousLevel = 0
        
        // Налаштовуємо вибраний мікрофон через зміну системного пристрою за замовчуванням
        setupSelectedMicrophone()
        
        // Створюємо новий engine для кожного запису
        let engine = AVAudioEngine()
        self.engine = engine
        
        // Отримуємо inputNode
        let inputNode = engine.inputNode
        
        // Створюємо тимчасовий файл (WAV format - more reliable)
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "dictation_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        self.recordingURL = fileURL
        
        // Отримуємо формат
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Перевіряємо чи формат валідний
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            print("[AudioRecorder] Invalid input format: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) channels")
            restoreOriginalDefaultDevice()
            state = .idle
            handleRecordingError()
            return
        }
        
        print("[AudioRecorder] Input format: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) channels")
        
        // Target: 16kHz mono for Whisper (optimal for speech recognition)
        let targetSampleRate: Double = 16000
        print("[AudioRecorder] Target sample rate: \(targetSampleRate) Hz")
        
        // Створюємо проміжний формат для конвертації
        let needsConversion = inputFormat.sampleRate != targetSampleRate || inputFormat.channelCount != 1
        
        // Формат для запису в файл (16-bit PCM WAV)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: targetSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: outputSettings)
        } catch {
            print("[AudioRecorder] Failed to create audio file: \(error)")
            restoreOriginalDefaultDevice()
            state = .idle
            handleRecordingError()
            return
        }
        
        // Створюємо конвертер якщо потрібно
        var converter: AVAudioConverter?
        var outputFormat: AVAudioFormat?
        
        if needsConversion {
            outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: false
            )
            
            if let outFmt = outputFormat {
                converter = AVAudioConverter(from: inputFormat, to: outFmt)
            }
        }
        
        // Встановлюємо tap на input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            guard let self = self, self.state == .recording else { return }
            self.processBuffer(buffer, converter: converter, outputFormat: outputFormat)
        }
        
        // Запускаємо engine
        do {
            try engine.start()
            state = .recording
            recordingStartTime = Date()
            print("[AudioRecorder] Recording started to: \(fileURL.path)")
        } catch {
            print("[AudioRecorder] Failed to start engine: \(error)")
            inputNode.removeTap(onBus: 0)
            restoreOriginalDefaultDevice()
            state = .idle
            handleRecordingError()
        }
    }
    
    private func stopRecording(session: Int = 0) {
        guard let engine = engine else {
            print("[AudioRecorder] No engine to stop")
            state = .idle
            return
        }
        
        print("[AudioRecorder] Stopping recording for session \(session)")
        
        // Capture URL before any cleanup
        let url = recordingURL
        recordingURL = nil
        
        // Зупиняємо engine
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        self.engine = nil
        
        // Закриваємо файл - важливо зробити це в окремому блоці щоб файл був закритий
        closeAudioFile()
        
        // Відновлюємо оригінальний пристрій за замовчуванням
        restoreOriginalDefaultDevice()
        
        guard let url = url else {
            print("[AudioRecorder] No recording URL")
            state = .idle
            handleRecordingError()
            return
        }
        
        // Обчислюємо тривалість запису
        let duration: Double
        if let startTime = recordingStartTime {
            duration = Date().timeIntervalSince(startTime)
            print("[AudioRecorder] Recording stopped: \(url.path) (duration: \(String(format: "%.2f", duration))s, session \(session))")
        } else {
            duration = 0
            print("[AudioRecorder] Recording stopped: \(url.path) (duration: unknown, session \(session))")
        }
        recordingStartTime = nil
        
        // Мінімальна тривалість запису (0.5 секунди) - коротші записи вважаються випадковими
        let minimumDuration: Double = 0.5
        
        // Якщо запис занадто короткий - тихо закриваємо без помилки
        if duration < minimumDuration && duration > 0 {
            print("[AudioRecorder] Recording too short (\(String(format: "%.2f", duration))s < \(minimumDuration)s), dismissing silently for session \(session)")
            try? FileManager.default.removeItem(at: url)
            state = .idle
            DispatchQueue.main.async {
                // Тільки ховаємо якщо reset() успішний (кнопка не натиснута, та ж сесія)
                if DictationUIState.shared.reset(forSession: session) {
                    OverlayWindow.shared.hide()
                }
            }
            return
        }
        
        // Даємо час на фінальізацію файлу
        Thread.sleep(forTimeInterval: 0.1)
        
        // Мінімальний розмір файлу (приблизно 0.5с при 16kHz 16-bit mono = ~16KB)
        let minimumFileSize: Int64 = 16000
        
        // Перевіряємо чи файл існує і має вміст
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("[AudioRecorder] File size: \(fileSize) bytes")
                
                if fileSize > minimumFileSize {
                    // Фіксуємо UI видимим для транскрибування
                    DispatchQueue.main.async {
                        DictationUIState.shared.lockOverlayVisible()
                        DictationUIState.shared.phase = .transcribing
                    }
                    
                    // Set state to idle before async transcription
                    state = .idle
                    if let callback = onRecordingComplete {
                        callback(url)
                    } else {
                        transcribe(fileURL: url)
                    }
                } else {
                    print("[AudioRecorder] Recording file too small (\(fileSize) bytes < \(minimumFileSize) bytes), dismissing silently for session \(session)")
                    try? FileManager.default.removeItem(at: url)
                    state = .idle
                    // UI вже анімується до зникнення, просто скидаємо стан
                    DispatchQueue.main.async {
                        // Тільки ховаємо якщо reset() успішний (кнопка не натиснута, та ж сесія)
                        if DictationUIState.shared.reset(forSession: session) {
                            OverlayWindow.shared.hide()
                        }
                    }
                }
            } catch {
                print("[AudioRecorder] Error checking file: \(error)")
                state = .idle
                handleRecordingError()
            }
        } else {
            print("[AudioRecorder] Recording file not found")
            state = .idle
            handleRecordingError()
        }
    }
    
    private func closeAudioFile() {
        // Закриваємо файл в окремому блоці для гарантованого звільнення
        autoreleasepool {
            audioFile = nil
        }
    }
    
    // MARK: - Microphone Selection
    
    private func setupSelectedMicrophone() {
        // Якщо вибрано "System Default" - не змінюємо нічого
        guard let selectedDeviceID = microphoneManager.getSelectedDeviceID() else {
            print("[AudioRecorder] Using system default microphone")
            originalDefaultDevice = nil
            return
        }
        
        // Зберігаємо поточний системний пристрій за замовчуванням
        originalDefaultDevice = microphoneManager.getSystemDefaultInputDevice()
        print("[AudioRecorder] Original default device: \(originalDefaultDevice ?? 0)")
        
        // Встановлюємо вибраний пристрій як системний за замовчуванням
        if microphoneManager.setSystemDefaultInputDevice(selectedDeviceID) {
            print("[AudioRecorder] Set selected device \(selectedDeviceID) as system default")
            
            // Невелика затримка для застосування змін
            Thread.sleep(forTimeInterval: 0.1)
        } else {
            print("[AudioRecorder] Failed to set selected device as system default, using current default")
            originalDefaultDevice = nil
        }
    }
    
    private func restoreOriginalDefaultDevice() {
        guard let originalDevice = originalDefaultDevice else {
            return
        }
        
        print("[AudioRecorder] Restoring original default device: \(originalDevice)")
        microphoneManager.setSystemDefaultInputDevice(originalDevice)
        originalDefaultDevice = nil
    }
    
    // MARK: - Error Handling
    
    private func handleRecordingError() {
        DispatchQueue.main.async {
            self.showErrorAlert(title: "Recording Error", message: "Failed to record audio. Please check your microphone permissions and try again.")
            DictationUIState.shared.forceReset()
            OverlayWindow.shared.hide()
        }
    }
    
    private func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func getErrorMessage(from error: Error) -> String {
        if let whisperError = error as? WhisperError {
            return whisperError.localizedDescription
        } else {
            return "An error occurred: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Methods
    
    private func processBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter?, outputFormat: AVAudioFormat?) {
        // Double-check we're still recording and have a valid file
        guard state == .recording, let file = audioFile else { return }
        
        // Обчислюємо RMS для візуалізації
        let level = calculateRMS(buffer: buffer)
        DispatchQueue.main.async {
            DictationUIState.shared.level = level
        }
        
        // Якщо потрібна конвертація
        if let converter = converter, let outputFormat = outputFormat {
            let ratio = outputFormat.sampleRate / buffer.format.sampleRate
            // Add some extra capacity to ensure we have enough space
            let outputFrameCount = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio) + 100)
            
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount) else {
                print("[AudioRecorder] Failed to create output buffer")
                return
            }
            
            var error: NSError?
            var inputBufferUsed = false
            
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                if inputBufferUsed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                inputBufferUsed = true
                outStatus.pointee = .haveData
                return buffer
            }
            
            let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
            
            if let error = error {
                print("[AudioRecorder] Conversion error: \(error)")
                return
            }
            
            if status == .error {
                print("[AudioRecorder] Converter returned error status")
                return
            }
            
            // Only write if we have data
            guard outputBuffer.frameLength > 0 else {
                return
            }
            
            // Записуємо конвертований буфер
            do {
                try file.write(from: outputBuffer)
            } catch {
                print("[AudioRecorder] Failed to write converted buffer: \(error)")
            }
        } else {
            // Записуємо напряму
            do {
                try file.write(from: buffer)
            } catch {
                print("[AudioRecorder] Failed to write buffer: \(error)")
            }
        }
    }
    
    private func calculateRMS(buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData else { return 0 }
        
        let channelDataValue = channelData.pointee
        let channelDataCount = Int(buffer.frameLength)
        
        guard channelDataCount > 0 else { return 0 }
        
        var rms: Float = 0
        vDSP_rmsqv(channelDataValue, 1, &rms, vDSP_Length(channelDataCount))
        
        // Підсилюємо для кращої візуалізації
        let boosted = pow(CGFloat(rms), 0.6) * 8.0
        let rawLevel = min(1.0, max(0.0, boosted))
        
        // Плавна анімація - швидка атака, швидший спад для живої реакції
        let attackSmoothing: CGFloat = 0.7  // Швидкість наростання
        let decaySmoothing: CGFloat = 0.5   // Швидкість спаду
        
        let smoothing = rawLevel > previousLevel ? attackSmoothing : decaySmoothing
        let smoothedLevel = previousLevel + (rawLevel - previousLevel) * smoothing
        previousLevel = smoothedLevel
        
        return smoothedLevel
    }
    
    private func transcribe(fileURL: URL) {
        WhisperClient.shared.transcribeFile(at: fileURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    print("[AudioRecorder] Transcription: \(text)")
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        TranscriptionHistoryStore.shared.add(text: text)
                        TextInjector.shared.insert(text: text)
                    } else {
                        print("[AudioRecorder] Empty transcription, skipping insert")
                        self.showErrorAlert(title: "Empty Transcription", message: "The audio was transcribed but the result was empty. Please try again.")
                        DictationUIState.shared.forceReset()
                        OverlayWindow.shared.hide()
                    }
                    
                case .failure(let error):
                    print("[AudioRecorder] Transcription error: \(error)")
                    let errorMessage = self.getErrorMessage(from: error)
                    self.showErrorAlert(title: "Transcription Failed", message: errorMessage)
                    DictationUIState.shared.forceReset()
                    OverlayWindow.shared.hide()
                }
                
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
