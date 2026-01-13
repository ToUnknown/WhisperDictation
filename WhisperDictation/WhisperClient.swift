//
//  WhisperClient.swift
//  WhisperDictation
//
//  Клієнт для OpenAI Whisper API.
//

import Foundation
import Carbon

final class WhisperClient {
    static let shared = WhisperClient()
    
    private let apiURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    
    // Маппінг мов клавіатури до кодів Whisper
    private let keyboardToWhisperLanguage: [String: String] = [
        "uk": "uk",      // Ukrainian
        "en": "en",      // English
    ]
    
    private init() {}
    
    // MARK: - Public Methods
    
    func transcribeFile(at url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        print("[WhisperClient] Starting transcription for file: \(url.path)")
        
        // Отримуємо мову з системної клавіатури
        let keyboardLanguage = getCurrentKeyboardLanguage()
        let whisperLanguage = keyboardToWhisperLanguage[keyboardLanguage] ?? "en"
        print("[WhisperClient] Keyboard language: \(keyboardLanguage) → Whisper language: \(whisperLanguage)")
        
        // Перевіряємо API ключ
        guard let apiKey = APIKeyStore.shared.apiKey, !apiKey.isEmpty else {
            print("[WhisperClient] ERROR: API key is missing or empty")
            completion(.failure(WhisperError.missingAPIKey))
            return
        }
        
        // Перевіряємо формат API ключа
        if !APIKeyStore.shared.isValidAPIKeyFormat(apiKey) {
            print("[WhisperClient] ERROR: API key format is invalid (must start with 'sk-' and be at least 10 characters)")
            completion(.failure(WhisperError.invalidAPIKeyFormat))
            return
        }
        
        print("[WhisperClient] API key found (length: \(apiKey.count) chars)")
        
        // Читаємо файл
        guard let audioData = try? Data(contentsOf: url) else {
            print("[WhisperClient] ERROR: Failed to read audio file at \(url.path)")
            completion(.failure(WhisperError.fileReadError))
            return
        }
        
        print("[WhisperClient] Audio file read successfully: \(audioData.count) bytes")
        
        // Створюємо multipart request
        let boundary = UUID().uuidString
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Формуємо тіло запиту
        var body = Data()
        
        // Поле model
        body.appendFormField(named: "model", value: "gpt-4o-transcribe", boundary: boundary)
        
        // Поле language - мова з клавіатури
        body.appendFormField(named: "language", value: whisperLanguage, boundary: boundary)
        
        // Поле file
        let fileName = url.lastPathComponent
        let mimeType = getMimeType(for: url)
        
        print("[WhisperClient] File name: \(fileName), MIME type: \(mimeType)")
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Закриваємо boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("[WhisperClient] Request body size: \(body.count) bytes")
        print("[WhisperClient] Sending request to: \(apiURL.absoluteString)")
        
        // Виконуємо запит
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            print("[WhisperClient] Received response")
            
            if let error = error {
                print("[WhisperClient] ERROR: Network error - \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("[WhisperClient] ERROR: No data received from server")
                completion(.failure(WhisperError.noData))
                return
            }
            
            print("[WhisperClient] Response data size: \(data.count) bytes")
            
            // Перевіряємо HTTP статус
            if let httpResponse = response as? HTTPURLResponse {
                print("[WhisperClient] HTTP status code: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("[WhisperClient] ERROR: HTTP error status \(httpResponse.statusCode)")
                    
                    // Спробуємо отримати помилку з відповіді
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("[WhisperClient] Response body: \(responseString)")
                    }
                    
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorInfo = errorJson["error"] as? [String: Any],
                       let message = errorInfo["message"] as? String {
                        print("[WhisperClient] API error message: \(message)")
                        completion(.failure(WhisperError.apiError(message)))
                    } else {
                        completion(.failure(WhisperError.httpError(httpResponse.statusCode)))
                    }
                    return
                }
            } else {
                print("[WhisperClient] WARNING: Response is not an HTTPURLResponse")
            }
            
            // Парсимо JSON відповідь
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String {
                    print("[WhisperClient] Transcription successful: \(text.prefix(100))\(text.count > 100 ? "..." : "")")
                    completion(.success(text))
                } else {
                    // Можливо простий текст без JSON
                    if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                        print("[WhisperClient] Transcription (plain text): \(text.prefix(100))\(text.count > 100 ? "..." : "")")
                        completion(.success(text))
                    } else {
                        print("[WhisperClient] ERROR: Invalid response format")
                        completion(.failure(WhisperError.invalidResponse))
                    }
                }
            } catch {
                // Якщо не JSON, спробуємо як простий текст
                if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                    print("[WhisperClient] Transcription (plain text): \(text.prefix(100))\(text.count > 100 ? "..." : "")")
                    completion(.success(text))
                } else {
                    print("[WhisperClient] ERROR: Failed to parse response - \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Private Methods
    
    /// Отримує поточну мову клавіатури з системи
    private func getCurrentKeyboardLanguage() -> String {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            print("[WhisperClient] Could not get keyboard input source, defaulting to 'en'")
            return "en"
        }
        
        // Отримуємо властивість мов через Unmanaged
        guard let rawPtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceLanguages) else {
            print("[WhisperClient] Could not get languages from input source, defaulting to 'en'")
            return "en"
        }
        
        // Конвертуємо в CFArray
        let languagesArray = Unmanaged<CFArray>.fromOpaque(rawPtr).takeUnretainedValue()
        
        guard let languages = languagesArray as? [String], let primaryLanguage = languages.first else {
            print("[WhisperClient] Could not parse languages array, defaulting to 'en'")
            return "en"
        }
        
        // Беремо перші 2 символи (код мови), наприклад "uk" з "uk-UA"
        let languageCode = String(primaryLanguage.prefix(2))
        print("[WhisperClient] Detected keyboard language: \(primaryLanguage) → \(languageCode)")
        return languageCode
    }
    
    private func getMimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m4a":
            return "audio/m4a"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "webm":
            return "audio/webm"
        case "mp4":
            return "audio/mp4"
        case "mpeg":
            return "audio/mpeg"
        case "mpga":
            return "audio/mpeg"
        case "oga":
            return "audio/ogg"
        case "ogg":
            return "audio/ogg"
        case "flac":
            return "audio/flac"
        default:
            return "audio/m4a"
        }
    }
}

// MARK: - Data Extension

private extension Data {
    mutating func appendFormField(named name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}

// MARK: - Errors

enum WhisperError: LocalizedError {
    case missingAPIKey
    case invalidAPIKeyFormat
    case fileReadError
    case noData
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is not set. Please configure it in Settings."
        case .invalidAPIKeyFormat:
            return "API key format is invalid. OpenAI API keys must start with 'sk-' and be at least 10 characters long."
        case .fileReadError:
            return "Failed to read audio file."
        case .noData:
            return "No data received from server."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}
