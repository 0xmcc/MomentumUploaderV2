import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const nvidiaApiKey = Deno.env.get("NVIDIA_API_KEY") ?? ""

const supabase = createClient(supabaseUrl, supabaseServiceKey)

serve(async (req) => {
  try {
    const { record } = await req.json()
    
    // We only process if transcription is explicitly saying "Processing..." to avoid loops
    if (record.transcript !== "Processing...") {
      return new Response("Not a processing task, skipping.", { status: 200 })
    }

    const audioUrl = record.audio_url
    if (!audioUrl) throw new Error("Missing audio_url")

    // Assuming audioUrl is the public URL, but verify if it's the path or public URL.
    // In our Swift app, audioFileURL is set to `publicAudioURL.absoluteString`.
    const fileResponse = await fetch(audioUrl)
    if (!fileResponse.ok) throw new Error(`Failed to fetch audio: ${fileResponse.statusText}`)
    
    const arrayBuffer = await fileResponse.arrayBuffer()
    const fileName = audioUrl.split('/').pop() || "audio.m4a"

    // Forward to NVIDIA Transcription API
    const formData = new FormData()
    formData.append("file", new File([arrayBuffer], fileName, { type: "audio/m4a" }))
    formData.append("model", "nvidia/parakeet-ctc-1.1b-asr")

    const nvidiaResponse = await fetch("https://integrate.api.nvidia.com/v1/audio/transcriptions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${nvidiaApiKey}`
      },
      body: formData
    })

    if (!nvidiaResponse.ok) {
      const errText = await nvidiaResponse.text()
      throw new Error(`NVIDIA API Error: ${nvidiaResponse.status} - ${errText}`)
    }

    const { text } = await nvidiaResponse.json()

    // Update the record in the database with the completed transcription
    const { error: updateError } = await supabase
      .from("memos")
      .update({ transcript: text })
      .eq("id", record.id)

    if (updateError) throw updateError

    return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } })

  } catch (err: any) {
    console.error("Transcription error:", err.message)
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: { "Content-Type": "application/json" } })
  }
})
