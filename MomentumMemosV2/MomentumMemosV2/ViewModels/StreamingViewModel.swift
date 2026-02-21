import Foundation
internal import Combine

@MainActor
class StreamingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isSaving = false
    @Published var liveTranscript = ""
    @Published var errorMessage: String?
    
    private let audioManager = StreamingAudioManager()
    private let wsClient = StreamingTranscriptionClient()
    
    private var streamingTask: Task<Void, Never>?
    private var currentSessionId: String?
    private var finalSegments: [String] = []
    
    init() {
        wsClient.onTranscriptPartial = { [weak self] info in
            self?.handleTranscript(info)
        }
        
        wsClient.onSessionSaved = { [weak self] info in
            self?.isSaving = false
            self?.liveTranscript = info.fullTranscript
        }
        
        wsClient.onError = { [weak self] error in
            self?.errorMessage = error
            self?.stopRecording()
        }
    }
    
    private func handleTranscript(_ info: TranscriptPartialInfo) {
        if info.isFinal {
            finalSegments.append(info.text)
            liveTranscript = finalSegments.joined(separator: " ")
        } else {
            let current = finalSegments.joined(separator: " ")
            if current.isEmpty {
                liveTranscript = info.text
            } else {
                liveTranscript = current + " " + info.text
            }
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        errorMessage = nil
        liveTranscript = ""
        finalSegments = []
        isRecording = true
        isSaving = false
        
        let sessionId = UUID().uuidString
        currentSessionId = sessionId
        
        wsClient.connect()
        wsClient.startSession(sessionId: sessionId)
        
        let stream = audioManager.startStreaming()
        
        streamingTask = Task {
            for await data in stream {
                if !Task.isCancelled {
                    wsClient.sendAudioData(data)
                }
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        audioManager.stopStreaming()
        streamingTask?.cancel()
        
        if let sessionId = currentSessionId {
            isSaving = true
            wsClient.endSession(sessionId: sessionId)
        }
    }
}
