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

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method:  'POST',
    headers: {
      'Content-Type':      'application/json',
      'x-api-key':         process.env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const error = await response.text();
    return new Response(
      JSON.stringify({ error: `Anthropic API error: ${response.status}`, detail: error }),
      { status: response.status, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const data = await response.json();
  return Response.json(data);
}
