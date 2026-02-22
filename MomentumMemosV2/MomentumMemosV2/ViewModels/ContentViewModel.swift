import Foundation
import SwiftUI
internal import Combine

@MainActor
class ContentViewModel: ObservableObject {
    @Published var memos: [VoiceMemo] = []
    @Published var isUploading = false
    @Published var errorMessage: String?
    
    var audioRecorder = AudioRecorder()
    
    init() {
        Task {
            await fetchMemos()
            do {
                try await SupabaseManager.shared.subscribeToMemos { [weak self] in
                    Task { @MainActor in
                        await self?.fetchMemos()
                    }
                }
            } catch {
                print("Failed to subscribe to memo updates: \(error)")
            }
        }
    }
    
    func toggleRecording() {
        errorMessage = nil

        if audioRecorder.isRecording {
            // Capture the URL before stopping (stopRecording sets isRecording=false synchronously)
            let url = audioRecorder.recordingURL
            audioRecorder.stopRecording()

            guard let fileURL = url else {
                errorMessage = "Could not find recorded audio file."
                return
            }

            Task {
                await self.processAndUpload(fileURL: fileURL)
            }
        } else {
            audioRecorder.startRecording()
        }
    }
    
    private func processAndUpload(fileURL: URL) async {
        isUploading = true
        errorMessage = nil
        
        do {
            // 1. Upload the audio file payload to Supabase 
            let fileName = "\(UUID().uuidString).m4a"
            let publicAudioURL = try await SupabaseManager.shared.uploadAudioFile(fileURL: fileURL, fileName: fileName)
            
            // 2. Save matching structural data in JSON to Supabase database
            let newMemo = VoiceMemo(
                id: UUID(),
                createdAt: Date(),
                title: "Recording - \(Date().formatted())",
                audioFileURL: publicAudioURL.absoluteString,
                transcription: "Processing...",
                duration: "0", // Duration can be expanded later via AVAsset
                streamSessionId: nil
            )
            
            try await SupabaseManager.shared.uploadMetadata(memo: newMemo)
            isUploading = false
            
            // 3. Update memory / state
            await fetchMemos()
        } catch {
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
