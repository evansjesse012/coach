// Supabase Edge Function: ElevenLabs TTS proxy
// Generates speech audio from text using ElevenLabs API.
// For Goggins mode, uses a custom cloned voice trained on public podcast/audiobook audio.
// Falls back to a default deep male voice if cloned voice isn't available.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ELEVENLABS_API_KEY = Deno.env.get("ELEVENLABS_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// Voice IDs — update GOGGINS_VOICE_ID after training the cloned voice in ElevenLabs
const GOGGINS_VOICE_ID = Deno.env.get("ELEVENLABS_GOGGINS_VOICE_ID") || "";
const DEFAULT_VOICE_ID = "pNInz6obpgDQGcFmaJgB"; // "Adam" — deep male fallback

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Validate JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!ELEVENLABS_API_KEY) {
      return new Response(
        JSON.stringify({ error: "ElevenLabs not configured" }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const body = await req.json();
    const text = body.text as string;
    const voice = body.voice as string; // "goggins" or default

    if (!text) {
      return new Response(JSON.stringify({ error: "Missing text" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Select voice ID based on personality
    const voiceId =
      voice === "goggins" && GOGGINS_VOICE_ID
        ? GOGGINS_VOICE_ID
        : DEFAULT_VOICE_ID;

    // Voice settings — tuned for coaching delivery
    const voiceSettings = body.voice_settings || {
      stability: voice === "goggins" ? 0.75 : 0.5,
      similarity_boost: voice === "goggins" ? 0.85 : 0.75,
      style: voice === "goggins" ? 0.4 : 0.2,
      use_speaker_boost: true,
    };

    const ttsRes = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "xi-api-key": ELEVENLABS_API_KEY,
        },
        body: JSON.stringify({
          text,
          model_id: body.model_id || "eleven_turbo_v2",
          voice_settings: voiceSettings,
        }),
      },
    );

    if (!ttsRes.ok) {
      const errText = await ttsRes.text();
      return new Response(
        JSON.stringify({ error: "TTS failed", details: errText }),
        {
          status: ttsRes.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Stream audio bytes back to client
    const audioData = await ttsRes.arrayBuffer();

    return new Response(audioData, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "audio/mpeg",
        "Content-Length": audioData.byteLength.toString(),
      },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
