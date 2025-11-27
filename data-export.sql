-- ================================================
-- DATA EXPORT QUERIES
-- ================================================
-- Run these queries in your OLD Lovable Cloud project
-- to export existing data, then import into your new project
-- ================================================

-- ================================================
-- EXPORT PROFILES
-- ================================================
-- Copy the results and run as INSERT statements in new project

SELECT 
  'INSERT INTO public.profiles (id, name, email, avatar_url, whitelisted_email, created_at, updated_at) VALUES ' ||
  string_agg(
    format('(%L, %L, %L, %L, %L, %L, %L)',
      id, name, email, avatar_url, whitelisted_email, created_at, updated_at
    ), ', '
  ) || ';' as insert_statement
FROM public.profiles;

-- ================================================
-- EXPORT USER ROLES
-- ================================================

SELECT 
  'INSERT INTO public.user_roles (user_id, role, created_at) VALUES ' ||
  string_agg(
    format('(%L, %L, %L)',
      user_id, role::text, created_at
    ), ', '
  ) || ';' as insert_statement
FROM public.user_roles;

-- ================================================
-- EXPORT INTERNSHIPS
-- ================================================

SELECT 
  'INSERT INTO public.internships (id, title, company, location, duration, description, major, industry, views, apply_clicks, application_method, application_value, image_url, expires_at, listing_duration, created_by, created_at, updated_at, deleted_at) VALUES ' ||
  string_agg(
    format('(%L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L)',
      id, title, company, location, duration, description, 
      major, industry, views, apply_clicks, 
      application_method, application_value, image_url,
      expires_at, listing_duration, created_by,
      created_at, updated_at, deleted_at
    ), ', '
  ) || ';' as insert_statement
FROM public.internships;

-- ================================================
-- EXPORT USER INTERACTIONS
-- ================================================

SELECT 
  'INSERT INTO public.user_internship_interactions (user_id, internship_id, is_starred, is_viewed, created_at, updated_at) VALUES ' ||
  string_agg(
    format('(%L, %L, %L, %L, %L, %L)',
      user_id, internship_id, is_starred, is_viewed, created_at, updated_at
    ), ', '
  ) || ';' as insert_statement
FROM public.user_internship_interactions;

-- ================================================
-- EXPORT ACTIVITY LOGS
-- ================================================

SELECT 
  'INSERT INTO public.activity_logs (user_id, internship_id, event, method, metadata, created_at) VALUES ' ||
  string_agg(
    format('(%L, %L, %L, %L, %L, %L)',
      user_id, internship_id, event, method, metadata, created_at
    ), ', '
  ) || ';' as insert_statement
FROM public.activity_logs;

-- ================================================
-- EXPORT MONTHLY APPLICATION STATS
-- ================================================

SELECT 
  'INSERT INTO public.monthly_application_stats (year, month, count, created_at, updated_at) VALUES ' ||
  string_agg(
    format('(%L, %L, %L, %L, %L)',
      year, month, count, created_at, updated_at
    ), ', '
  ) || ';' as insert_statement
FROM public.monthly_application_stats;

-- ================================================
-- ALTERNATIVE: EXPORT AS CSV
-- ================================================
-- If the above queries are too large, export each table as CSV:

-- Profiles
COPY (SELECT * FROM public.profiles) TO STDOUT WITH CSV HEADER;

-- User Roles
COPY (SELECT * FROM public.user_roles) TO STDOUT WITH CSV HEADER;

-- Internships
COPY (SELECT * FROM public.internships) TO STDOUT WITH CSV HEADER;

-- User Interactions
COPY (SELECT * FROM public.user_internship_interactions) TO STDOUT WITH CSV HEADER;

-- Activity Logs
COPY (SELECT * FROM public.activity_logs) TO STDOUT WITH CSV HEADER;

-- Monthly Stats
COPY (SELECT * FROM public.monthly_application_stats) TO STDOUT WITH CSV HEADER;

-- ================================================
-- NOTES ON DATA IMPORT
-- ================================================
-- 
-- 1. Run migration-to-own-supabase.sql FIRST in your new project
-- 2. Then run the INSERT statements generated above
-- 3. User authentication data CANNOT be migrated - users must:
--    - Sign up again with new accounts, OR
--    - Use password reset to create new passwords
-- 4. Files in storage buckets must be manually transferred
--    (download from old project, upload to new project)
-- ================================================
