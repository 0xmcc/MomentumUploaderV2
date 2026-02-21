import Foundation

struct SessionStartConfig: Codable {
    let sampleRate: Int
    let channels: Int
    let bitDepth: Int
    let encoding: String
    
    enum CodingKeys: String, CodingKey {
        case sampleRate = "sample_rate"
        case channels
        case bitDepth = "bit_depth"
        case encoding
    }
}

struct SessionStartMessage: Codable {
    let type: String = "session.start"
    let sessionId: String
    let config: SessionStartConfig
    
    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case config
    }
}

struct SessionEndMessage: Codable {
    let type: String = "session.end"
    let sessionId: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
    }
}

struct TranscriptPartialInfo: Codable {
    let text: String
    let isFinal: Bool
    let sequence: Int
    
    enum CodingKeys: String, CodingKey {
        case text
        case isFinal = "is_final"
        case sequence
    }
}

struct SessionSavedInfo: Codable {
    let memoId: String
    let fullTranscript: String
    
    enum CodingKeys: String, CodingKey {
        case memoId = "memo_id"
        case fullTranscript = "full_transcript"
    }
}

class StreamingTranscriptionClient: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    
    private var urlString: String {
        if let envValue = ProcessInfo.processInfo.environment["BACKEND_WS_URL"], !envValue.isEmpty {
            return envValue
        }
        if let plistValue = Bundle.main.infoDictionary?["BACKEND_WS_URL"] as? String, !plistValue.isEmpty {
            return plistValue
        }
        return "ws://localhost:8000/ws/transcribe"
    }
    
    var onTranscriptPartial: ((TranscriptPartialInfo) -> Void)?
    var onSessionSaved: ((SessionSavedInfo) -> Void)?
    var onError: ((String) -> Void)?
    
    func connect() {
        guard let url = URL(string: urlString) else {
            onError?("Invalid backend URL")
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
    }
    
    func startSession(sessionId: String) {
        let config = SessionStartConfig(sampleRate: 16000, channels: 1, bitDepth: 16, encoding: "LINEAR_PCM")
        let msg = SessionStartMessage(sessionId: sessionId, config: config)
        sendJSON(msg)
    }
    
    func endSession(sessionId: String) {
        let msg = SessionEndMessage(sessionId: sessionId)
        sendJSON(msg)
    }
    
    func sendAudioData(_ data: Data) {
        guard isConnected else { return }
        let msg = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(msg) { [weak self] error in
            if let error = error {
                print("WebSocket send error: \(error)")
                self?.onError?("Failed to send audio bytes: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendJSON<T: Encodable>(_ payload: T) {
        guard isConnected else { return }
        do {
            let data = try JSONEncoder().encode(payload)
            if let str = String(data: data, encoding: .utf8) {
                let msg = URLSessionWebSocketTask.Message.string(str)
                webSocketTask?.send(msg) { error in
                    if let error = error {
                        print("WebSocket JSON send error: \(error)")
                    }
                }
            }
        } catch {
            print("Failed to encode json: \(error)")
        }
    }
    
    private func receiveMessage() {
        guard isConnected else { return }
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleTextResponse(text)
                case .data(_):
                    break
                @unknown default:
                    break
                }
                self.receiveMessage()
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self.isConnected = false
                self.onError?("Connection lost.")
            }
        }
    }
    
    private func handleTextResponse(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let type = dict["type"] as? String {
                if type == "transcript.partial" || type == "transcript.final" {
                    let info = try JSONDecoder().decode(TranscriptPartialInfo.self, from: data)
                    DispatchQueue.main.async {
                        self.onTranscriptPartial?(info)
                    }
                } else if type == "session.saved" {
                    let info = try JSONDecoder().decode(SessionSavedInfo.self, from: data)
                    DispatchQueue.main.async {
                        self.onSessionSaved?(info)
                    }
                } else if type == "error" {
                    let msg = dict["message"] as? String ?? "Unknown server error"
                    DispatchQueue.main.async {
                        self.onError?(msg)
                    }
                }
            }
        } catch {
            print("Failed to parse response: \(text)")
        }
    }
}
