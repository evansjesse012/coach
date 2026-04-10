// app/api/chat/route.js
//
// Updated to support tool use.
// The only change from the original: we now pass through
// tools and tool_choice from the browser request.
// The API key stays here — never touches the browser.

export async function POST(request) {
  const body = await request.json();

  const payload = {
    model:      'claude-sonnet-4-20250514',
    max_tokens: body.max_tokens || 1024,
    system:     body.system,
    messages:   body.messages,
  };

  // Pass tools through if provided
  if (body.tools?.length) {
    payload.tools       = body.tools;
    payload.tool_choice = body.tool_choice || { type: 'auto' };
  }

  const MAX_RETRIES = 3;

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method:  'POST',
      headers: {
        'Content-Type':      'application/json',
        'x-api-key':         process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify(payload),
    });

    if (response.ok) {
      const data = await response.json();
      return Response.json(data);
    }

    // Retry on 429 (rate limit) unless this is the last attempt
    if (response.status === 429 && attempt < MAX_RETRIES - 1) {
      const retryAfter = response.headers.get('retry-after');
      const waitMs = retryAfter
        ? parseFloat(retryAfter) * 1000
        : Math.min(1000 * Math.pow(2, attempt), 8000) + Math.random() * 500;
      await new Promise(r => setTimeout(r, waitMs));
      continue;
    }

    // Non-429 error or final 429 attempt: return error to client
    const error = await response.text();
    const resHeaders = { 'Content-Type': 'application/json' };
    const retryAfter = response.headers.get('retry-after');
    if (retryAfter) resHeaders['Retry-After'] = retryAfter;

    return new Response(
      JSON.stringify({
        error: response.status === 429
          ? 'Rate limited — too many requests. Please wait a moment.'
          : `Anthropic API error: ${response.status}`,
        detail: error,
        isRateLimit: response.status === 429,
      }),
      { status: response.status, headers: resHeaders }
    );
  }
}
