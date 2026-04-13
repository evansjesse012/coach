-- 007_exercise_catalog.sql
-- Seeds the built-in exercise catalog and extends custom_exercises with slugs.

-- ─── Global exercise catalog ──────────────────────────────────────────────────
CREATE TABLE exercises (
    slug TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    body_part TEXT NOT NULL,
    category TEXT NOT NULL,
    exercise_type TEXT NOT NULL,   -- 'weighted' | 'bodyweight' | 'banded' | 'timed' | 'cardio-drill'
    primary_muscles TEXT[] NOT NULL DEFAULT '{}',
    secondary_muscles TEXT[] NOT NULL DEFAULT '{}',
    is_built_in BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INT NOT NULL DEFAULT 0
);

ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Exercises are readable by everyone"
    ON exercises FOR SELECT USING (TRUE);
-- No insert/update/delete policies — writes are admin-only (service role).

-- ─── custom_exercises: add slug column ────────────────────────────────────────
-- Backfill uses the same rule as Swift's String.slugified:
--   lowercase → regex replace runs of [^a-z0-9] with '-' → trim leading/trailing '-'
ALTER TABLE custom_exercises ADD COLUMN slug TEXT;

UPDATE custom_exercises
    SET slug = trim(BOTH '-' FROM regexp_replace(lower(name), '[^a-z0-9]+', '-', 'g'));

ALTER TABLE custom_exercises ALTER COLUMN slug SET NOT NULL;
ALTER TABLE custom_exercises
    ADD CONSTRAINT custom_exercises_user_slug_unique UNIQUE (user_id, slug);

-- ─── Seed the catalog ─────────────────────────────────────────────────────────
INSERT INTO exercises (slug, name, body_part, category, exercise_type, primary_muscles, sort_order) VALUES
-- Back
('deadlift',                       'Deadlift',                       'Back',      'Barbell',    'weighted',   ARRAY['back','hamstrings','glutes'], 100),
('sumo-deadlift',                   'Sumo Deadlift',                  'Back',      'Barbell',    'weighted',   ARRAY['glutes','hamstrings','back'], 101),
('romanian-deadlift',               'Romanian Deadlift',              'Back',      'Barbell',    'weighted',   ARRAY['hamstrings','glutes','back'], 102),
('barbell-row',                     'Barbell Row',                    'Back',      'Barbell',    'weighted',   ARRAY['lats','upper back'], 103),
('pendlay-row',                     'Pendlay Row',                    'Back',      'Barbell',    'weighted',   ARRAY['lats','upper back'], 104),
('t-bar-row',                       'T-Bar Row',                      'Back',      'Barbell',    'weighted',   ARRAY['lats','upper back'], 105),
('seated-cable-row',                'Seated Cable Row',               'Back',      'Cable',      'weighted',   ARRAY['lats','upper back'], 106),
('lat-pulldown',                    'Lat Pulldown',                   'Back',      'Cable',      'weighted',   ARRAY['lats'], 107),
('pull-up',                         'Pull Up',                        'Back',      'Bodyweight', 'bodyweight', ARRAY['lats','biceps'], 108),
('chin-up',                         'Chin Up',                        'Back',      'Bodyweight', 'bodyweight', ARRAY['lats','biceps'], 109),
('face-pull',                       'Face Pull',                      'Back',      'Cable',      'weighted',   ARRAY['rear delts','upper back'], 110),
('shrug',                           'Shrug',                          'Back',      'Barbell',    'weighted',   ARRAY['traps'], 111),
('good-morning',                    'Good Morning',                   'Back',      'Barbell',    'weighted',   ARRAY['hamstrings','lower back'], 112),
-- Chest
('barbell-bench-press',             'Barbell Bench Press',            'Chest',     'Barbell',    'weighted',   ARRAY['chest','triceps','front delts'], 200),
('incline-bench-press',             'Incline Bench Press',            'Chest',     'Barbell',    'weighted',   ARRAY['upper chest','front delts'], 201),
('decline-bench-press',             'Decline Bench Press',            'Chest',     'Barbell',    'weighted',   ARRAY['lower chest','triceps'], 202),
('dumbbell-bench-press',            'Dumbbell Bench Press',           'Chest',     'Dumbbell',   'weighted',   ARRAY['chest','triceps'], 203),
('incline-dumbbell-press',          'Incline Dumbbell Press',         'Chest',     'Dumbbell',   'weighted',   ARRAY['upper chest'], 204),
('dumbbell-fly',                    'Dumbbell Fly',                   'Chest',     'Dumbbell',   'weighted',   ARRAY['chest'], 205),
('cable-fly',                       'Cable Fly',                      'Chest',     'Cable',      'weighted',   ARRAY['chest'], 206),
('pec-deck',                        'Pec Deck',                       'Chest',     'Machine',    'weighted',   ARRAY['chest'], 207),
('push-up',                         'Push Up',                        'Chest',     'Bodyweight', 'bodyweight', ARRAY['chest','triceps'], 208),
('dip',                             'Dip',                            'Chest',     'Bodyweight', 'bodyweight', ARRAY['chest','triceps'], 209),
-- Legs
('back-squat',                      'Back Squat',                     'Legs',      'Barbell',    'weighted',   ARRAY['quads','glutes'], 300),
('front-squat',                     'Front Squat',                    'Legs',      'Barbell',    'weighted',   ARRAY['quads','core'], 301),
('box-squat',                       'Box Squat',                      'Legs',      'Barbell',    'weighted',   ARRAY['glutes','quads'], 302),
('hack-squat',                      'Hack Squat',                     'Legs',      'Machine',    'weighted',   ARRAY['quads'], 303),
('leg-press',                       'Leg Press',                      'Legs',      'Machine',    'weighted',   ARRAY['quads','glutes'], 304),
('bulgarian-split-squat',           'Bulgarian Split Squat',          'Legs',      'Dumbbell',   'weighted',   ARRAY['quads','glutes'], 305),
('walking-lunge',                   'Walking Lunge',                  'Legs',      'Dumbbell',   'weighted',   ARRAY['quads','glutes'], 306),
('goblet-squat',                    'Goblet Squat',                   'Legs',      'Dumbbell',   'weighted',   ARRAY['quads','glutes'], 307),
('leg-extension',                   'Leg Extension',                  'Legs',      'Machine',    'weighted',   ARRAY['quads'], 308),
('lying-leg-curl',                  'Lying Leg Curl',                 'Legs',      'Machine',    'weighted',   ARRAY['hamstrings'], 309),
('seated-leg-curl',                 'Seated Leg Curl',                'Legs',      'Machine',    'weighted',   ARRAY['hamstrings'], 310),
('hip-thrust',                      'Hip Thrust',                     'Legs',      'Barbell',    'weighted',   ARRAY['glutes'], 311),
('glute-bridge',                    'Glute Bridge',                   'Legs',      'Barbell',    'weighted',   ARRAY['glutes'], 312),
('standing-calf-raise',             'Standing Calf Raise',            'Legs',      'Machine',    'weighted',   ARRAY['calves'], 313),
('seated-calf-raise',               'Seated Calf Raise',              'Legs',      'Machine',    'weighted',   ARRAY['calves'], 314),
-- Shoulders
('overhead-press',                  'Overhead Press',                 'Shoulders', 'Barbell',    'weighted',   ARRAY['front delts','triceps'], 400),
('seated-dumbbell-shoulder-press',  'Seated Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell',   'weighted',   ARRAY['front delts','side delts'], 401),
('arnold-press',                    'Arnold Press',                   'Shoulders', 'Dumbbell',   'weighted',   ARRAY['front delts','side delts'], 402),
('dumbbell-lateral-raise',          'Dumbbell Lateral Raise',         'Shoulders', 'Dumbbell',   'weighted',   ARRAY['side delts'], 403),
('cable-lateral-raise',             'Cable Lateral Raise',            'Shoulders', 'Cable',      'weighted',   ARRAY['side delts'], 404),
('rear-delt-fly',                   'Rear Delt Fly',                  'Shoulders', 'Dumbbell',   'weighted',   ARRAY['rear delts'], 405),
('upright-row',                     'Upright Row',                    'Shoulders', 'Barbell',    'weighted',   ARRAY['side delts','traps'], 406),
('landmine-press',                  'Landmine Press',                 'Shoulders', 'Barbell',    'weighted',   ARRAY['front delts','chest'], 407),
-- Arms
('barbell-curl',                    'Barbell Curl',                   'Arms',      'Barbell',    'weighted',   ARRAY['biceps'], 500),
('ez-bar-curl',                     'EZ-Bar Curl',                    'Arms',      'Barbell',    'weighted',   ARRAY['biceps'], 501),
('dumbbell-curl',                   'Dumbbell Curl',                  'Arms',      'Dumbbell',   'weighted',   ARRAY['biceps'], 502),
('hammer-curl',                     'Hammer Curl',                    'Arms',      'Dumbbell',   'weighted',   ARRAY['biceps','forearms'], 503),
('preacher-curl',                   'Preacher Curl',                  'Arms',      'Dumbbell',   'weighted',   ARRAY['biceps'], 504),
('close-grip-bench-press',          'Close-Grip Bench Press',         'Arms',      'Barbell',    'weighted',   ARRAY['triceps','chest'], 505),
('skull-crusher',                   'Skull Crusher',                  'Arms',      'Barbell',    'weighted',   ARRAY['triceps'], 506),
('tricep-pushdown',                 'Tricep Pushdown',                'Arms',      'Cable',      'weighted',   ARRAY['triceps'], 507),
('overhead-tricep-extension',       'Overhead Tricep Extension',      'Arms',      'Dumbbell',   'weighted',   ARRAY['triceps'], 508),
-- Core
('plank',                           'Plank',                          'Core',      'Bodyweight', 'timed',      ARRAY['core'], 600),
('side-plank',                      'Side Plank',                     'Core',      'Bodyweight', 'timed',      ARRAY['obliques','core'], 601),
('hanging-leg-raise',               'Hanging Leg Raise',              'Core',      'Bodyweight', 'bodyweight', ARRAY['abs','hip flexors'], 602),
('cable-crunch',                    'Cable Crunch',                   'Core',      'Cable',      'weighted',   ARRAY['abs'], 603),
('ab-wheel-rollout',                'Ab Wheel Rollout',               'Core',      'Bodyweight', 'bodyweight', ARRAY['abs'], 604),
('russian-twist',                   'Russian Twist',                  'Core',      'Bodyweight', 'bodyweight', ARRAY['obliques'], 605),
-- Olympic / Power (Full Body)
('power-clean',                     'Power Clean',                    'Full Body', 'Barbell',    'weighted',   ARRAY['glutes','back','quads'], 700),
('hang-clean',                      'Hang Clean',                     'Full Body', 'Barbell',    'weighted',   ARRAY['glutes','back','traps'], 701),
('clean-and-jerk',                  'Clean and Jerk',                 'Full Body', 'Barbell',    'weighted',   ARRAY['full body'], 702),
('snatch',                          'Snatch',                         'Full Body', 'Barbell',    'weighted',   ARRAY['full body'], 703),
('push-press',                      'Push Press',                     'Full Body', 'Barbell',    'weighted',   ARRAY['shoulders','triceps','legs'], 704);
