-- ================================================
-- COMPLETE MIGRATION SCRIPT FOR SELF-MANAGED SUPABASE
-- ================================================
-- Run this entire script in your new Supabase project's SQL Editor
-- ================================================

-- ================================================
-- STEP 1: CREATE CUSTOM TYPES
-- ================================================

CREATE TYPE public.app_role AS ENUM ('admin', 'student');

-- ================================================
-- STEP 2: CREATE TABLES
-- ================================================

-- Profiles table (extends auth.users with additional info)
CREATE TABLE public.profiles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  avatar_url TEXT,
  whitelisted_email BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- User roles table (for role-based access control)
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  role app_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, role)
);

-- Internships table
CREATE TABLE public.internships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  company TEXT NOT NULL,
  location TEXT NOT NULL,
  duration TEXT NOT NULL,
  description TEXT NOT NULL,
  major TEXT[] NOT NULL DEFAULT '{}',
  industry TEXT[] NOT NULL DEFAULT '{}',
  views INTEGER NOT NULL DEFAULT 0,
  apply_clicks INTEGER NOT NULL DEFAULT 0,
  application_method TEXT NOT NULL,
  application_value TEXT NOT NULL,
  image_url TEXT,
  expires_at TIMESTAMP WITH TIME ZONE,
  listing_duration INTEGER,
  created_by TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- User internship interactions (starred/viewed)
CREATE TABLE public.user_internship_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  internship_id UUID NOT NULL REFERENCES public.internships(id) ON DELETE CASCADE,
  is_starred BOOLEAN NOT NULL DEFAULT false,
  is_viewed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, internship_id)
);

-- Activity logs (tracks apply events)
CREATE TABLE public.activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT,
  internship_id UUID NOT NULL REFERENCES public.internships(id) ON DELETE CASCADE,
  event TEXT NOT NULL,
  method TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Monthly application statistics
CREATE TABLE public.monthly_application_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  year INTEGER NOT NULL,
  month INTEGER NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE(year, month)
);

-- OTP verifications (for passwordless auth if needed)
CREATE TABLE public.otp_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  otp_code TEXT NOT NULL,
  purpose TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '10 minutes'),
  verified_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- OTP rate limits
CREATE TABLE public.otp_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  ip_address TEXT,
  attempt_count INTEGER NOT NULL DEFAULT 1,
  window_start TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  locked_until TIMESTAMP WITH TIME ZONE
);

-- ================================================
-- STEP 3: CREATE INDEXES
-- ================================================

CREATE INDEX idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX idx_internships_deleted_at ON public.internships(deleted_at);
CREATE INDEX idx_internships_created_at ON public.internships(created_at);
CREATE INDEX idx_activity_logs_user_id ON public.activity_logs(user_id);
CREATE INDEX idx_activity_logs_internship_id ON public.activity_logs(internship_id);
CREATE INDEX idx_activity_logs_created_at ON public.activity_logs(created_at);
CREATE INDEX idx_activity_logs_event ON public.activity_logs(event);
CREATE INDEX idx_monthly_stats_year_month ON public.monthly_application_stats(year, month);

-- ================================================
-- STEP 4: CREATE SECURITY DEFINER FUNCTIONS
-- ================================================

-- Function to check if user has a specific role (prevents RLS recursion)
CREATE OR REPLACE FUNCTION public.has_role(_user_id TEXT, _role app_role)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin(check_user_id TEXT DEFAULT (auth.uid())::text)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = check_user_id AND role = 'admin'
  )
$$;

-- ================================================
-- STEP 5: CREATE UTILITY FUNCTIONS
-- ================================================

-- Auto-update updated_at column
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Handle new user creation (auto-create profile)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    NEW.email
  );
  
  -- Assign default student role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id::text, 'student');
  
  RETURN NEW;
END;
$$;

-- Validate internship data
CREATE OR REPLACE FUNCTION public.validate_internship_data(
  p_title TEXT,
  p_company TEXT,
  p_location TEXT,
  p_description TEXT,
  p_application_value TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_title IS NULL OR length(trim(p_title)) < 1 OR length(p_title) > 200 THEN
    RAISE EXCEPTION 'Title must be between 1 and 200 characters';
  END IF;
  
  IF p_company IS NULL OR length(trim(p_company)) < 1 OR length(p_company) > 200 THEN
    RAISE EXCEPTION 'Company must be between 1 and 200 characters';
  END IF;
  
  IF p_location IS NULL OR length(trim(p_location)) < 1 OR length(p_location) > 200 THEN
    RAISE EXCEPTION 'Location must be between 1 and 200 characters';
  END IF;
  
  IF p_description IS NULL OR length(trim(p_description)) < 10 OR length(p_description) > 5000 THEN
    RAISE EXCEPTION 'Description must be between 10 and 5000 characters';
  END IF;
  
  IF p_application_value IS NULL OR length(trim(p_application_value)) < 1 THEN
    RAISE EXCEPTION 'Application value is required';
  END IF;
  
  RETURN true;
END;
$$;

-- Validation trigger function
CREATE OR REPLACE FUNCTION public.validate_internship_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.validate_internship_data(
    NEW.title,
    NEW.company,
    NEW.location,
    NEW.description,
    NEW.application_value
  );
  RETURN NEW;
END;
$$;

-- Increment monthly application count
CREATE OR REPLACE FUNCTION public.increment_monthly_application_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_year INTEGER;
  current_month INTEGER;
BEGIN
  IF NEW.event = 'apply' THEN
    current_year := EXTRACT(YEAR FROM NEW.created_at);
    current_month := EXTRACT(MONTH FROM NEW.created_at);
    
    INSERT INTO public.monthly_application_stats (year, month, count)
    VALUES (current_year, current_month, 1)
    ON CONFLICT (year, month)
    DO UPDATE SET 
      count = monthly_application_stats.count + 1,
      updated_at = NOW();
  END IF;
  
  RETURN NEW;
END;
$$;

-- Prevent email changes
CREATE OR REPLACE FUNCTION public.prevent_email_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.email IS DISTINCT FROM NEW.email THEN
    RAISE EXCEPTION 'Email cannot be changed after registration';
  END IF;
  RETURN NEW;
END;
$$;

-- Cleanup expired OTPs
CREATE OR REPLACE FUNCTION public.cleanup_expired_otps()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.otp_verifications
  WHERE expires_at < NOW() - INTERVAL '1 hour';
  
  DELETE FROM public.otp_rate_limits
  WHERE window_start < NOW() - INTERVAL '1 day';
END;
$$;

-- ================================================
-- STEP 6: CREATE TRIGGERS
-- ================================================

-- Auto-create profile when new user signs up
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Auto-update updated_at on profiles
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Auto-update updated_at on internships
CREATE TRIGGER update_internships_updated_at
  BEFORE UPDATE ON public.internships
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Auto-update updated_at on interactions
CREATE TRIGGER update_interactions_updated_at
  BEFORE UPDATE ON public.user_internship_interactions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Validate internship data on insert
CREATE TRIGGER validate_internship_insert
  BEFORE INSERT ON public.internships
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_internship_trigger();

-- Validate internship data on update
CREATE TRIGGER validate_internship_update
  BEFORE UPDATE ON public.internships
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_internship_trigger();

-- Increment monthly application count
CREATE TRIGGER increment_monthly_applications
  AFTER INSERT ON public.activity_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_monthly_application_count();

-- Prevent email changes on profiles
CREATE TRIGGER prevent_profile_email_change
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_email_change();

-- ================================================
-- STEP 7: ENABLE ROW LEVEL SECURITY
-- ================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.internships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_internship_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_application_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_rate_limits ENABLE ROW LEVEL SECURITY;

-- ================================================
-- STEP 8: CREATE RLS POLICIES
-- ================================================

-- Profiles policies
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING ((auth.uid())::text = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING ((auth.uid())::text = id)
  WITH CHECK ((auth.uid())::text = id);

CREATE POLICY "Admins can view all profiles"
  ON public.profiles FOR SELECT
  USING (has_role((auth.uid())::text, 'admin'));

CREATE POLICY "Admins can update all profiles"
  ON public.profiles FOR UPDATE
  USING (has_role((auth.uid())::text, 'admin'));

-- User roles policies
CREATE POLICY "Users can view own roles"
  ON public.user_roles FOR SELECT
  USING (user_id = (auth.uid())::text);

CREATE POLICY "Admins can manage all roles"
  ON public.user_roles FOR ALL
  USING (has_role((auth.uid())::text, 'admin'));

-- Internships policies
CREATE POLICY "Anyone can view active internships"
  ON public.internships FOR SELECT
  USING (deleted_at IS NULL);

CREATE POLICY "Admins can view all internships including deleted"
  ON public.internships FOR SELECT
  USING (has_role((auth.uid())::text, 'admin'));

CREATE POLICY "Admins can insert internships"
  ON public.internships FOR INSERT
  WITH CHECK (has_role((auth.uid())::text, 'admin'));

CREATE POLICY "Admins can update internships"
  ON public.internships FOR UPDATE
  USING (has_role((auth.uid())::text, 'admin'));

CREATE POLICY "Admins can delete internships"
  ON public.internships FOR DELETE
  USING (has_role((auth.uid())::text, 'admin'));

-- User internship interactions policies
CREATE POLICY "Users can view own interactions"
  ON public.user_internship_interactions FOR SELECT
  USING (user_id = (auth.uid())::text);

CREATE POLICY "Users can insert own interactions"
  ON public.user_internship_interactions FOR INSERT
  WITH CHECK (user_id = (auth.uid())::text);

CREATE POLICY "Users can update own interactions"
  ON public.user_internship_interactions FOR UPDATE
  USING (user_id = (auth.uid())::text);

CREATE POLICY "Admins can view all interactions"
  ON public.user_internship_interactions FOR SELECT
  USING (has_role((auth.uid())::text, 'admin'));

-- Activity logs policies
CREATE POLICY "Users can view their own activity logs"
  ON public.activity_logs FOR SELECT
  USING ((auth.uid())::text = user_id);

CREATE POLICY "Users can insert their own activity logs"
  ON public.activity_logs FOR INSERT
  WITH CHECK (((auth.uid())::text = user_id) OR (user_id IS NULL));

CREATE POLICY "Admins can view all activity logs"
  ON public.activity_logs FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = (auth.uid())::text
    AND user_roles.role = 'admin'
  ));

CREATE POLICY "Admins can delete activity logs"
  ON public.activity_logs FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_roles.user_id = (auth.uid())::text
    AND user_roles.role = 'admin'
  ));

-- Monthly stats policies
CREATE POLICY "Admins can view monthly stats"
  ON public.monthly_application_stats FOR SELECT
  USING (has_role((auth.uid())::text, 'admin'));

-- OTP policies (no direct access)
CREATE POLICY "No direct access to OTP verifications"
  ON public.otp_verifications FOR ALL
  USING (false);

CREATE POLICY "No direct access to rate limits"
  ON public.otp_rate_limits FOR ALL
  USING (false);

-- ================================================
-- STEP 9: ENABLE REALTIME (OPTIONAL)
-- ================================================

-- Uncomment if you want realtime updates
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.internships;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.activity_logs;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.user_internship_interactions;

-- ================================================
-- MIGRATION COMPLETE!
-- ================================================
-- Next steps:
-- 1. Create storage bucket 'internship-images' (see instructions below)
-- 2. Run data export queries (see data-export.sql)
-- 3. Deploy edge function (see instructions below)
-- 4. Configure secrets in Supabase dashboard
-- 5. Update your app's environment variables
-- ================================================
