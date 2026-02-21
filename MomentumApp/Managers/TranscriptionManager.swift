import Foundation

class TranscriptionManager {
    static let shared = TranscriptionManager()
    
    // NVIDIA NIM API endpoint for transcription
    // Assuming NVIDIA Parakeet TDT 1.1b model for demonstration
    private let nvapiURL = URL(string: "https://integrate.api.nvidia.com/v1/audio/transcriptions")!
    
    // TODO: Add your NVIDIA NIM API Key
    private let apiKey = "YOUR_NVIDIA_API_KEY"
    
    func transcribeAudio(fileURL: URL) async throws -> String {
        var request = URLRequest(url: nvapiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Ensure the file data can be loaded
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let mimeType = "audio/m4a"
        
        // Helper block to append strings to Data
        func appendText(_ string: String) {
            if let data = string.data(using: .utf8) {
                body.append(data)
            }
        }
        
        // Append audio file to form-data
        appendText("--\(boundary)\r\n")
        appendText("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        appendText("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        appendText("\r\n")
        
        // Append model name matching NVIDIA NIM's API requirement
        // "nvidia/parakeet-rnnt-1.1b" or "nvidia/parakeet-tdt-1.1b"
        appendText("--\(boundary)\r\n")
        appendText("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        appendText("nvidia/parakeet-tdt-1.1b\r\n")
        
        appendText("--\(boundary)--\r\n")
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for valid HTTP status
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Request Error"
            throw NSError(domain: "TranscriptionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        // Decode response from the standard OpenAI-compatible API mapping from NVIDIA
        struct TranscriptionResponse: Decodable {
            let text: String
        }
        
        do {
            let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            return result.text
        } catch {
            throw error
        }
    }
}
