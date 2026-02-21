import Foundation
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    @Published var memos: [VoiceMemo] = []
    @Published var isTranscribing = false
    @Published var isUploading = false
    @Published var errorMessage: String?
    
    var audioRecorder = AudioRecorder()
    
    init() {
        Task {
            await fetchMemos()
        }
    }
    
    func toggleRecording() {
        // Clear any previous error
        errorMessage = nil
        
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            
            // Allow a small delay to cleanly stop writing to disk
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let error = self.audioRecorder.errorMessage {
                    self.errorMessage = "Recording Error: \(error)"
                    return
                }
                
                guard let url = self.audioRecorder.recordingURL else {
                    self.errorMessage = "Could not find recorded audio file."
                    return
                }
                
                Task {
                    await self.processAndUpload(fileURL: url)
                }
            }
        } else {
            audioRecorder.startRecording()
        }
    }
    
    private func processAndUpload(fileURL: URL) async {
        isTranscribing = true
        isUploading = true
        errorMessage = nil
        
        do {
            // 1. Send Audio to Parakeet for transcription
            let transcriptText = try await TranscriptionManager.shared.transcribeAudio(fileURL: fileURL)
            isTranscribing = false
            
            // 2. Upload the audio file payload to Supabase 
            let fileName = "\(UUID().uuidString).m4a"
            let publicAudioURL = try await SupabaseManager.shared.uploadAudioFile(fileURL: fileURL, fileName: fileName)
            
            // 3. Save matching structural data in JSON to Supabase database
            let newMemo = VoiceMemo(
                id: UUID(),
                createdAt: Date(),
                title: "Recording - \(Date().formatted())",
                audioFileURL: publicAudioURL.absoluteString,
                transcription: transcriptText,
                duration: 0.0 // Duration can be expanded later via AVAsset
            )
            
            try await SupabaseManager.shared.uploadMetadata(memo: newMemo)
            isUploading = false
            
            // 4. Update memory / state
            await fetchMemos()
        } catch {
            isTranscribing = false
            isUploading = false
            errorMessage = "Processing Error: \(error.localizedDescription)"
        }
    }
    
    func fetchMemos() async {
        do {
            let fetchedMemos = try await SupabaseManager.shared.fetchMemos()
            self.memos = fetchedMemos
        } catch {
            errorMessage = "Fetch Failed: \(error.localizedDescription)"
        }
    }
}
