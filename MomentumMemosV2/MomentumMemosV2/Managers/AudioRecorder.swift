import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var errorMessage: String?
    
    private var audioRecorder: AVAudioRecorder?
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            #if os(iOS)
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            #endif
            
            // Get documents directory URL
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let soundFilePath = documentPath.appendingPathComponent("\(UUID().uuidString).m4a")
            self.recordingURL = soundFilePath
            
            // Audio recording settings for M4A / AAC
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: soundFilePath, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Recording Failed: \(error.localizedDescription)"
            }
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}
