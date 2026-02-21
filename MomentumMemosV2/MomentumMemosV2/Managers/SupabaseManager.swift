import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    // TODO: Connect this to your Supabase project URL and anon key.
    // Replace the placeholders below.
    let client = SupabaseClient(
        supabaseURL: URL(string: "https://wyzcizewwswwnqllzoyl.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind5emNpemV3d3N3d25xbGx6b3lsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc5NDMyMjIsImV4cCI6MjA2MzUxOTIyMn0.rjTOa1w-nmhWkWX1_XWPgiwNYjSeRwgl5N1NndGVUxI"
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
