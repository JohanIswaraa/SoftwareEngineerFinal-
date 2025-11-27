# Migration Instructions: Move to Self-Managed Supabase

## Overview
This guide will help you migrate your internship platform from Lovable Cloud to your own Supabase project, giving you full dashboard access.

---

## Step 1: Create New Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign up/login
2. Click **"New Project"**
3. Choose a name, database password, and region
4. Wait for project to finish setting up (~2 minutes)
5. Save your credentials:
   - Project URL: `https://xxxxx.supabase.co`
   - Anon/Public Key: Found in **Settings → API**
   - Project ID: Found in **Settings → General**

---

## Step 2: Run Database Migration

1. In your new Supabase dashboard, go to **SQL Editor**
2. Click **"New Query"**
3. Copy the entire contents of `migration-to-own-supabase.sql`
4. Paste into the SQL editor
5. Click **"Run"** (or press Cmd/Ctrl + Enter)
6. Wait for completion - should see "Success. No rows returned"

This creates:
- ✅ All database tables (profiles, internships, activity_logs, etc.)
- ✅ Security functions (has_role, is_admin, etc.)
- ✅ Triggers (auto-create profiles, validation, etc.)
- ✅ Row Level Security policies

---

## Step 3: Create Storage Bucket

1. In Supabase dashboard, go to **Storage**
2. Click **"Create a new bucket"**
3. Configure:
   - Name: `internship-images`
   - **Public bucket**: ✅ Checked
   - File size limit: `5242880` (5MB)
   - Allowed MIME types: `image/jpeg, image/png, image/webp, image/gif`
4. Click **"Create bucket"**

### Set Storage Policies

Go to **Storage → Policies** and add these policies for `internship-images`:

```sql
-- Allow public read access
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'internship-images');

-- Allow authenticated users to upload
CREATE POLICY "Authenticated users can upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'internship-images');

-- Allow admins to delete
CREATE POLICY "Admins can delete"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'internship-images' 
  AND EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = auth.uid()::text 
    AND role = 'admin'
  )
);
```

---

## Step 4: Export and Import Data

### 4A. Export Data from Lovable Cloud

**Option 1: Using Lovable Dashboard**
1. Open your Lovable project
2. Click "View Backend" button (provided by Lovable AI)
3. Go to **Table Editor**
4. For each table, click **"Export to CSV"**

**Option 2: Using SQL Queries**
1. Open your current Lovable project backend
2. Go to SQL Editor
3. Copy and run each query from `data-export.sql`
4. Copy the generated INSERT statements

### 4B. Import Data to New Project

1. In your **new** Supabase dashboard, go to **SQL Editor**
2. Paste the INSERT statements generated from step 4A
3. Run each INSERT statement
4. Verify data imported: Go to **Table Editor** and check each table

### Current Data Summary
- 22 profiles
- 5 internships
- 120 activity logs
- 22 user roles
- User interactions (if any)

---

## Step 5: Deploy Edge Function

### Prerequisites
Install Supabase CLI:
```bash
# macOS
brew install supabase/tap/supabase

# Windows
scoop install supabase

# Linux
npm install -g supabase
```

### Deploy the Function

1. Open terminal in your project directory
2. Login to Supabase:
   ```bash
   supabase login
   ```
3. Link to your project:
   ```bash
   supabase link --project-ref YOUR_PROJECT_ID
   ```
4. Deploy the send-email function:
   ```bash
   supabase functions deploy send-email
   ```

---

## Step 6: Configure Secrets

In your Supabase dashboard, go to **Edge Functions → Secrets** and add:

| Secret Name | Description | Where to Get It |
|------------|-------------|-----------------|
| `RESEND_API_KEY` | Email sending API key | [resend.com/api-keys](https://resend.com/api-keys) |
| `SEND_EMAIL_HOOK_SECRET` | Webhook verification | Generate a random string (e.g., use password generator) |

To add secrets:
```bash
supabase secrets set RESEND_API_KEY=your_key_here
supabase secrets set SEND_EMAIL_HOOK_SECRET=your_secret_here
```

---

## Step 7: Configure Authentication

1. Go to **Authentication → Providers**
2. Enable **Email** provider
3. Go to **Authentication → Settings**
4. Configure:
   - **Enable email confirmations**: OFF (for testing) or ON (for production)
   - **Secure email change**: ON
   - **Email templates**: Customize if desired

### Optional: Set Up Email Webhooks
If you want custom email templates (using the send-email function):

1. Go to **Authentication → Settings → Email Hooks**
2. Click **"Enable"** for desired hooks (Magic Link, Password Reset, etc.)
3. Set Hook URL to: `https://YOUR_PROJECT_ID.supabase.co/functions/v1/send-email`
4. Add hook secret: The `SEND_EMAIL_HOOK_SECRET` value from Step 6

---

## Step 8: Update Your Application

### Update Environment Variables

**If deploying to Vercel/Netlify/etc:**
1. Go to your hosting platform's dashboard
2. Navigate to Environment Variables
3. Update these variables:
   ```env
   VITE_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
   VITE_SUPABASE_PUBLISHABLE_KEY=your-new-anon-key
   VITE_SUPABASE_PROJECT_ID=YOUR_PROJECT_ID
   ```
4. Redeploy your application

**If developing locally:**
1. Update your `.env` file with the same variables above
2. Restart your dev server

---

## Step 9: Transfer Storage Files (Optional)

If you have existing internship images:

1. In **old** Lovable Cloud backend:
   - Go to Storage → internship-images
   - Download all files

2. In **new** Supabase project:
   - Go to Storage → internship-images
   - Upload the downloaded files

---

## Step 10: Create First Admin User

Since user auth data cannot be migrated:

1. Open your app and **sign up** with a new account
2. In your Supabase dashboard, go to **SQL Editor**
3. Run this query (replace with your new user's ID):
   ```sql
   -- Find your user ID first
   SELECT id, email FROM auth.users;

   -- Then assign admin role
   INSERT INTO public.user_roles (user_id, role)
   VALUES ('your-user-id-here', 'admin');
   ```
4. Refresh your app - you should now have admin access

---

## Verification Checklist

After migration, verify everything works:

- [ ] Can access Supabase dashboard at supabase.com
- [ ] All tables visible in Table Editor
- [ ] Sample data shows up in tables
- [ ] Can sign up new users in your app
- [ ] Can login with new account
- [ ] Admin user can access admin dashboard
- [ ] Students can view internships
- [ ] Students can star/apply to internships
- [ ] Images upload successfully
- [ ] Email function works (test password reset)

---

## What You Get

✅ **Full Supabase Dashboard Access**
- SQL Editor - Write custom queries
- Table Editor - View/edit data directly
- Database → Functions - See all database functions
- Database → Triggers - View trigger logic
- Database → Extensions - Install Postgres extensions

✅ **Authentication Management**
- See all registered users
- Manually verify emails
- Delete test accounts
- View session logs

✅ **Storage Management**
- Upload files directly
- Set custom policies
- View storage metrics

✅ **Monitoring & Logs**
- API Logs - See all requests
- Database Logs - Query performance
- Edge Function Logs - Debug functions

✅ **Full Control**
- Export database anytime
- Create backups
- Scale resources
- Add team members

---

## Important Notes

### User Authentication Data
⚠️ **Cannot be migrated** - Users need to:
- Sign up with new accounts, OR
- Use "Forgot Password" to set new passwords

### Session Tokens
⚠️ All existing users will be **logged out** and need to login again with new passwords

### Uploaded Files
⚠️ Must be **manually transferred** from old storage bucket to new one (see Step 9)

### Edge Functions
⚠️ Must be **manually deployed** using Supabase CLI (see Step 5)

### Old Lovable Cloud Project
✅ Will continue to work until you update your app's environment variables
✅ Can keep as backup during migration
✅ Can delete after successful migration

---

## Troubleshooting

### "Permission denied" errors
- Check RLS policies are applied
- Verify user has correct role in user_roles table
- Ensure functions have `SECURITY DEFINER` set

### Edge function not working
- Verify secrets are set: `supabase secrets list`
- Check function logs in dashboard
- Redeploy: `supabase functions deploy send-email`

### Can't upload images
- Verify storage bucket is public
- Check storage policies are created
- Ensure bucket name is exactly `internship-images`

### Migration script errors
- Run script sections separately
- Check for syntax errors
- Verify no tables already exist

---

## Need Help?

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Discord Community](https://discord.supabase.com)
- Check console logs in browser for errors
- Check database logs in Supabase dashboard

---

## Summary

You now have a **fully functional, self-managed Supabase project** with:
- Complete database schema with all tables, functions, and policies
- Storage bucket for internship images  
- Edge function for email sending
- Full dashboard access to manage everything
- All your existing data migrated over

Your app is now independent of Lovable Cloud and you have complete control! 🎉
