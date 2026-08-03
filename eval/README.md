# Eval — Meridian Support Copilot

A small labeled set that guards two behaviors: **grounded answering** and **correct escalation**.

- `dataset.jsonl` — one case per line:
  - `expected: "answer"` → the agent should answer from the KB and mention the `must_mention` facts.
  - `expected: "escalate"` → the agent should open a ticket instead of answering (money/identity/unknown cases).
- `expected_category` is the KB category the answer should come from (`unknown` = not in the KB → must escalate).

## Scoring

For each case:
- **Grounding pass** = expected `answer` AND response contains all `must_mention` strings AND no ticket opened.
- **Escalation pass** = expected `escalate` AND a ticket was opened AND no fabricated answer.

Report: grounding accuracy, escalation accuracy, and median latency. Record the numbers in the root `README.md` Results table and the walkthrough.

## How to run

The `meridian-eval` n8n workflow ([`../workflows/meridian-eval.json`](../workflows/meridian-eval.json)) iterates the dataset, calls the agent, and checks each rule automatically.

**Last run:** 10/10 (100%) — grounding 8/8, escalation 2/2, 0 failures.
