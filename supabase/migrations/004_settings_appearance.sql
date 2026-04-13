-- Three-way appearance preference: 'system' | 'light' | 'dark'.
-- Left dark_mode column in place for backward compatibility; new clients
-- read/write appearance, old rows fall back to dark_mode when appearance
-- is NULL.

ALTER TABLE settings ADD COLUMN appearance TEXT;
