"""Synthetic metadata tests, never evidence of a real Boss clear."""
import copy
import unittest
import math
from check_endless_campaign_report import validate, valid_process_receipt, validate_profile


def profile_fixture():
    rows = []
    wall = 3000000
    for index in range(1000):
        interval = 34.0 if index == 100 else 8.0
        if index == 800:
            wall += 2000000
        previous = wall
        wall += int(interval * 1000)
        rows.append(dict(frame=index + 1, callback_index=index + 1, window_id=1 if index < 800 else 2, previous_wall_usec=previous, wall_usec=wall, interval_ms=interval,
                         phase="COMBAT:0" if index < 800 else "BOSS:2", enemies=16 if index < 800 else 1,
                         projectiles=20, draw_calls=10, process_ms=1.0, physics_ms=0.5, objects=30))
    def summary(part):
        intervals = sorted(row["interval_ms"] for row in part)
        size, total = len(part), sum(intervals)
        constant = lambda value: dict(count=size, mean=value, p50=value, p95=value, p99=value, maximum=value)
        return dict(frames=size, wall_seconds=total / 1000, effective_callback_fps=size * 1000 / total,
                    interval_ms=dict(count=size, mean=total / size, p50=intervals[(size + 1) // 2 - 1],
                                     p95=intervals[math.ceil(size * .95) - 1], p99=intervals[math.ceil(size * .99) - 1], maximum=intervals[-1]),
                    process_ms=constant(1.0), physics_ms=constant(.5), enemy_peak=max(row["enemies"] for row in part),
                    projectile_peak=20, draw_call_peak=10, intervals_over_16_667_ms=sum(value > 16.667 for value in intervals),
                    intervals_over_33_333_ms=sum(value > 33.333 for value in intervals))
    return dict(sampled=True, complete=True, overflow=False, invalid_clock=False, fixed_fps_argument=False,
                audio_nodes_enabled=True, audio_driver="SYNTHETIC UNIT FIXTURE", adapter="NOT REAL HARDWARE", driver="unit",
                display_server="unit", sampling_image_readbacks=0, raw_rows=rows, all=summary(rows), combat=summary(rows[:800]),
                boss=summary(rows[800:]), dense_at_least_12=summary(rows[:800]), longest_contiguous_dense_seconds=6.418,
                dense_coverage_available=True)


def fixture(stage=6):
    chapter = (stage - 1) % 6 + 1
    loop = (stage - 1) // 6 + 1
    saved = dict(version=1, cleared_stage=stage, coins=37, inherited_counts={"damage": 1}, pending_clear={})
    before = dict(version=1, cleared_stage=stage - 1, coins=20, inherited_counts={}, pending_clear={})
    bank = {"scripts/Main.gd": "a" * 64}
    endless = dict(schema=1, loop=loop, process_id=101, previous_process_id=100, used_preseed=False,
                   returned_to_main=True, defeated_boss_instance=1, expected_kills=30,
                   before_state=before, saved_state=saved, saved_sha256="b" * 64, source_bank=bank,
                   choice="damage", earned_counts={"damage": 1}, next_entry=dict(loop=stage // 6 + 1, chapter=stage % 6 + 1))
    report = dict(valid=True, chapter=chapter, assertions=100, moves=600, shots=200,
                  prerequisite_fixture=[], samples=[dict(state="CLEARED", kills=31, coins=37)], endless=endless)
    marker = ["Nursery", "Foundry", "Salt", "Archive", "Echo", "Rift"][chapter - 1]
    return [report, stage, 0, f"TEST PASS: Verify{marker}ChapterFlow 100\n", saved, "b" * 64, bank]


class EndlessReportTest(unittest.TestCase):
    def test_raw_profile_exact_slow_frame_recomputation(self):
        self.assertEqual(validate_profile(profile_fixture()), [])
        actual_callback_gap = profile_fixture()
        for row in actual_callback_gap["raw_rows"][100:]:
            row["frame"] += 2
        self.assertEqual(validate_profile(actual_callback_gap), [])
        args = fixture()
        args[0]["performance"] = profile_fixture()
        args[0]["native_scope"] = "source-bound GPU screenshots"
        self.assertTrue(validate(*args))
        args[0]["native_scope"] = "Actual model observations only; no combat pixel captures"
        self.assertEqual(validate(*args), [])

    def test_profile_rejects_fixed_step_filtered_or_incomplete_data(self):
        for key, value in [("fixed_fps_argument", True), ("overflow", True), ("invalid_clock", True),
                           ("complete", False), ("audio_nodes_enabled", False), ("sampling_image_readbacks", 1),
                           ("display_server", "headless"), ("audio_driver", "Dummy")]:
            profile = profile_fixture()
            profile[key] = value
            self.assertTrue(validate_profile(profile), key)
        for change in [lambda p: p["all"]["interval_ms"].__setitem__("maximum", 8),
                       lambda p: p["raw_rows"][100].__setitem__("interval_ms", 8),
                       lambda p: p["raw_rows"].pop(100),
                       lambda p: p.__setitem__("longest_contiguous_dense_seconds", 10),
                       lambda p: p["raw_rows"][10].__setitem__("process_ms", float("nan"))]:
            profile = profile_fixture()
            change(profile)
            self.assertTrue(validate_profile(profile))

    def test_owned_wrapper_child_receipt_requires_live_observation(self):
        receipt = dict(actual_exit=0, engine_process_id=101, launcher_process_id=100, observed_engine_process_ids=[100, 101])
        self.assertTrue(valid_process_receipt(receipt, 101))
        self.assertFalse(valid_process_receipt(receipt, 102))
        for key, value in [("actual_exit", False), ("actual_exit", 1), ("observed_engine_process_ids", [100]),
                           ("observed_engine_process_ids", [101]), ("launcher_process_id", True)]:
            broken = dict(receipt, **{key: value})
            self.assertFalse(valid_process_receipt(broken, 101))

    def test_sixth_clear_advances_to_second_round(self):
        self.assertEqual(validate(*fixture(6)), [])

    def test_two_rounds_advance_to_third(self):
        self.assertEqual(validate(*fixture(12)), [])

    def test_reject_unverified_or_forged_claims(self):
        cases = [
            lambda a: a.__setitem__(2, False),
            lambda a: a.__setitem__(2, 1),
            lambda a: a.__setitem__(3, a[3] + "SCRIPT ERROR: hidden\n"),
            lambda a: a.__setitem__(3, a[3] + a[3]),
            lambda a: a[0].__setitem__("valid", "true"),
            lambda a: a[0].__setitem__("prerequisite_fixture", [1]),
            lambda a: a[0]["endless"].__setitem__("used_preseed", True),
            lambda a: a[0]["endless"].__setitem__("returned_to_main", False),
            lambda a: a[0]["endless"].__setitem__("next_entry", dict(loop=1, chapter=6)),
            lambda a: a[0]["endless"].__setitem__("loop", 2),
            lambda a: a[0]["endless"].__setitem__("choice", "thunder_matrix"),
            lambda a: a[0]["endless"]["earned_counts"].__setitem__("damage", 0),
            lambda a: a[0]["endless"]["before_state"].__setitem__("cleared_stage", 3),
            lambda a: a[0]["samples"][-1].__setitem__("state", "BOSS"),
            lambda a: a[0]["samples"][-1].__setitem__("kills", 29),
            lambda a: a[0]["samples"][-1].__setitem__("coins", 0),
            lambda a: a[0]["endless"].__setitem__("source_bank", {}),
            lambda a: a[0]["endless"].__setitem__("saved_sha256", "c" * 64),
            lambda a: a[0]["endless"].__setitem__("saved_state", {}),
        ]
        for change in cases:
            args = copy.deepcopy(fixture())
            change(args)
            with self.subTest(change=change):
                self.assertTrue(validate(*args))


if __name__ == "__main__":
    unittest.main()
