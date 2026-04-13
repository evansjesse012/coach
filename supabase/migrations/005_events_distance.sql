-- Explicit distance/length field on events. Previously inferred from
-- preset_id, which left custom goals with no way to record their length.

ALTER TABLE events ADD COLUMN distance TEXT;
