#!/usr/bin/env python3
"""
verify_audit.py - Independent verification tool for Agent Gate hash chains.
"""

import hashlib
import json
import sys


def verify_chain(log_path: str = "audit_log.jsonl") -> bool:
    expected_prev = None
    line_num = 0

    with open(log_path, "r", encoding="utf-8") as f:
        for line in f:
            line_num += 1
            raw = line.strip()
            if not raw:
                continue

            record = json.loads(raw)
            entry_hash = record.get("entry_hash")
            prev_hash = record.get("prev_hash")

            # Check hash linkage across lines
            if expected_prev is not None and prev_hash != expected_prev:
                print(f"[FAIL] Broken chain at line {line_num}:")
                print(f"       Expected prev_hash: {expected_prev}")
                print(f"       Found prev_hash:    {prev_hash}")
                return False

            # Verify entry hash calculation
            payload = {k: v for k, v in record.items() if k != "entry_hash"}
            serialized = json.dumps(payload, sort_keys=True)
            recalculated = hashlib.sha256(serialized.encode("utf-8")).hexdigest()

            if recalculated != entry_hash:
                print(f"[FAIL] Tampered record at line {line_num}:")
                print(f"       Recorded hash:     {entry_hash}")
                print(f"       Recalculated hash: {recalculated}")
                return False

            expected_prev = entry_hash

    print(f"[PASS] Audit log intact. Verified {line_num} records. Tip hash: {expected_prev[:16]}...")
    return True


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "audit_log.jsonl"
    if not verify_chain(path):
        sys.exit(1)
