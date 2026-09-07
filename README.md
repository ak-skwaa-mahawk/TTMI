
# TTMI
Technical tech minimal instruction 

A deterministic policy gate with human review and cryptographic audit logging for autonomous CLI agents.

When an LLM agent executes local shell actions, unconstrained execution is hazardous, while manually approving every command is tedious. Agent Gate introduces a minimal intermediary:
1. Filters actions against deterministic safety policies.
2. Halts for a human confirmation prompt (`[y/N]`) on non-blocked actions.
3. Appends all proposals and decisions to an immutable, SHA-256 hash-chained log.

---

## Quickstart

Requires Python 3.8+ (no dependencies outside the standard library).

```bash
git clone [https://github.com/ak-skwaa-mahawk/TTMI.git](https://github.com/ak-skwaa-mahawk/TTMI.git)
cd TTMI
python3 agent_gate.py
python3 verify_audit.py

# Agent Gate

A deterministic admission gate for autonomous scripts and CLI agents.

When an LLM agent runs locally, letting it execute shell calls directly is unsafe,
while manually copy-pasting commands is tedious. Agent Gate sits in the middle:
it intercepts proposed commands, runs baseline policy checks, prompts you for a
single keystroke confirmation, and writes an append-only, SHA-256 hash-chained log
to disk.

## Quickstart

Requires Python 3.8+ (no pip dependencies).

```bash
git clone [https://github.com/your-username/agent-gate.git](https://github.com/your-username/agent-gate.git)
cd agent-gate
python3 agent_gate.py
