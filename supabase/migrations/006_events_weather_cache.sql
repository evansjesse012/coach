-- Cache weather payloads (including hourly series and AI impact
-- assessment) on the event so we don't re-fetch Open-Meteo on every
-- race detail open and so the AI impact call only runs when weather
-- data actually changes.

ALTER TABLE events ADD COLUMN weather_data JSONB;
