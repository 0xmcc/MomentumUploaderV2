# Momentum Uploader V2 - NVIDIA Parakeet + Supabase Voice Memos

This directory contains the Swift source files for a macOS and iOS Voice Memos application that records audio, uploads it to Supabase via `supabase-swift`, and passes the audio payload to the NVIDIA Parakeet Speech-to-Text inference model for transcriptions.

These files have been generated to be imported easily into a fresh Xcode project. 

## 🛠️ To-Do Checklist

To fully run this application and make it complete, please accomplish the following tasks:

- [ ] **Create an Xcode Workspace / Project**:
  - Open Xcode and select **File > New > Project**.
  - Choose **Multiplatform > App** (or iOS App with Mac Catalyst / macOS App).
  - Name your project `MomentumApp` and assure SwiftUI is selected as the Interface.
  - Drag and drop the `Models`, `Views`, `ViewModels`, and `Managers` folders (from where these files currently reside) into your new Xcode project tree.

- [ ] **Configure Supabase Details**:
  - Get your instance configuration from your [Supabase Dashboard](https://supabase.com/dashboard).
  - Open `MomentumApp/Managers/SupabaseManager.swift` and replace `"YOUR_SUPABASE_URL"` and `"YOUR_SUPABASE_ANON_KEY"` with your live environment tokens.

- [ ] **Set up Supabase Tables & Storage**:
  - In Supabase SQL Editor, create the table for the application:
    ```sql
    create table public.memos (
        id uuid primary key,
        created_at timestamp with time zone default timezone('utc'::text, now()) not null,
        title text,
        audio_url text,
        transcription text,
        duration double precision
    );
    ```
  - Create a Supabase Storage bucket named `audio_memos` and configure its RLS (Row Level Security) permissions or set it to **Public** for uploading and reading files.

- [ ] **Configure NVIDIA NIM Details**:
  - Procure an execution API Key from your [NVIDIA Developer account](https://build.nvidia.com) routing to the Parakeet endpoints.
  - Open `MomentumApp/Managers/TranscriptionManager.swift` and replace `"YOUR_NVIDIA_API_KEY"` with your key.

- [ ] **Install Swift Package Dependencies**:
  - Go to **File > Add Package Dependencies...** in Xcode.
  - Enter the URL for the official Supabase Swift client: `https://github.com/supabase/supabase-swift`.
  - Add it into your targets.

- [ ] **Grant Required Permissions `Info.plist`**:
  - Navigate to your target's **Info** tab.
  - Add the `NSMicrophoneUsageDescription` (`Privacy - Microphone Usage Description`) string. For example: *"This app requires microphone access to record voice memos."* (Required to prevent crashes on launch / start of recording).

- [ ] **Finish Audio Playback Capability**:
  - Currently, the list view allows visualization of the metadata, transcript text, and timestamp.
  - Use `AVPlayer(url: URL(string: memo.audioFileURL!)!)` inside a new component (e.g., `PlaybackView` or inline inside `ContentView` elements) to actually play back the recordings over the speakers.

- [ ] **Polish UI and Feedback**:
  - Add more comprehensive states, e.g., permission checks before starting a recording.
  - Implement a way to delete voice memos. 

Happy building!
