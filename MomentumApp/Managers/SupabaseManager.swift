import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    // TODO: Connect this to your Supabase project URL and anon key.
    // Replace the placeholders below.
    let client = SupabaseClient(
        URL: URL(string: "YOUR_SUPABASE_URL")!,
        supabaseKey: "YOUR_SUPABASE_ANON_KEY"
    )
    
    init() {}
    
    func uploadMetadata(memo: VoiceMemo) async throws {
        // Insert record into 'memos' table
        try await client.database
            .from("memos")
            .insert(memo)
            .execute()
    }
    
    func uploadAudioFile(fileURL: URL, fileName: String) async throws -> URL {
        let fileData = try Data(contentsOf: fileURL)
        
        // Upload the file to "audio_memos" storage bucket using Supabase Storage
        try await client.storage
            .from("audio_memos")
            .upload(
                path: fileName,
                file: fileData,
                options: FileOptions(contentType: "audio/m4a")
            )
        
        // Retrieve the public URL for the newly uploaded file
        let publicURL = try client.storage.from("audio_memos").getPublicUrl(path: fileName)
        return publicURL
    }
    
    func fetchMemos() async throws -> [VoiceMemo] {
        let response: [VoiceMemo] = try await client.database
            .from("memos")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
}
