import { createMiddleware } from "hono/factory";
import { HTTPException } from "hono/http-exception";
import { env } from "../env.js";

/**
 * JWT verification middleware.
 *
 * Verifies the caller's Supabase token exactly the way the edge function does:
 * by calling ${SUPABASE_URL}/auth/v1/user with the bearer token + anon key.
 * This is required because the project uses asymmetric ES256 signing keys —
 * local secret verification would not work (see chat/index.ts:74-93 and §3.2
 * of the plan). The verified user's id is attached to the context as `userId`
 * and is the ONLY trusted source of identity; request bodies never assert it.
 */
export type AuthVars = { userId: string };

interface SupabaseUser {
  id: string;
}

export const requireAuth = createMiddleware<{ Variables: AuthVars }>(async (c, next) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader) {
    throw new HTTPException(401, { message: "Missing authorization" });
  }

  const res = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: {
      Authorization: authHeader,
      apikey: env.SUPABASE_ANON_KEY,
    },
  });

  if (!res.ok) {
    throw new HTTPException(401, { message: "Unauthorized" });
  }

  const user = (await res.json()) as SupabaseUser;
  if (!user?.id) {
    throw new HTTPException(401, { message: "Unauthorized" });
  }

  c.set("userId", user.id);
  await next();
});
