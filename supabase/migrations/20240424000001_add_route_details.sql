ALTER TABLE public.routes
ADD COLUMN IF NOT EXISTS estimated_distance_mi NUMERIC,
ADD COLUMN IF NOT EXISTS estimated_duration_minutes INTEGER,
ADD COLUMN IF NOT EXISTS alert_lead_time_minutes INTEGER DEFAULT 30;

-- Update RLS if needed (not needed as these are just new columns)
