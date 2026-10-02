"""Adapter and power-policy tests; no model weights or network required."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import torch
from pydantic import ValidationError

import server


QUESTIONS = {
    "route": {
        "type": "choice",
        "instructions": "Route the ticket",
        "criteria": {"billing": "Charges and refunds", "technical": "Bugs"},
    },
    "refund": {"type": "noul", "instructions": "Is a refund requested?"},
    "urgency": {
        "type": "score",
        "instructions": "How urgent is it?",
        "criteria": ["can wait", "this week", "today"],
    },
}


class DecisionTests(unittest.TestCase):
    def setUp(self):
        self.model = Mock(backend="torch")
        self.model.probs.return_value = [
            torch.tensor([0.8, 0.2]),
            torch.tensor([0.1, 0.9]),
            torch.tensor([0.1, 0.2, 0.7]),
        ]
        for name, value in (("_model", self.model), ("_tokenizer", object())):
            p = patch.object(server, name, value)
            p.start()
            self.addCleanup(p.stop)
        for name, target in (("load", "server._load"), ("ac", "server.on_ac"), ("admit", "kev.model.admit")):
            p = patch(target)
            setattr(self, name, p.start())
            self.addCleanup(p.stop)
        self.ac.return_value = True
        self.admit.return_value = {"ids": [1, 2, 3]}

    def test_all_question_types_use_native_api(self):
        def probabilities(enc):
            self.assertTrue(server._lock.locked())
            return self.model.probs.return_value

        self.model.probs.side_effect = probabilities
        result = server.decide({"ticket": "Refund this duplicate charge today."}, QUESTIONS)
        self.assertEqual(result["model"], "jaredpalmer/kev-4b")
        self.assertEqual(result["answers"]["route"]["choice"], "billing")
        self.assertEqual(result["answers"]["route"]["probabilities"], {"billing": 0.8, "technical": 0.2})
        self.assertEqual(result["answers"]["refund"]["noul"], 0.9)
        self.assertEqual(result["answers"]["urgency"]["score"], 1.6)
        self.assertEqual(result["answers"]["urgency"]["legend"]["2"], "today")
        self.assertEqual(result["usage"]["input_tokens"], 3)
        record = self.admit.call_args.args[2]
        self.assertIn("ticket: Refund", record["state"])
        self.assertEqual(record["questions"][0]["options"], ["billing: Charges and refunds", "technical: Bugs"])
        self.assertEqual(self.admit.call_args.kwargs, {"truncate": False})

    def test_invalid_questions_fail_before_loading(self):
        for questions in ({}, {"route": {"type": "choice", "criteria": {}}}, {"urgency": {"type": "score", "criteria": []}}):
            with self.subTest(questions=questions), self.assertRaises(ValidationError):
                server.decide("test", questions)
        self.load.assert_not_called()
        self.model.probs.assert_not_called()

    def test_battery_unloads_and_rejects_inference(self):
        self.ac.return_value = False
        with self.assertRaisesRegex(RuntimeError, "only runs on AC"):
            server.decide("test", QUESTIONS)
        self.assertIsNone(server._model)
        self.assertIsNone(server._tokenizer)
        self.load.assert_not_called()
        self.model.probs.assert_not_called()

    def test_unplugged_during_load_does_not_infer(self):
        self.ac.side_effect = [True, False]
        with self.assertRaisesRegex(RuntimeError, "only runs on AC"):
            server.decide("test", QUESTIONS)
        self.load.assert_called_once()
        self.assertIsNone(server._model)
        self.model.probs.assert_not_called()

    def test_batch_preserves_order_and_checks_power_between_states(self):
        self.ac.side_effect = [True, True, False]
        with self.assertRaisesRegex(RuntimeError, "only runs on AC"):
            server.decide_batch(["first", "second"], QUESTIONS)
        self.model.probs.assert_called_once()
        self.assertEqual(self.admit.call_args.args[2]["state"], "first")
        self.ac.side_effect = None
        server._model = self.model
        result = server.decide_batch(["first", "second"], QUESTIONS)
        self.assertEqual(len(result), 2)
        self.assertEqual([c.args[2]["state"] for c in self.admit.call_args_list[-2:]], ["first", "second"])

    def test_context_overflow_does_not_run_model(self):
        self.admit.side_effect = ValueError("state exceeds context")
        with self.assertRaisesRegex(ValueError, "exceeds context"):
            server.decide("long text", QUESTIONS)
        self.model.probs.assert_not_called()

    def test_watcher_survives_load_failure_and_then_unloads(self):
        self.ac.side_effect = [True, False]
        self.load.side_effect = RuntimeError("download failed")
        with patch.object(server.time, "sleep", side_effect=[None, StopIteration]):
            with self.assertRaises(StopIteration):
                server.watch_power()
        self.assertIsNone(server._model)


class PowerTests(unittest.TestCase):
    def test_desktop_and_laptop_power_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(server, "POWER_SUPPLY", root):
                self.assertTrue(server.on_ac())
                ac = root / "AC"
                ac.mkdir()
                (ac / "type").write_text("Mains\n")
                (ac / "online").write_text("0\n")
                self.assertFalse(server.on_ac())
                (ac / "online").write_text("1\n")
                self.assertTrue(server.on_ac())
                (ac / "online").unlink()
                self.assertFalse(server.on_ac())


if __name__ == "__main__":
    unittest.main()
