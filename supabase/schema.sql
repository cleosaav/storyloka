-- ============ EXTENSIONS ============
create extension if not exists pgcrypto with schema extensions;

-- ============ TABEL AKUN (tidak diakses langsung oleh klien) ============
create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  password_hash text not null,
  avatar_url text,
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists app_users_email_uidx on public.app_users (lower(email));

create table if not exists public.app_sessions (
  token text primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index if not exists app_sessions_user_idx on public.app_sessions (user_id);

alter table public.app_users enable row level security;
alter table public.app_sessions enable row level security;
-- Sengaja TANPA policy: hanya fungsi SECURITY DEFINER di bawah yang bisa mengakses.

-- ============ TABEL DATA ============
create table if not exists public.user_books (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  google_books_id text not null,
  title text not null,
  authors text,
  genre text,
  isbn text,
  publisher text,
  page_count integer,
  cover_url text,
  synopsis text,
  price_amount numeric,
  price_currency text,
  list_type text not null check (list_type in ('collection','wishlist')),
  status text not null default 'not_started' check (status in ('not_started','reading','finished')),
  current_page integer not null default 0,
  rating integer check (rating between 1 and 5),
  review text,
  started_at timestamptz,
  finished_at timestamptz,
  last_read_at timestamptz,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, google_books_id)
);
create index if not exists user_books_user_idx on public.user_books (user_id);

create table if not exists public.reading_sessions (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  user_book_id uuid not null references public.user_books(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  duration_seconds integer not null,
  created_at timestamptz not null default now()
);
create index if not exists reading_sessions_user_idx on public.reading_sessions (user_id);

create table if not exists public.ledger_blocks (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  block_index integer not null,
  timestamp timestamptz not null,
  data_json jsonb not null,
  previous_hash text not null,
  nonce integer not null,
  hash text not null,
  created_at timestamptz not null default now(),
  unique (user_id, block_index)
);

create table if not exists public.feedbacks (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  name text not null,
  impression text not null,
  suggestion text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.game_scores (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  game text not null,
  score integer not null,
  played_at timestamptz not null default now()
);

-- ============ RLS TABEL DATA (permisif untuk anon — lihat catatan keamanan 8.2) ============
alter table public.user_books enable row level security;
alter table public.reading_sessions enable row level security;
alter table public.ledger_blocks enable row level security;
alter table public.feedbacks enable row level security;
alter table public.game_scores enable row level security;

do $$
declare t text;
begin
  foreach t in array array['user_books','reading_sessions','ledger_blocks','feedbacks','game_scores']
  loop
    execute format('drop policy if exists "%1$s anon all" on public.%1$s', t);
    execute format('create policy "%1$s anon all" on public.%1$s for all to anon using (true) with check (true)', t);
  end loop;
end $$;

-- ============ RPC AUTH ============
create or replace function public.register_user(p_name text, p_email text, p_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user public.app_users;
  v_token text;
begin
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'NAME_REQUIRED'; end if;
  if p_email is null or p_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'EMAIL_INVALID'; end if;
  if p_password is null or length(p_password) < 8 then raise exception 'PASSWORD_TOO_SHORT'; end if;
  if exists (select 1 from public.app_users where lower(email) = lower(trim(p_email))) then
    raise exception 'EMAIL_TAKEN';
  end if;

  insert into public.app_users (name, email, password_hash)
  values (trim(p_name), lower(trim(p_email)), crypt(p_password, gen_salt('bf', 10)))
  returning * into v_user;

  v_token := encode(gen_random_bytes(32), 'hex');
  insert into public.app_sessions (token, user_id, expires_at)
  values (v_token, v_user.id, now() + interval '30 days');

  return json_build_object(
    'token', v_token,
    'user', json_build_object('id', v_user.id, 'name', v_user.name, 'email', v_user.email,
                              'avatar_url', v_user.avatar_url, 'bio', v_user.bio)
  );
end $$;

create or replace function public.login_user(p_email text, p_password text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user public.app_users;
  v_token text;
begin
  select * into v_user from public.app_users where lower(email) = lower(trim(p_email));
  if not found or v_user.password_hash <> crypt(p_password, v_user.password_hash) then
    raise exception 'INVALID_CREDENTIALS';
  end if;

  v_token := encode(gen_random_bytes(32), 'hex');
  insert into public.app_sessions (token, user_id, expires_at)
  values (v_token, v_user.id, now() + interval '30 days');

  return json_build_object(
    'token', v_token,
    'user', json_build_object('id', v_user.id, 'name', v_user.name, 'email', v_user.email,
                              'avatar_url', v_user.avatar_url, 'bio', v_user.bio)
  );
end $$;

create or replace function public.validate_session(p_token text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v_user public.app_users;
begin
  select u.* into v_user
  from public.app_sessions s join public.app_users u on u.id = s.user_id
  where s.token = p_token and s.expires_at > now();
  if not found then raise exception 'SESSION_INVALID'; end if;
  return json_build_object('id', v_user.id, 'name', v_user.name, 'email', v_user.email,
                           'avatar_url', v_user.avatar_url, 'bio', v_user.bio);
end $$;

create or replace function public.logout_session(p_token text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  delete from public.app_sessions where token = p_token;
end $$;

create or replace function public.update_profile(p_token text, p_name text, p_bio text, p_avatar_url text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
  v_user public.app_users;
begin
  select user_id into v_uid from public.app_sessions where token = p_token and expires_at > now();
  if v_uid is null then raise exception 'SESSION_INVALID'; end if;
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'NAME_REQUIRED'; end if;

  update public.app_users
  set name = trim(p_name), bio = p_bio, avatar_url = coalesce(p_avatar_url, avatar_url), updated_at = now()
  where id = v_uid
  returning * into v_user;

  return json_build_object('id', v_user.id, 'name', v_user.name, 'email', v_user.email,
                           'avatar_url', v_user.avatar_url, 'bio', v_user.bio);
end $$;

grant execute on function public.register_user(text, text, text) to anon;
grant execute on function public.login_user(text, text) to anon;
grant execute on function public.validate_session(text) to anon;
grant execute on function public.logout_session(text) to anon;
grant execute on function public.update_profile(text, text, text, text) to anon;

-- ============ STORAGE AVATAR ============
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars anon read" on storage.objects;
drop policy if exists "avatars anon insert" on storage.objects;
drop policy if exists "avatars anon update" on storage.objects;
create policy "avatars anon read"   on storage.objects for select to anon using (bucket_id = 'avatars');
create policy "avatars anon insert" on storage.objects for insert to anon with check (bucket_id = 'avatars');
create policy "avatars anon update" on storage.objects for update to anon using (bucket_id = 'avatars');
