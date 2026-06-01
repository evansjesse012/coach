import {
  pgTable,
  text,
  integer,
  smallint,
  numeric,
  jsonb,
  uuid,
  timestamp,
  boolean,
} from "drizzle-orm/pg-core";

/**
 * Drizzle schema — TYPES FOR QUERIES ONLY.
 *
 * The single source of truth for the database schema is the SQL files in
 * ../../supabase/migrations. These definitions mirror those tables so the
 * backend gets type-safe, compiler-checked queries. When you add a migration,
 * update the matching definition here.
 */

// --- Existing (pre-backend) tables the API needs to read/write ---------------

// training_plans.id is TEXT (not UUID); weekly_plans is the JSONB blob the
// Phase 1 endpoints edit before normalization (001_initial_schema.sql).
export const trainingPlans = pgTable("training_plans", {
  id: text("id").primaryKey(),
  userId: uuid("user_id").notNull(),
  totalWeeks: integer("total_weeks"),
  currentWeek: integer("current_week"),
  currentPhase: integer("current_phase"),
  phases: jsonb("phases").notNull(),
  weeklyPlans: jsonb("weekly_plans").default({}),
  updatedAt: timestamp("updated_at", { withTimezone: true }),
});

// Global exercise catalog, keyed by stable slug (007/008). Strength
// prescriptions link to this by slug.
export const exercises = pgTable("exercises", {
  slug: text("slug").primaryKey(),
  name: text("name").notNull(),
  bodyPart: text("body_part").notNull(),
  category: text("category").notNull(),
});

// --- New normalized tables (Phase 2 — migration 014) -------------------------

export const prescribedWorkouts = pgTable("prescribed_workouts", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  planId: text("plan_id").notNull(),
  weekNumber: integer("week_number").notNull(),
  day: smallint("day").notNull(),
  position: smallint("position").notNull().default(0),
  type: text("type").notNull(),
  label: text("label"),
  duration: integer("duration"),
  distance: numeric("distance"),
  zone: text("zone"),
  pace: text("pace"),
  effortCategory: text("effort_category"),
  priority: text("priority"),
  purpose: text("purpose"),
  detail: jsonb("detail").default({}),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
});

export const prescribedExercises = pgTable("prescribed_exercises", {
  id: uuid("id").primaryKey().defaultRandom(),
  prescribedWorkoutId: uuid("prescribed_workout_id").notNull(),
  catalogExerciseSlug: text("catalog_exercise_slug"),
  position: smallint("position").notNull().default(0),
  prescription: jsonb("prescription").default({}),
});

export const workoutCompletions = pgTable("workout_completions", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  prescribedWorkoutId: uuid("prescribed_workout_id"),
  status: text("status").notNull(),
  actualDuration: integer("actual_duration"),
  actualDistance: numeric("actual_distance"),
  actualSport: text("actual_sport"),
  rpe: smallint("rpe"),
  fatigue: smallint("fatigue"),
  athleteNote: text("athlete_note"),
  completionNote: text("completion_note"),
  linkedWorkoutId: uuid("linked_workout_id"),
  resolvedAt: timestamp("resolved_at", { withTimezone: true }),
  needsReview: boolean("needs_review").default(false),
});

// --- Adherence read-model (Phase 3 — migration 015) --------------------------

export const weekAdherence = pgTable("week_adherence", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull(),
  planId: text("plan_id").notNull(),
  weekNumber: integer("week_number").notNull(),
  phase: integer("phase"),
  prescribed: integer("prescribed").notNull().default(0),
  completed: integer("completed").notNull().default(0),
  shortened: integer("shortened").notNull().default(0),
  missed: integer("missed").notNull().default(0),
  substituted: integer("substituted").notNull().default(0),
  bySport: jsonb("by_sport").default({}),
  adherencePct: numeric("adherence_pct"),
  snapshotId: uuid("snapshot_id"),
  computedAt: timestamp("computed_at", { withTimezone: true }).defaultNow(),
});
