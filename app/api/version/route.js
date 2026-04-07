// Returns build ID. This module is evaluated once at build time.
// On each new deploy, Next.js rebuilds and BUILD_ID gets a new value.
// Using force-static so the value is baked in at build, not re-evaluated per request.

const BUILD_ID = process.env.VERCEL_GIT_COMMIT_SHA || Date.now().toString();

export async function GET() {
  return new Response(JSON.stringify({ v: BUILD_ID }), {
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-cache, no-store, must-revalidate' },
  });
}
