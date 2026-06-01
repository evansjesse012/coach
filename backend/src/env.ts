import { z } from "zod";

/**
 * Environment configuration, validated once at startup.
 *
 * We fail fast: if a required variable is missing, the process exits with a
 * clear message rather than throwing deep inside a request later. ANTHROPIC_API_KEY
 * is optional for now — it is only needed once the agent loop moves server-side
 * (Phase 4 of BACKEND_FOUNDATION_PLAN.md).
 */
const schema = z.object({
  DATABASE_URL: z.string().min(1, "DATABASE_URL is required (Supabase pooled connection string)"),
  SUPABASE_URL: z.string().url("SUPABASE_URL must be a valid URL"),
  SUPABASE_ANON_KEY: z.string().min(1, "SUPABASE_ANON_KEY is required"),
  PORT: z.coerce.number().int().positive().default(8080),
  ANTHROPIC_API_KEY: z.string().optional(),
});

export type Env = z.infer<typeof schema>;

function loadEnv(): Env {
  const parsed = schema.safeParse(process.env);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `  - ${i.path.join(".")}: ${i.message}`).join("\n");
    console.error(`Invalid environment configuration:\n${issues}`);
    process.exit(1);
  }
  return parsed.data;
}

export const env = loadEnv();
