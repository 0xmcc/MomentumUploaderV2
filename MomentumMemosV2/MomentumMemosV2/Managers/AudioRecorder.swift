import Foundation
import AVFoundation
internal import Combine

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?

    func startRecording() {
        guard !isRecording else { return }

        // Clear any stale error from a previous session
        errorMessage = nil

        #if os(iOS)
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.beginRecording()
                } else {
                    self.errorMessage = "Microphone access denied. Enable it in Settings > Privacy > Microphone."
                }
            }
        }
        #else
        beginRecording()
        #endif
    }

    private func beginRecording() {
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            // Use .measurement mode to avoid any automatic stop from ducking/mixing
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true, options: [])
            #endif

            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let soundFilePath = documentPath.appendingPathComponent("\(UUID().uuidString).m4a")
            self.recordingURL = soundFilePath

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let recorder = try AVAudioRecorder(url: soundFilePath, settings: settings)
            recorder.delegate = self
            recorder.prepareToRecord()

            let didStart = recorder.record()
            if didStart {
                self.audioRecorder = recorder
                self.isRecording = true
                print("[AudioRecorder] Recording started at \(soundFilePath.lastPathComponent)")
            } else {
                self.errorMessage = "Recorder failed to start. Check microphone permissions."
                print("[AudioRecorder] record() returned false")
            }
        } catch {
            self.errorMessage = "Recording setup failed: \(error.localizedDescription)"
            print("[AudioRecorder] Error: \(error)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        audioRecorder?.stop()
        isRecording = false
        print("[AudioRecorder] Recording stopped")

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isRecording = false
            if !flag {
                self.errorMessage = "Recording ended unexpectedly (encode error or session interrupted)."
                print("[AudioRecorder] Finished recording — success: \(flag)")
            }
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async {
            let msg = error?.localizedDescription ?? "Unknown encode error"
            self.errorMessage = "Encode error: \(msg)"
            self.isRecording = false
            print("[AudioRecorder] Encode error: \(msg)")
        }
    }
}
