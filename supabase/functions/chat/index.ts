// Supabase Edge Function: Anthropic API proxy
// Supports both non-streaming (original behaviour) and SSE streaming, chosen
// via a `stream: true` flag in the request body. Streaming removes the wall-
// clock cliff for long generations — iOS `URLSession.bytes()` keeps the
// connection open and each chunk resets the read timer.

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Builds the Anthropic request body. Unpacks the iOS body into Anthropic's
// shape and carries the streaming flag through.
function buildAnthropicBody(body: Record<string, unknown>): Record<string, unknown> {
  return {
    model: body.model || "claude-sonnet-4-6",
    max_tokens: body.max_tokens || 1024,
    system: body.system,
    messages: body.messages,
    tools: body.tools,
    tool_choice: body.tool_choice || { type: "auto" },
    stream: body.stream === true,
  };
}

// Non-streaming call with 429/529 retry. Used by the agent loop and the
// older one-shot generators that haven't migrated to streaming yet.
async function callAnthropic(body: Record<string, unknown>, attempt = 1): Promise<Response> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(buildAnthropicBody({ ...body, stream: false })),
  });

  if ((res.status === 429 || res.status === 529) && attempt < 3) {
    const delay = Math.pow(2, attempt) * 1000;
    await new Promise((r) => setTimeout(r, delay));
    return callAnthropic(body, attempt + 1);
  }

  return res;
}

// Streaming call — forwards Anthropic's SSE response body straight through
// to the iOS client. No retry (can't resume mid-stream); the caller is
// responsible for retrying a failed stream.
async function callAnthropicStreaming(body: Record<string, unknown>): Promise<Response> {
  return await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(buildAnthropicBody({ ...body, stream: true })),
  });
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Validate the user's JWT. We verify by calling /auth/v1/user directly
    // instead of using supabase-js: the Deno build of @supabase/supabase-js
    // loaded via esm.sh doesn't reliably verify ES256-signed tokens that
    // projects with asymmetric JWT signing keys now issue. A direct fetch to
    // the auth endpoint uses the same verification path PostgREST uses, which
    // we've confirmed works with our current project config.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        Authorization: authHeader,
        apikey: SUPABASE_ANON_KEY,
      },
    });
    if (!userRes.ok) {
      const preview = await userRes.text();
      return new Response(
        JSON.stringify({ error: "Unauthorized", detail: preview.slice(0, 200) }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const body = await req.json();
    const wantsStream = body.stream === true;

    if (wantsStream) {
      // Streaming path — forward the Anthropic SSE response body directly.
      // If Anthropic returned an error status, surface it as JSON instead of
      // a broken stream so the iOS client can render a helpful error.
      const anthropicRes = await callAnthropicStreaming(body);
      if (!anthropicRes.ok) {
        const preview = await anthropicRes.text();
        return new Response(
          JSON.stringify({ error: `Anthropic HTTP ${anthropicRes.status}`, detail: preview.slice(0, 400) }),
          {
            status: anthropicRes.status,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
      return new Response(anthropicRes.body, {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          Connection: "keep-alive",
        },
      });
    }

    // Non-streaming path — unchanged from the original behaviour.
    const anthropicRes = await callAnthropic(body);
    const data = await anthropicRes.json();

    return new Response(JSON.stringify(data), {
      status: anthropicRes.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
