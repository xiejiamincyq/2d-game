from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "art"))
from check_natural_run_report import check_report, check_log


def fixture():
    return {"valid": True, "acceptance": "measurement_only", "terminal": "step_budget",
            "config": {"steps": 1, "clock": "realtime"}, "map_seed": 426363786,
            "real_saves_before": {str(i): "absent" for i in range(6)},
            "real_saves_after": {str(i): "absent" for i in range(6)},
            "orphan_before": 1, "orphan_after": 0, "result": {}, "restart_verified": False,
            "events": [], "samples": [{"step": 1, "frame": 101, "delta": 1 / 60,
                "wall": 2.1, "simulation": 1 / 60, "aim_dot": 1.0,
                "input": [1, 0], "actual_input": [1, 0], "position": [3.9, 0], "health": 100}]}


class NaturalRunReportTest(unittest.TestCase):
    def test_log_must_be_clean_and_complete_once(self):
        marker = "NATURAL_RUN_COMPLETE run=sample valid=true steps=9 terminal=victory"
        self.assertEqual([], check_log(marker, "sample"))
        for log in ["", marker + "\n" + marker, "ERROR: detached viewport\n" + marker, "ObjectDB instances were leaked\n" + marker]:
            self.assertTrue(check_log(log, "sample"))

    def test_valid_budget_is_measurement_not_victory(self):
        self.assertEqual([], check_report(fixture()))

    def test_reject_invalid_aim(self):
        report = fixture()
        report["samples"][0]["aim_dot"] = 0
        self.assertTrue(check_report(report))

    def test_reject_changed_save(self):
        report = fixture()
        report["real_saves_after"]["0"] = "different"
        self.assertTrue(check_report(report))

    def test_reject_wrong_actual_input(self):
        report = fixture()
        report["samples"][0]["actual_input"] = [-1, 0]
        self.assertTrue(check_report(report))

    def test_reject_invented_time(self):
        report = fixture()
        report["samples"][0]["simulation"] = 10
        self.assertTrue(check_report(report))

    def test_reject_false_valid_or_empty_or_leaked(self):
        for key, value in [("valid", False), ("samples", []), ("orphan_after", 9), ("map_seed", 0)]:
            report = fixture()
            report[key] = value
            self.assertTrue(check_report(report))

    def test_death_requires_actual_death_and_restart(self):
        report = fixture()
        report.update(terminal="death", result={"health": 0, "terminal": "death", "snapshot_cleared": True}, restart_verified=True)
        self.assertEqual([], check_report(report))
        report["result"]["health"] = 100
        self.assertTrue(check_report(report))

    def test_budget_cannot_be_truncated(self):
        report = fixture()
        report["config"]["steps"] = 36000
        self.assertTrue(check_report(report))


if __name__ == "__main__":
    unittest.main()
