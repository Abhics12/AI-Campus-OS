# AI Campus OS — Final Build Deployment

## Architecture
- One web app.
- Every Department + Year is a separate workspace/tenant.
- Supabase is the database/auth/security layer.
- Google Drive is optional workspace file storage selected by each Admin.
- RLS must enforce `workspace_id` isolation.

## Required account configuration
1. Supabase project URL + publishable/anon key in `config.js`.
2. Google OAuth Web Client ID in `config.js`.
3. Google Drive API enabled in the Google Cloud project.
4. The deployed domain added to Google OAuth Authorized JavaScript origins.

Do not put service-role keys or service-account private keys in the browser.

## Local run
Serve the folder with a web server. Do not open `index.html` with `file://`.
For example with a Node project, run the project's dev server and open the printed local URL.

## Workspace model
Example workspaces:
- CSE • 1st Year
- CSE • 2nd Year
- CSE • 3rd Year
- CSE • 4th Year
- Mechanical • 1st Year
- Civil • 1st Year
- Electrical • 1st Year
- CSE Specialization • 1st Year

The Admin creates/opens one Department + Year workspace. The same web app can host many isolated workspaces.

## Google Drive
The app does not hard-code a Gmail account. Each Admin chooses their Google account during OAuth.
A production Drive implementation should use the least-privilege `drive.file` scope and store only a workspace folder ID and non-secret account metadata server-side.

## Important production note
The source contains the full workspace/UI/data model and a Google OAuth configuration point. Live Google OAuth cannot be activated without the owner's Google Cloud OAuth client ID and authorized domain, and Supabase cannot be connected without the owner's project URL/key. Those are account-specific credentials and cannot be safely fabricated.
