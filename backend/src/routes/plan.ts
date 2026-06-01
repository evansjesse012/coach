import { Hono } from "hono";
import { requireAuth, type AuthVars } from "../middleware/auth.js";

/**
 * Phase 1 mutation endpoints — the server seam.
 *
 * These are the intent-named replacements for the client-side tools in
 * ToolExecutor.swift. They are scaffolded here with auth wired and a clear
 * 501 body so Phase 0 proves the pipe (client → authed endpoint → backend)
 * end to end. Phase 1 fills in each handler by porting the corresponding blob
 * op from Swift to TypeScript (still operating on training_plans.weekly_plans,
 * no schema change). Phase 2 repoints them at the normalized rows.
 *
 * Mapping to today's tools:
 *   POST /plan/patch-week        ← patch_weekly_plan
 *   POST /plan/save-week         ← save_weekly_plan
 *   POST /plan/generate-week     ← generate_week_plan
 *   POST /workouts/log           ← log_workout
 *   POST /weekly-review/complete ← complete_weekly_review
 */
export const planRoutes = new Hono<{ Variables: AuthVars }>();

planRoutes.use("*", requireAuth);

const notImplemented = (intent: string) => ({
  error: "not_implemented",
  intent,
  phase: "Phase 1",
  detail: `'${intent}' endpoint is scaffolded; handler lands in Phase 1 (see BACKEND_FOUNDATION_PLAN.md §5).`,
});

planRoutes.post("/plan/patch-week", (c) => c.json(notImplemented("patch_weekly_plan"), 501));
planRoutes.post("/plan/save-week", (c) => c.json(notImplemented("save_weekly_plan"), 501));
planRoutes.post("/plan/generate-week", (c) => c.json(notImplemented("generate_week_plan"), 501));
planRoutes.post("/workouts/log", (c) => c.json(notImplemented("log_workout"), 501));
planRoutes.post("/weekly-review/complete", (c) => c.json(notImplemented("complete_weekly_review"), 501));
