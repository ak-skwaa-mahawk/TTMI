#!/usr/bin/env python3
"""
agent_gate.py - Minimal admission gate for CLI agent actions.
"""

import hashlib
import json
import os
import sys
import time
from dataclasses import asdict, dataclass
from typing import Optional, Tuple


@dataclass
class ActionProposal:
    action_id: str
    command: str
    target_path: str
    risk_tier: int  # 1 = Low, 2 = Medium, 3 = High


class PolicyEngine:
    BLOCKED_PATTERNS = ["rm -rf /", ":(){ :|:& };:", "/dev/sd"]
    PROTECTED_PATHS = ["/etc", "/boot", "/sys", "/dev"]

    @classmethod
    def evaluate(cls, proposal: ActionProposal) -> Tuple[bool, str]:
        for pattern in cls.BLOCKED_PATTERNS:
            if pattern in proposal.command:
                return False, f"Blocked: matched unsafe pattern '{pattern}'"

        resolved = os.path.abspath(proposal.target_path)
        for target in cls.PROTECTED_PATHS:
            if resolved.startswith(os.path.abspath(target)):
                return False, f"Blocked: access to protected directory '{target}'"

        if proposal.risk_tier not in (1, 2, 3):
            return False, "Blocked: invalid risk tier"

        return True, "Passed policy checks."


class AuditLogger:
    def __init__(self, log_path: str = "audit_log.jsonl"):
        self.log_path = log_path
        self.last_hash = self._get_tip_hash()

    def _get_tip_hash(self) -> str:
        if not os.path.exists(self.log_path):
            return "0" * 64
        last_line = ""
        with open(self.log_path, "r", encoding="utf-8") as f:
            for line in f:
                if line.strip():
                    last_line = line
        if not last_line:
            return "0" * 64
        try:
            return json.loads(last_line).get("entry_hash", "0" * 64)
        except json.JSONDecodeError:
            return "0" * 64

    def commit(
        self,
        proposal: ActionProposal,
        passed: bool,
        reason: str,
        human_decision: Optional[bool],
    ) -> str:
        payload = {
            "prev_hash": self.last_hash,
            "timestamp_ns": time.time_ns(),
            "proposal": asdict(proposal),
            "policy_passed": passed,
            "policy_reason": reason,
            "human_accepted": human_decision,
        }
        serialized = json.dumps(payload, sort_keys=True)
        entry_hash = hashlib.sha256(serialized.encode("utf-8")).hexdigest()
        record = {**payload, "entry_hash": entry_hash}

        with open(self.log_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(record) + "\n")

        self.last_hash = entry_hash
        return entry_hash


def main():
    logger = AuditLogger()
    print(f"[Gate Online] Tip hash: {logger.last_hash[:16]}...")

    demo_proposals = [
        ActionProposal("act_001", "touch report.md", "./workspace/report.md", 1),
        ActionProposal("act_002", "rm -rf /", "/etc", 3),
        ActionProposal("act_003", "rm temp.txt", "./workspace/temp.txt", 2),
    ]

    for p in demo_proposals:
        print("\n" + "-" * 40)
        print(f"Action: {p.command} (Path: {p.target_path}, Risk: {p.risk_tier})")
        passed, reason = PolicyEngine.evaluate(p)
        print(f"Policy: {reason}")

        decision = None
        if passed:
            while True:
                choice = input("Approve? [y/N]: ").strip().lower()
                if choice in ("y", "yes"):
                    decision = True
                    print("[APPROVED]")
                    break
                elif choice in ("n", "no", ""):
                    decision = False
                    print("[REJECTED]")
                    break
        else:
            print("[AUTO-BLOCKED]")

        entry_hash = logger.commit(p, passed, reason, decision)
        print(f"Committed: {entry_hash[:16]}...")


if __name__ == "__main__":
    main()
