"""Synthetic report-unit contracts, never a claim of actual victories."""
import copy
import importlib.util
import unittest


class ChainReportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.find_spec("check_campaign_chain_report")
        if spec:
            import check_campaign_chain_report
            cls.validator = staticmethod(check_campaign_chain_report.validate)
        else:
            cls.validator = None

    def fixture(self, chapter):
        self.assertIsNotNone(self.validator, "independent terminal report validator missing")
        state = lambda n: {"version": 1, "cleared_chapters": list(range(1, n + 1))}
        bank = {"scripts/Main.gd": "a" * 64}
        report = {"valid": True, "chapter": chapter, "assertions": 600, "moves": 600, "shots": 80,
                  "prerequisite_fixture": [], "samples": [{"state": "CLEARED", "kills": 30}],
                  "chain": {"schema": 1, "enabled": True, "used_preseed": False, "process_id": 42,
                            "returned_to_main": True, "defeated_boss_instance": 77, "expected_kills": 30,
                            "saved_sha256": "b" * 64, "saved_state": state(chapter), "before_state": state(chapter - 1),
                            "source_bank": bank, "parent_report_sha256": "" if chapter == 1 else "c" * 64,
                            "parent_saved_sha256": "" if chapter == 1 else "d" * 64,
                            "previous_process_id": 0 if chapter == 1 else 41,
                            "next_entry_chapter": min(chapter + 1, 6),
                            "return_capture": {"file": "build/diagnostics/campaign-goal/unit/returned_main.png", "sha256": "e" * 64}}}
        marker = ["Nursery", "Foundry", "Salt", "Archive", "Echo", "Rift"][chapter - 1]
        args = [report, chapter, 0, f"TEST PASS: Verify{marker}ChapterFlow 600\n", state(chapter), "b" * 64, bank]
        return args

    def test_six_leg_metadata(self):
        for chapter in range(1, 7):
            with self.subTest(chapter=chapter):
                self.assertEqual(self.validator(*self.fixture(chapter)), [])

    def test_bad_terminal(self):
        for label in ("exit", "error", "duplicate", "counter", "wrong_marker"):
            args = self.fixture(2)
            if label == "exit": args[2] = 1
            if label == "error": args[3] += "SCRIPT ERROR: fake\n"
            if label == "duplicate": args[3] *= 2
            if label == "counter": args[3] = args[3].replace("600", "0")
            if label == "wrong_marker": args[3] = args[3].replace("Foundry", "Nursery")
            with self.subTest(label=label): self.assertTrue(self.validator(*args))

    def test_false_provenance(self):
        for key, value in {"enabled": False, "used_preseed": True, "returned_to_main": False,
                           "schema": True, "process_id": 41, "defeated_boss_instance": 0,
                           "expected_kills": 31, "saved_sha256": "z" * 64, "parent_report_sha256": "",
                           "parent_saved_sha256": "", "next_entry_chapter": 4, "source_bank": {},
                           "saved_state": {"version": True, "cleared_chapters": [1, 2]},
                           "before_state": {"version": 1, "cleared_chapters": [1, 2]}, "return_capture": {}}.items():
            args = self.fixture(2)
            args[0]["chain"][key] = value
            with self.subTest(key=key): self.assertTrue(self.validator(*args))

    def test_false_gameplay(self):
        for key, value in {"valid": 1, "chapter": True, "moves": 500, "shots": 50,
                           "prerequisite_fixture": [1], "samples": [], "chain": None}.items():
            args = self.fixture(2)
            args[0][key] = value
            with self.subTest(key=key): self.assertTrue(self.validator(*args))

    def test_input_immutable(self):
        args = self.fixture(6)
        before = copy.deepcopy(args)
        self.validator(*args)
        self.assertEqual(args, before)


if __name__ == "__main__":
    unittest.main()
