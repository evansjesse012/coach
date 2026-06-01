import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { env } from "../env.js";
import * as schema from "./schema.js";

/**
 * Postgres connection for the backend.
 *
 * The backend connects as the trusted writer (service-role / direct connection)
 * which bypasses RLS by design — ownership is enforced in code by filtering on
 * the user_id derived from the verified JWT. See §3.2 of the plan.
 *
 * `prepare: false` is recommended when using Supabase's transaction-mode pooler
 * (port 6543), which does not support prepared statements.
 */
const queryClient = postgres(env.DATABASE_URL, {
  prepare: false,
  max: 10,
});

export const db = drizzle(queryClient, { schema });

/** Lightweight connectivity check used by the /health endpoint. */
export async function pingDatabase(): Promise<boolean> {
  try {
    await queryClient`select 1`;
    return true;
  } catch {
    return false;
  }
}

export async function closeDatabase(): Promise<void> {
  await queryClient.end({ timeout: 5 });
}
