-- Create a function to get global application counts that bypasses RLS
CREATE OR REPLACE FUNCTION get_global_application_counts()
RETURNS TABLE (internship_id uuid, application_count bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    internship_id,
    COUNT(*) as application_count
  FROM activity_logs
  WHERE event = 'apply'
  GROUP BY internship_id;
$$;