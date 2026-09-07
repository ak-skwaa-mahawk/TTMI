cat << 'EOF' > README.md
# Agent Gate

A deterministic policy gate with human review and cryptographic audit logging for autonomous CLI agents.

When an LLM agent executes local shell actions, unconstrained execution is hazardous, while manually approving every command is tedious. Agent Gate introduces a minimal intermediary:
1. Filters actions against deterministic safety policies.
2. Halts for a human confirmation prompt (`[y/N]`) on non-blocked actions.
3. Appends all proposals and decisions to an immutable, SHA-256 hash-chained log.

---

## Quickstart

Requires Python 3.8+ (no external dependencies).

```bash
git clone [https://github.com/ak-skwaa-mahawk/TTMI.git](https://github.com/ak-skwaa-mahawk/TTMI.git)
cd TTMI
python3 agent_gate.py
