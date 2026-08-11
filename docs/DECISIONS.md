# Design Decisions (ADR-lite) — Meridian Support Copilot

Each entry: **Context → Decision → Consequence**.

---

## ADR-001: Ground answers with RAG instead of fine-tuning

- **Context.** The agent must answer from Meridian's help center, which changes over time.
- **Options considered.** Fine-tune a model on the docs vs retrieval-augmented generation.
- **Decision.** RAG over pgvector. Docs are chunked, embedded, and retrieved at query time; the model answers only from retrieved context.
- **Consequence.** Content updates need only a re-ingest (no retraining); answers are citable and auditable. Trade-off: retrieval quality now depends on chunking and embeddings, which the eval set guards.

---

## ADR-002: Escalate with an idempotent tool call, not a best-effort answer

- **Context.** Some requests (refunds, ownership disputes) must reach a human. A wrong "sure, refunded!" is worse than no answer.
- **Options considered.** Let the model answer everything vs give it an `open_ticket` tool and instruct it to escalate.
- **Decision.** Provide an `open_ticket` tool. The system prompt requires escalation for money/identity actions. The tool sends an `external_ref` idempotency key.
- **Consequence.** Clear human hand-off. Trade-off: a small class of questions escalate that a human might have self-served — acceptable, and measured in the eval.
- **Idempotency is enforced in the database, not trusted to the LLM.** An early version relied on the LLM to produce a stable `external_ref` plus a `UNIQUE` constraint. In practice the model produced slightly different keys across runs (so duplicates slipped through), and when it *did* repeat a key the raw insert raised a unique-violation the agent then retried in a loop until it hit the iteration cap. Fix: a `BEFORE INSERT` trigger (`tickets_skip_duplicate`) turns a duplicate `external_ref` into a silent no-op. Now a retry is a true no-op — no error, no loop, at-most-one ticket — regardless of the caller. See `database/schema.sql`.

---

## ADR-003: RLS deny-by-default; n8n uses the service role

- **Context.** The vector store and tickets live in a public Postgres schema.
- **Options considered.** Disable RLS for simplicity vs enable RLS with explicit policies vs enable RLS with no anon policies.
- **Decision.** Enable RLS on all tables with no anon/authenticated policies. n8n connects with the service role key (bypasses RLS); no public client touches these tables.
- **Consequence.** No accidental public data exposure via the anon key. Trade-off: the Supabase linter shows an INFO "RLS enabled, no policy" — intentional and documented here.

---

## ADR-004: OpenAI for both chat and embeddings

- **Context.** The project needs a chat model and an embeddings model.
- **Options considered.** Mixed providers (Claude chat + OpenAI embeddings) vs single provider.
- **Decision.** Single provider (OpenAI) for chat and `text-embedding-3-small`.
- **Consequence.** One credential, one bill, simpler ops for a portfolio demo. Trade-off: provider lock-in; the workflow isolates the model nodes so swapping later is a local change.
