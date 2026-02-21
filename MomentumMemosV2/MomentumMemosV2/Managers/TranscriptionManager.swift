import Foundation

class TranscriptionManager {
    static let shared = TranscriptionManager()

    private enum ConfigKeys {
        static let endpoint = "NVIDIA_TRANSCRIPTION_URL"
        static let apiKey = "NVIDIA_API_KEY"
        static let model = "NVIDIA_TRANSCRIPTION_MODEL"
        static let defaultEndpoint = "https://integrate.api.nvidia.com/v1/audio/transcriptions"
        static let defaultModel = "nvidia/parakeet-ctc-1.1b-asr"
    }

    private func configValue(for key: String) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[key], !envValue.isEmpty {
            return envValue
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String, !plistValue.isEmpty {
            return plistValue
        }

        return nil
    }
    
    func transcribeAudio(fileURL: URL) async throws -> String {
        let endpointString = configValue(for: ConfigKeys.endpoint) ?? ConfigKeys.defaultEndpoint
        let model = configValue(for: ConfigKeys.model) ?? ConfigKeys.defaultModel
        guard let nvapiURL = URL(string: endpointString) else {
            throw NSError(
                domain: "TranscriptionManager",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Invalid transcription endpoint URL."]
            )
        }

        guard let apiKey = configValue(for: ConfigKeys.apiKey) else {
            throw NSError(
                domain: "TranscriptionManager",
                code: 1000,
                userInfo: [NSLocalizedDescriptionKey: "Missing configuration value for \(ConfigKeys.apiKey)."]
            )
        }

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
        appendText("\(model)\r\n")
        
        appendText("--\(boundary)--\r\n")
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for valid HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "TranscriptionManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response from transcription API."]
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiMessage = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackHint = "Verify NVIDIA_TRANSCRIPTION_URL and NVIDIA_TRANSCRIPTION_MODEL from your Build NVIDIA API page."
            let message = (apiMessage?.isEmpty == false) ? apiMessage! : "HTTP \(httpResponse.statusCode)"
            throw NSError(
                domain: "TranscriptionManager",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "Transcription request failed [\(httpResponse.statusCode)] at \(endpointString): \(message). \(fallbackHint)"
                ]
            )
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
