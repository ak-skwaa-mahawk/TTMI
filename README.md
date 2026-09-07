# TTMI
Technical tech minimal instruction 

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
