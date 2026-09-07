import os
import unittest
from agent_gate import ActionProposal, AuditLogger, PolicyEngine


class TestAgentGate(unittest.TestCase):
    def setUp(self):
        self.test_log = "test_audit.jsonl"
        if os.path.exists(self.test_log):
            os.remove(self.test_log)

    def tearDown(self):
        if os.path.exists(self.test_log):
            os.remove(self.test_log)

    def test_policy_blocks_hazardous_command(self):
        bad = ActionProposal("1", "rm -rf /", "./workspace", 1)
        passed, msg = PolicyEngine.evaluate(bad)
        self.assertFalse(passed)
        self.assertIn("Blocked", msg)

    def test_policy_blocks_system_directory(self):
        bad = ActionProposal("2", "touch", "/etc/passwd", 1)
        passed, msg = PolicyEngine.evaluate(bad)
        self.assertFalse(passed)
        self.assertIn("protected directory", msg)

    def test_hash_chain_integrity(self):
        logger = AuditLogger(log_path=self.test_log)
        p1 = ActionProposal("10", "echo", "./workspace/a.txt", 1)
        p2 = ActionProposal("11", "echo", "./workspace/b.txt", 1)

        h1 = logger.commit(p1, True, "Passed", True)
        h2 = logger.commit(p2, True, "Passed", False)

        self.assertNotEqual(h1, h2)
        recovered_logger = AuditLogger(log_path=self.test_log)
        self.assertEqual(recovered_logger.last_hash, h2)


if __name__ == "__main__":
    unittest.main()
