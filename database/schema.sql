-- Meridian Support Copilot — database schema (Supabase / Postgres + pgvector)
-- Run in the Supabase SQL editor before importing the workflows.

create extension if not exists vector;

-- 1) Knowledge base (RAG). Embedding dim 1536 = OpenAI text-embedding-3-small.
create table if not exists public.kb_documents (
  id          uuid primary key default gen_random_uuid(),
  content     text not null,
  metadata    jsonb not null default '{}'::jsonb,
  embedding   vector(1536),
  created_at  timestamptz not null default now()
);
create index if not exists kb_documents_embedding_idx
  on public.kb_documents using ivfflat (embedding vector_cosine_ops) with (lists = 100);
create index if not exists kb_documents_metadata_idx
  on public.kb_documents using gin (metadata);

-- Vector similarity search used by the n8n Supabase Vector Store node.
-- search_path is pinned to '' (hardening); the pgvector operator is therefore
-- schema-qualified as OPERATOR(public.<=>) so it still resolves.
create or replace function public.match_kb_documents (
  query_embedding vector(1536),
  match_count int default 5,
  filter jsonb default '{}'::jsonb
) returns table (id uuid, content text, metadata jsonb, similarity float)
language plpgsql stable
set search_path = ''
as $$
begin
  return query
  select d.id, d.content, d.metadata,
         1 - (d.embedding OPERATOR(public.<=>) query_embedding) as similarity
  from public.kb_documents d
  where d.metadata @> filter
  order by d.embedding OPERATOR(public.<=>) query_embedding
  limit match_count;
end;
$$;

-- 2) Tickets (tool-calling target). external_ref = idempotency key.
create table if not exists public.tickets (
  id             bigint generated always as identity primary key,
  external_ref   text unique,
  customer_email text,
  subject        text not null,
  body           text,
  status         text not null default 'open',
  priority       text not null default 'normal',
  created_at     timestamptz not null default now()
);

-- 3) Observability: every agent interaction is logged.
create table if not exists public.interaction_logs (
  id          bigint generated always as identity primary key,
  session_id  text,
  question    text,
  answer      text,
  used_docs   jsonb,
  latency_ms  int,
  usage       jsonb,
  resolved    boolean,
  created_at  timestamptz not null default now()
);

-- Idempotency at the database level: a duplicate external_ref becomes a silent
-- no-op instead of a unique-violation error. This guarantees at-most-one ticket
-- per external_ref no matter how many times the agent retries an escalation.
create or replace function public.tickets_skip_duplicate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.external_ref is not null
     and exists (select 1 from public.tickets t where t.external_ref = new.external_ref) then
    return null; -- skip the insert silently
  end if;
  return new;
end;
$$;

drop trigger if exists tickets_skip_duplicate_trg on public.tickets;
create trigger tickets_skip_duplicate_trg
  before insert on public.tickets
  for each row execute function public.tickets_skip_duplicate();

-- Security: RLS on, deny-by-default. n8n connects with the service role key
-- (bypasses RLS); no anon/authenticated access is granted to these tables.
alter table public.kb_documents     enable row level security;
alter table public.tickets          enable row level security;
alter table public.interaction_logs enable row level security;
