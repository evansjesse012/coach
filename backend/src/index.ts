import { serve } from "@hono/node-server";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { HTTPException } from "hono/http-exception";
import { env } from "./env.js";
import { pingDatabase, closeDatabase } from "./db/client.js";
import { planRoutes } from "./routes/plan.js";

const app = new Hono();

app.use("*", logger());
app.use("*", cors());

// Liveness + DB connectivity. Proves the whole pipe in Phase 0.
app.get("/health", async (c) => {
  const dbOk = await pingDatabase();
  return c.json({ status: dbOk ? "ok" : "degraded", db: dbOk }, dbOk ? 200 : 503);
});

app.route("/", planRoutes);

// Uniform JSON error shape so the iOS client can render failures sensibly.
app.onError((err, c) => {
  if (err instanceof HTTPException) {
    return c.json({ error: err.message }, err.status);
  }
  console.error(err);
  return c.json({ error: "internal_error" }, 500);
});

const server = serve({ fetch: app.fetch, port: env.PORT }, (info) => {
  console.log(`coach-backend listening on :${info.port}`);
});

// Graceful shutdown so Railway deploys/restarts drain cleanly.
const shutdown = async () => {
  server.close();
  await closeDatabase();
  process.exit(0);
};
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
