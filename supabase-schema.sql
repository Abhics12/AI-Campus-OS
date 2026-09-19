-- AI Campus OS — Supabase production schema
-- Run in Supabase SQL Editor.
-- Auth users are managed by Supabase Auth; app profiles live in public.profiles.
--
-- NOTE (fixed): "CREATE POLICY IF NOT EXISTS" is NOT valid PostgreSQL syntax
-- (Postgres has no IF NOT EXISTS support for policies as of PG 18 / late 2026).
-- Every policy below uses "DROP POLICY IF EXISTS ...; CREATE POLICY ...;" instead,
-- which is idempotent and safe to re-run.

create extension if not exists pgcrypto;

do $$ begin
  create type public.app_role as enum ('admin','teacher','student');
exception when duplicate_object then null; end $$;

create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  department text not null,
  year_no int not null check (year_no between 1 and 4),
  name text generated always as (department || ' • Year ' || year_no) stored,
  created_at timestamptz not null default now(),
  unique(department, year_no)
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text not null default '',
  role public.app_role not null default 'student',
  workspace_id uuid references public.workspaces(id) on delete restrict,
  section text,
  batch text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sections (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  code text not null,
  active boolean not null default true,
  unique(workspace_id, code)
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  code text,
  active boolean not null default true
);

create table if not exists public.teacher_subjects (
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  section_id uuid references public.sections(id) on delete cascade,
  primary key(teacher_id, subject_id, section_id)
);

create table if not exists public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  section_id uuid references public.sections(id) on delete set null,
  subject_id uuid references public.subjects(id) on delete set null,
  teacher_id uuid references public.profiles(id) on delete set null,
  attendance_date date not null,
  period_no int,
  lecture_no int,
  status text not null default 'held' check (status in ('held','holiday','no_class')),
  created_at timestamptz not null default now()
);

create table if not exists public.attendance_records (
  session_id uuid not null references public.attendance_sessions(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  status text not null check (status in ('present','absent','leave')),
  primary key(session_id, student_id)
);

create table if not exists public.labs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  lab_code text not null,
  active boolean not null default true,
  unique(workspace_id, lab_code)
);

create table if not exists public.lab_sessions (
  id uuid primary key default gen_random_uuid(),
  lab_id uuid not null references public.labs(id) on delete cascade,
  section_id uuid references public.sections(id) on delete set null,
  teacher_id uuid references public.profiles(id) on delete set null,
  batch text,
  lab_date date not null,
  lab_no int,
  experiment_no int,
  created_at timestamptz not null default now()
);

create table if not exists public.lab_attendance (
  session_id uuid not null references public.lab_sessions(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  status text not null check (status in ('present','absent','leave')),
  primary key(session_id, student_id)
);

create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  section_id uuid references public.sections(id) on delete set null,
  teacher_id uuid references public.profiles(id) on delete set null,
  title text not null,
  question text,
  assignment_date date,
  last_submission_date date,
  max_marks numeric not null default 10,
  attachment_path text,
  created_at timestamptz not null default now()
);

create table if not exists public.assignment_status (
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  physical_submitted boolean not null default false,
  marks numeric,
  checked_at timestamptz,
  primary key(assignment_id, student_id)
);

create table if not exists public.timetables (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  title text not null,
  file_path text not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  section_id uuid references public.sections(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete set null,
  title text not null,
  message text,
  attachment_path text,
  created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists email text;

-- Helper: current user's workspace
create or replace function public.my_workspace_id()
returns uuid language sql stable security definer set search_path=public
as $$ select workspace_id from public.profiles where id = auth.uid(); $$;

-- Helper: current user's role
create or replace function public.my_role()
returns public.app_role language sql stable security definer set search_path=public
as $$ select role from public.profiles where id = auth.uid(); $$;

alter table public.workspaces enable row level security;
alter table public.profiles enable row level security;
alter table public.sections enable row level security;
alter table public.subjects enable row level security;
alter table public.teacher_subjects enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.labs enable row level security;
alter table public.lab_sessions enable row level security;
alter table public.lab_attendance enable row level security;
alter table public.assignments enable row level security;
alter table public.assignment_status enable row level security;
alter table public.timetables enable row level security;
alter table public.notifications enable row level security;

-- Workspace isolation: users only read data from their own workspace.
drop policy if exists profiles_self_or_workspace on public.profiles;
create policy profiles_self_or_workspace on public.profiles for select using (id=auth.uid() or workspace_id=public.my_workspace_id());

drop policy if exists workspace_member_read on public.workspaces;
create policy workspace_member_read on public.workspaces for select using (id=public.my_workspace_id());

drop policy if exists sections_workspace on public.sections;
create policy sections_workspace on public.sections for all using (workspace_id=public.my_workspace_id()) with check (workspace_id=public.my_workspace_id());

drop policy if exists subjects_workspace on public.subjects;
create policy subjects_workspace on public.subjects for all using (workspace_id=public.my_workspace_id()) with check (workspace_id=public.my_workspace_id());

drop policy if exists assignments_workspace on public.assignments;
create policy assignments_workspace on public.assignments for all using (workspace_id=public.my_workspace_id()) with check (workspace_id=public.my_workspace_id());

drop policy if exists timetable_workspace on public.timetables;
create policy timetable_workspace on public.timetables for all using (workspace_id=public.my_workspace_id()) with check (workspace_id=public.my_workspace_id());

drop policy if exists notifications_workspace on public.notifications;
create policy notifications_workspace on public.notifications for all using (workspace_id=public.my_workspace_id()) with check (workspace_id=public.my_workspace_id());

drop policy if exists attendance_session_workspace on public.attendance_sessions;
create policy attendance_session_workspace on public.attendance_sessions for all using (workspace_id=public.my_workspace_id()) with check (workspace_id=public.my_workspace_id());

drop policy if exists labs_workspace on public.labs;
create policy labs_workspace on public.labs for all using (workspace_id=public.my_workspace_id()) with check (workspace_id=public.my_workspace_id());

-- Child rows are accessible through their parent workspace/session.
drop policy if exists attendance_record_member on public.attendance_records;
create policy attendance_record_member on public.attendance_records for all using (exists(select 1 from public.attendance_sessions s where s.id=session_id and s.workspace_id=public.my_workspace_id())) with check (exists(select 1 from public.attendance_sessions s where s.id=session_id and s.workspace_id=public.my_workspace_id()));

drop policy if exists lab_session_member on public.lab_sessions;
create policy lab_session_member on public.lab_sessions for all using (exists(select 1 from public.labs l where l.id=lab_id and l.workspace_id=public.my_workspace_id())) with check (exists(select 1 from public.labs l where l.id=lab_id and l.workspace_id=public.my_workspace_id()));

drop policy if exists lab_attendance_member on public.lab_attendance;
create policy lab_attendance_member on public.lab_attendance for all using (exists(select 1 from public.lab_sessions s join public.labs l on l.id=s.lab_id where s.id=session_id and l.workspace_id=public.my_workspace_id())) with check (exists(select 1 from public.lab_sessions s join public.labs l on l.id=s.lab_id where s.id=session_id and l.workspace_id=public.my_workspace_id()));

drop policy if exists assignment_status_member on public.assignment_status;
create policy assignment_status_member on public.assignment_status for all using (exists(select 1 from public.assignments a where a.id=assignment_id and a.workspace_id=public.my_workspace_id())) with check (exists(select 1 from public.assignments a where a.id=assignment_id and a.workspace_id=public.my_workspace_id()));

drop policy if exists teacher_subjects_member on public.teacher_subjects;
create policy teacher_subjects_member on public.teacher_subjects for all using (exists(select 1 from public.subjects s where s.id=subject_id and s.workspace_id=public.my_workspace_id())) with check (exists(select 1 from public.subjects s where s.id=subject_id and s.workspace_id=public.my_workspace_id()));

-- Storage bucket for timetable/assignment/notification files.
insert into storage.buckets (id, name, public) values ('campus-files','campus-files',false) on conflict (id) do nothing;

drop policy if exists campus_files_read on storage.objects;
create policy campus_files_read on storage.objects for select to authenticated using (bucket_id='campus-files');

drop policy if exists campus_files_insert on storage.objects;
create policy campus_files_insert on storage.objects for insert to authenticated with check (bucket_id='campus-files');

drop policy if exists campus_files_update on storage.objects;
create policy campus_files_update on storage.objects for update to authenticated using (bucket_id='campus-files') with check (bucket_id='campus-files');

drop policy if exists campus_files_delete on storage.objects;
create policy campus_files_delete on storage.objects for delete to authenticated using (bucket_id='campus-files');


-- Student directory privacy contract:
-- Students must never query a global teacher directory.
-- The UI/API should query teacher_subjects only through the student's
-- authenticated workspace and section/timetable assignment.
-- Production implementation should expose a view/RPC that returns only
-- teacher + subject pairs assigned to the current student's section.


-- =====================================================================
-- STAGE 1: real sign-up + shared, multi-device user accounts.
--
-- Flow:
--  1. Anyone can see the list of workspaces (department + year only,
--     no personal data) so the sign-up screen can offer a picker.
--  2. A new person signs up with their own email + password. A trigger
--     auto-creates their profiles row as role='student' in the chosen
--     workspace — nobody can grant themselves 'teacher' or 'admin'.
--  3. The college's first Admin account is promoted ONCE, by hand, by
--     running the commented block at the bottom of this file after they
--     sign up through the app. After that, the Admin promotes teachers
--     and edits sections/roles from inside the app (Admin Control Center).
-- =====================================================================

-- Let anyone (even signed-out visitors) see the workspace list so a new
-- sign-up can pick "their" Department + Year. No personal data here.
drop policy if exists workspaces_public_read on public.workspaces;
create policy workspaces_public_read on public.workspaces for select to anon, authenticated using (true);

-- Auto-create a profile row the moment someone signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
declare wid uuid;
begin
  wid := nullif(new.raw_user_meta_data->>'workspace_id','')::uuid;
  insert into public.profiles (id, email, full_name, role, workspace_id, section, active)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name',''), 'student', wid, nullif(new.raw_user_meta_data->>'section',''), true)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Let a signed-in user edit their own profile row (name/section/batch),
-- and let an Admin manage anyone already in their own workspace.
drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles for update using (id=auth.uid()) with check (id=auth.uid());

drop policy if exists profiles_admin_manage on public.profiles;
create policy profiles_admin_manage on public.profiles for update using (public.my_role()='admin' and workspace_id=public.my_workspace_id());

-- Safety net: even though the two policies above let a person update
-- their own row, only an EXISTING admin may ever change a role or move
-- someone to a different workspace — a self-update can never promote
-- itself, no matter what the client sends.
create or replace function public.prevent_self_privilege_escalation()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  if auth.uid() = old.id and public.my_role() <> 'admin' then
    new.role := old.role;
    new.workspace_id := old.workspace_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_self_escalation on public.profiles;
create trigger trg_prevent_self_escalation
  before update on public.profiles
  for each row execute function public.prevent_self_privilege_escalation();

-- ---------------------------------------------------------------------
-- ONE-TIME BOOTSTRAP — run this manually, after your own Admin account
-- has signed up through the app's Sign Up screen. Replace the email and
-- department/year, then run this block in the SQL Editor. The SQL
-- Editor runs as the table owner and bypasses RLS, so this is safe.
-- ---------------------------------------------------------------------
-- insert into public.workspaces (department, year_no) values ('CSE', 1)
--   on conflict (department, year_no) do nothing;
-- update public.profiles set role='admin',
--   workspace_id=(select id from public.workspaces where department='CSE' and year_no=1)
--   where id=(select id from auth.users where email='YOUR_ADMIN_EMAIL_HERE');
