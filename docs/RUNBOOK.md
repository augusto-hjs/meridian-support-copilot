# Runbook — Meridian Support Copilot

## Prerequisites

- n8n (Cloud or self-hosted) — recent version with the LangChain/AI nodes
- Supabase project with `pgvector` enabled
- OpenAI API key

## Setup

1. **Environment.** Copy `.env.example` → `.env` and fill:
   ```
   OPENAI_API_KEY=sk-...
   SUPABASE_URL=https://<ref>.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=...
   ```
2. **Database.** Run the SQL in `docs/ARCHITECTURE.md` (Data model) in the Supabase SQL editor.
3. **Import workflows.** In n8n: *Workflows → Import from File* for each file in `workflows/`.
4. **Credentials.** In n8n create:
   - **OpenAI** credential (your API key)
   - **Supabase** credential (project URL + service role key)
   Then open each workflow and select these credentials on the relevant nodes.
5. **Ingest.** Run `meridian-kb-ingestion` once. Confirm rows exist: `select count(*) from kb_documents;`

## Running

- **Trigger:** open the `meridian-support-copilot` workflow and use the chat trigger (or POST to its webhook).
- **Expected result:** a grounded answer with citations, or a confirmation that a ticket was opened.
- **Where to see output:** the chat response; tickets in `select * from tickets order by id desc;`

## Observability

- **Execution history:** n8n → Executions, filtered to this workflow.
- **Logs:** `select * from interaction_logs order by id desc limit 20;`
- **Key metrics:** latency_ms, resolved vs escalated ratio, retrieved doc ids.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| "I can't answer" on valid questions | KB not ingested / bad chunking | Re-run ingestion; verify `kb_documents` row count |
| Duplicate tickets | idempotency key not set | Ensure `external_ref` is populated on the `open_ticket` node |
| 429 from OpenAI | rate limit | Backoff is configured; reduce concurrency or upgrade key tier |
| Empty retrieval | embedding dim mismatch | Confirm `text-embedding-3-small` (1536) matches the column |

## Eval / tests

- **Run:** open `meridian-eval` (or `/eval`) and execute against the labeled Q&A set.
- **Last result:** _recorded in README Results after each run._
