import Foundation
internal import Combine
import AVFoundation

class StreamingAudioManager: NSObject, ObservableObject {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    
    private var continuation: AsyncStream<Data>.Continuation?
    
    func startStreaming() -> AsyncStream<Data> {
        return AsyncStream { continuation in
            self.continuation = continuation
            
            do {
                #if os(iOS)
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default)
                try session.setActive(true)
                #endif
                
                // Clear any existing taps just in case
                engine.inputNode.removeTap(onBus: 0)
                
                let inputNode = engine.inputNode
                let inputFormat = inputNode.inputFormat(forBus: 0)
                
                guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true) else {
                    print("Failed to create output audio format.")
                    continuation.finish()
                    return
                }
                
                guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                    print("Failed to create audio converter.")
                    continuation.finish()
                    return
                }
                self.converter = converter
                
                inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
                    self?.process(buffer: buffer, outputFormat: outputFormat)
                }
                
                engine.prepare()
                try engine.start()
            } catch {
                print("Failed to start audio engine: \(error)")
                continuation.finish()
            }
        }
    }
    
    private func process(buffer: AVAudioPCMBuffer, outputFormat: AVAudioFormat) {
        guard let converter = converter else { return }
        
        let capacity = AVAudioFrameCount(outputFormat.sampleRate / buffer.format.sampleRate * Double(buffer.frameLength))
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }
        
        var error: NSError?
        var allFramesProduced = false
        
        converter.convert(to: outputBuffer, error: &error) { packetCount, outStatus in
            if allFramesProduced {
                outStatus.pointee = .noDataNow
                return nil
            }
            allFramesProduced = true
            outStatus.pointee = .haveData
            return buffer
        }
        
        if error == nil {
            let audioBuffer = outputBuffer.audioBufferList.pointee.mBuffers
            if let mData = audioBuffer.mData {
                let bufferData = Data(bytes: mData, count: Int(audioBuffer.mDataByteSize))
                self.continuation?.yield(bufferData)
            }
        }
    }
    
    func stopStreaming() {
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
        
        continuation?.finish()
        continuation = nil
    }
}
