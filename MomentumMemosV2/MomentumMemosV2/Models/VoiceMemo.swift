import Foundation

struct VoiceMemo: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let title: String
    let audioFileURL: String? // Remote URL from Supabase
    let transcription: String?
    let duration: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case title
        case audioFileURL = "audio_url"
        case transcription
        case duration
    }
}
