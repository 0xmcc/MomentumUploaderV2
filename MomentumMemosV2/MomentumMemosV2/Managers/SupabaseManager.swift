import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    private enum ConfigKeys {
        static let supabaseURL = "SUPABASE_URL"
        static let supabaseAnonKey = "SUPABASE_ANON_KEY"
    }

    private var cachedClient: SupabaseClient?
    
    init() {}

    private func configValue(for key: String) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[key], !envValue.isEmpty {
            return envValue
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String, !plistValue.isEmpty {
            return plistValue
        }

        return nil
    }

    private func getClient() throws -> SupabaseClient {
        if let client = cachedClient { return client }

        guard let urlString = configValue(for: ConfigKeys.supabaseURL) else {
            throw NSError(
                domain: "SupabaseManager",
                code: 1000,
                userInfo: [NSLocalizedDescriptionKey: "Missing configuration value for \(ConfigKeys.supabaseURL)."]
            )
        }

        guard let anonKey = configValue(for: ConfigKeys.supabaseAnonKey) else {
            throw NSError(
                domain: "SupabaseManager",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Missing configuration value for \(ConfigKeys.supabaseAnonKey)."]
            )
        }

        guard let supabaseURL = URL(string: urlString) else {
            throw NSError(
                domain: "SupabaseManager",
                code: 1100,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Supabase URL."]
            )
        }

        let client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: anonKey)
        cachedClient = client
        return client
    }
    
    func uploadMetadata(memo: VoiceMemo) async throws {
        let client = try getClient()
        // Insert record into 'memos' table
        try await client.database
            .from("memos")
            .insert(memo)
            .execute()
    }
    
    func uploadAudioFile(fileURL: URL, fileName: String) async throws -> URL {
        let client = try getClient()
        let fileData = try Data(contentsOf: fileURL)
        
        // Upload the file to "audio_memos" storage bucket using Supabase Storage
        try await client.storage
            .from("audio_memos")
            .upload(
                path: fileName,
                file: fileData,
                options: FileOptions(contentType: "audio/m4a")
            )
        
        let publicURL = try client.storage.from("audio_memos").getPublicURL(path: fileName)
        return publicURL
    }
    
    func fetchMemos() async throws -> [VoiceMemo] {
        let client = try getClient()
        let response: [VoiceMemo] = try await client.database
            .from("memos")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    // Listen for updates on the memos table (e.g. status changes from Edge Functions)
    func subscribeToMemos(onUpdate: @escaping () -> Void) async throws {
        let client = try getClient()
        let channel = client.channel("public:memos")
        
        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "memos"
        )
        
        await channel.subscribe()
        
        Task {
            for await _ in stream {
                onUpdate()
            }
        }
    }
}
