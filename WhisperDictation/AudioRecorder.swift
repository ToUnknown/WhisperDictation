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
import AudioToolbox
import AppKit

final class AudioRecorder {
    static let shared = AudioRecorder()
    
    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var isRecording = false
    private let recordingQueue = DispatchQueue(label: "com.whisper.recording", qos: .userInitiated)
    private let microphoneManager = MicrophoneManager.shared
    
    // Для плавної анімації рівня звуку
    private var previousLevel: CGFloat = 0
    
    // AAC підтримує тільки ці sample rates
    private let aacSupportedSampleRates: [Double] = [48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000]
    
    /// Callback для передачі URL записаного файлу
    var onRecordingComplete: ((URL) -> Void)?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func start() {
        recordingQueue.async { [weak self] in
            self?.startRecording()
        }
    }
    
    func stopAndTranscribe() {
        recordingQueue.async { [weak self] in
            self?.stopRecording()
        }
    }
    
    // MARK: - Private Recording Methods
    
    private func startRecording() {
        guard !isRecording else {
            print("[AudioRecorder] Already recording")
            return
        }
        
        // Скидаємо рівень звуку для нового запису
        previousLevel = 0
        
        // Створюємо новий engine для кожного запису
        let engine = AVAudioEngine()
        self.engine = engine
        
        // Отримуємо inputNode
        let inputNode = engine.inputNode

        // Налаштовуємо вибраний мікрофон на input node
        configureSelectedMicrophone(for: inputNode)
        
        // Створюємо тимчасовий файл
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "dictation_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        self.recordingURL = fileURL
        
        // Отримуємо формат
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Перевіряємо чи формат валідний
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            print("[AudioRecorder] Invalid input format: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) channels")
            handleRecordingError()
            return
        }
        
        print("[AudioRecorder] Input format: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) channels")
        
        // Вибираємо найближчий підтримуваний AAC sample rate
        let targetSampleRate = findBestSampleRate(for: inputFormat.sampleRate)
        print("[AudioRecorder] Target AAC sample rate: \(targetSampleRate) Hz")
        
        // Створюємо проміжний формат для конвертації (якщо потрібно)
        let needsConversion = inputFormat.sampleRate != targetSampleRate || inputFormat.channelCount != 1
        
        // Формат для запису в файл (AAC)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: targetSampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        do {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: outputSettings)
        } catch {
            print("[AudioRecorder] Failed to create audio file: \(error)")
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
            self?.processBuffer(buffer, converter: converter, outputFormat: outputFormat)
        }
        
        // Запускаємо engine
        do {
            try engine.start()
            isRecording = true
            print("[AudioRecorder] Recording started to: \(fileURL.path)")
        } catch {
            print("[AudioRecorder] Failed to start engine: \(error)")
            inputNode.removeTap(onBus: 0)
            handleRecordingError()
        }
    }
    
    private func stopRecording() {
        guard isRecording, let engine = engine else {
            print("[AudioRecorder] Not recording")
            return
        }
        
        // Зупиняємо engine
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        isRecording = false
        self.engine = nil
        
        // Закриваємо файл
        audioFile = nil
        
        guard let url = recordingURL else {
            print("[AudioRecorder] No recording URL")
            handleRecordingError()
            return
        }
        
        print("[AudioRecorder] Recording stopped: \(url.path)")
        
        // Перевіряємо чи файл існує і має вміст
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("[AudioRecorder] File size: \(fileSize) bytes")
                
                if fileSize > 100 {
                    if let callback = onRecordingComplete {
                        callback(url)
                    } else {
                        transcribe(fileURL: url)
                    }
                } else {
                    print("[AudioRecorder] Recording file is empty")
                    try? FileManager.default.removeItem(at: url)
                    handleRecordingError()
                }
            } catch {
                print("[AudioRecorder] Error checking file: \(error)")
                handleRecordingError()
            }
        } else {
            print("[AudioRecorder] Recording file not found")
            handleRecordingError()
        }
    }
    
    // MARK: - Microphone Selection
    
    private func configureSelectedMicrophone(for inputNode: AVAudioInputNode) {
        // Якщо вибрано "System Default" - не змінюємо нічого
        guard let selectedDeviceID = microphoneManager.getSelectedDeviceID() else {
            print("[AudioRecorder] Using system default microphone")
            return
        }

        guard let audioUnit = inputNode.audioUnit else {
            print("[AudioRecorder] Input node audio unit unavailable; using system default")
            return
        }

        var deviceID = selectedDeviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status == noErr {
            print("[AudioRecorder] Set input node device to \(selectedDeviceID)")
        } else {
            print("[AudioRecorder] Failed to set input node device: \(status)")
        }
    }
    
    // MARK: - Error Handling
    
    private func handleRecordingError() {
        DispatchQueue.main.async {
            self.showErrorAlert(title: "Recording Error", message: "Failed to record audio. Please check your microphone permissions and try again.")
            DictationUIState.shared.reset()
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
    
    private func findBestSampleRate(for inputRate: Double) -> Double {
        // Якщо input rate підтримується AAC - використовуємо його
        if aacSupportedSampleRates.contains(inputRate) {
            return inputRate
        }
        
        // Інакше знаходимо найближчий менший
        for rate in aacSupportedSampleRates {
            if rate <= inputRate {
                return rate
            }
        }
        
        // Fallback
        return 44100
    }
    
    private func processBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter?, outputFormat: AVAudioFormat?) {
        guard let file = audioFile else { return }
        
        // Обчислюємо RMS для візуалізації
        let level = calculateRMS(buffer: buffer)
        DispatchQueue.main.async {
            DictationUIState.shared.level = level
        }
        
        // Якщо потрібна конвертація
        if let converter = converter, let outputFormat = outputFormat {
            let ratio = outputFormat.sampleRate / buffer.format.sampleRate
            let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount) else {
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
            
            converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
            
            if let error = error {
                print("[AudioRecorder] Conversion error: \(error)")
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
                        DictationUIState.shared.reset()
                        OverlayWindow.shared.hide()
                    }
                    
                case .failure(let error):
                    print("[AudioRecorder] Transcription error: \(error)")
                    let errorMessage = self.getErrorMessage(from: error)
                    self.showErrorAlert(title: "Transcription Failed", message: errorMessage)
                    DictationUIState.shared.reset()
                    OverlayWindow.shared.hide()
                }
                
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
