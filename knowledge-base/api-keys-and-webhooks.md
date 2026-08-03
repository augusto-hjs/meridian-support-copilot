# API keys and webhooks

**API keys.** Create keys in *Settings → Developers → API keys*. Keys are scoped (read-only or read-write) and shown only once at creation — store them securely. Revoke a key anytime; revocation is immediate.

**Authentication.** Pass the key as a bearer token: `Authorization: Bearer <key>`. The API base URL is `https://api.meridian.example/v1`.

**Rate limits.** Free: 60 requests/min. Pro: 600 requests/min. Business: 3,000 requests/min. Exceeding the limit returns HTTP 429 with a `Retry-After` header. Use exponential backoff.

**Webhooks.** Configure endpoints in *Settings → Developers → Webhooks*. Subscribe to events such as `project.created`, `task.completed`, and `member.invited`. Each delivery is signed with an HMAC SHA-256 signature in the `X-Meridian-Signature` header — verify it using your webhook secret.

**Retries.** Failed webhook deliveries (non-2xx) are retried with backoff for up to 24 hours. You can replay deliveries from the webhook log.

**Idempotency.** Write endpoints accept an `Idempotency-Key` header so retried requests don't create duplicates.
