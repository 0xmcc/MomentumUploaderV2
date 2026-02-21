import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                // Show errors dynamically
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                // Memos collection view
                List(viewModel.memos) { memo in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(memo.title)
                            .font(.headline)
                        
                        if let transcription = memo.transcription {
                            Text(transcription)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(3)
                        } else {
                            Text("No transcription available.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(memo.createdAt.formatted())
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .listStyle(.plain)
                
                Spacer()
                
                // Recording / Activity Status Box
                VStack(spacing: 8) {
                    if viewModel.isTranscribing {
                        HStack {
                            ProgressView()
                            Text("Transcribing via Parakeet NIM...")
                                .foregroundColor(.orange)
                        }
                    }
                    if viewModel.isUploading {
                        HStack {
                            ProgressView()
                            Text("Uploading to Supabase...")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Main Record Button
                    Button(action: {
                        viewModel.toggleRecording()
                    }) {
                        ZStack {
                            Circle()
                                .fill(viewModel.audioRecorder.isRecording ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: viewModel.audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .foregroundColor(.white)
                        }
                        .scaleEffect(viewModel.audioRecorder.isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut, value: viewModel.audioRecorder.isRecording)
                        .shadow(radius: viewModel.audioRecorder.isRecording ? 10 : 5)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("NVIDIA Voice Memos")
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.fetchMemos()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            #endif
        }
    }
}
