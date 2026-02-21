import SwiftUI

struct StreamingRecordView: View {
    @StateObject private var viewModel = StreamingViewModel()
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Live Transcription")
                .font(.largeTitle)
                .bold()
                .padding(.top, 40)
            
            ScrollView {
                Text(viewModel.liveTranscript.isEmpty ? "Speak now..." : viewModel.liveTranscript)
                    .font(.body)
                    .foregroundColor(viewModel.liveTranscript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red.cornerRadius(8))
                    .padding(.horizontal)
            }
            
            Spacer()
            
            if viewModel.isSaving {
                ProgressView("Saving session...")
                    .padding()
            }
            
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                    
                    if viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    } else {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.bottom, 40)
            .disabled(viewModel.isSaving)
            .opacity(viewModel.isSaving ? 0.5 : 1.0)
        }
    }
}
