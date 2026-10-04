from pathlib import Path
import copy
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "art"))
from check_natural_run_report import check_report, check_log, check_resume

SAVE_PATHS = [base + suffix for base in ['user://five_minute_overdrive_run_v1.json',
              'user://five_minute_overdrive_run_test_v1.json'] for suffix in ['', '.tmp', '.bak']]

def fixture():
    return {"valid": True, "acceptance": "measurement_only", "terminal": "step_budget",
            "config": {"steps": 1, "clock": "realtime"}, "map_seed": 426363786,
            "real_saves_before": {path: "absent" for path in SAVE_PATHS},
            "real_saves_after": {path: "absent" for path in SAVE_PATHS},
            "orphan_before": 1, "orphan_after": 0, "result": {}, "restart_verified": False,
            "events": [], "samples": [{"step": 1, "frame": 101, "delta": 1 / 60,
                "wall": 2.1, "simulation": 1 / 60, "aim_dot": 1.0,
                "input": [1, 0], "actual_input": [1, 0], "position": [3.9, 0], "health": 100}]}


class NaturalRunReportTest(unittest.TestCase):
    def test_six_save_records_must_cover_the_actual_known_paths(self):
        report = fixture()
        self.assertEqual([], check_report(report))
        wrong = dict(report['real_saves_before'])
        wrong['user://unrelated.json'] = wrong.pop(SAVE_PATHS[0])
        report.update(real_saves_before=wrong, real_saves_after=wrong)
        self.assertTrue(check_report(report))

    def test_requested_third_wave_checkpoint_cannot_be_first_wave(self):
        # Synthetic unit data, not runtime evidence or a production save.
        report = fixture()
        report['config'].update(mode='checkpoint', checkpoint_wave=3, movement='dash')
        report.update(terminal='checkpoint', final={'state':'SETTLEMENT','wave':3,
                      'snapshot':{'boundary':'settlement','pending_stage':4,'settlement':{'wave':3}}})
        report['samples'] = [dict(report['samples'][0], step=i, frame=100+i, wall=2+i/60,
                                 simulation=i/60, wave=i, dash_requested=False) for i in (1,2,3)]
        report['events'] = [{'event':'state','state':'WAVE_CLEAR','wave':i} for i in (1,2,3)]
        self.assertEqual([], check_report(report))
        for field,value in [('wave',1),('snapshot',{'boundary':'settlement','pending_stage':2,'settlement':{'wave':1}})]:
            bad = copy.deepcopy(report)
            bad['final'][field] = value
            self.assertTrue(check_report(bad), field)
        bad = copy.deepcopy(report)
        bad['samples'][1]['wave'] = 1
        self.assertTrue(check_report(bad))

    def test_walk_cannot_request_dash_or_omit_request_record(self):
        report = fixture()
        report['config']['movement'] = 'walk'
        report['samples'][0]['dash_requested'] = False
        self.assertEqual([], check_report(report))
        for value in [True, 0, None]:
            report['samples'][0]['dash_requested'] = value
            self.assertTrue(check_report(report), value)

    def test_copy_resume_has_own_destination_and_unchanged_source(self):
        checkpoint = {'terminal':'checkpoint','valid':True,'process_id':100,'source_sha256':{'x':'a'},
                      'isolated_save_sha256':'b'*64,
                      'config':{'run':'saved','save_path':'user://natural-run/saved/run.json'},
                      'final':{'snapshot':{'player':{'health':100},'settlement':{'wave':3},
                               'pending_stage':4,'map_seed':426363786,'kills':177,'coins':54,
                               'family_levels':{'drone':2},'upgrade_counts':{'drone':2},'evolution':''}}}
        resumed = {'process_id':200,'source_sha256':{'x':'a'},
                   'samples':[{'wave':4,'state':'PLAYING'}],
                   'config':{'run':'trial','resume':'saved','resume_strategy':'copy',
                             'save_path':'user://natural-run/trial/run.json'},
                   'resume_reference':{'verified':True,'report_sha256':'raw_hash',
                      'snapshot_before':checkpoint['final']['snapshot'],
                      'restored':{key:checkpoint['final']['snapshot'][key] for key in ['player','settlement']},
                      'restored_run':{'wave':3,'waiting_for_advance':True,'map_seed':426363786,'kills':177,'coins':54},
                      'restored_growth':{key:checkpoint['final']['snapshot'][key] for key in
                                         ['coins','family_levels','upgrade_counts','evolution','settlement']},
                      'source_save_path':checkpoint['config']['save_path'],
                      'source_save_sha256':'b'*64,'copied_save_sha256':'b'*64,'source_save_sha256_after':'b'*64}}
        self.assertEqual([], check_resume(checkpoint,resumed,'raw_hash'))
        for field,value in [('source_save_sha256_after','changed'),('copied_save_sha256','changed'),('source_save_path','user://real.json')]:
            bad = copy.deepcopy(resumed)
            bad['resume_reference'][field] = value
            self.assertTrue(check_resume(checkpoint,bad,'raw_hash'), field)
        bad = copy.deepcopy(resumed)
        bad['config']['save_path'] = checkpoint['config']['save_path']
        self.assertTrue(check_resume(checkpoint,bad,'raw_hash'))

        for field,value in [('wave',1),('map_seed',7),('kills',0),('coins',0),('waiting_for_advance',False)]:
            bad = copy.deepcopy(resumed)
            bad['resume_reference']['restored_run'][field] = value
            self.assertTrue(check_resume(checkpoint,bad,'raw_hash'), field)
        bad = copy.deepcopy(resumed)
        bad['resume_reference'].pop('restored_run')
        self.assertTrue(check_resume(checkpoint,bad,'raw_hash'))
        for samples in [[], [{'wave':3,'state':'PLAYING'}], [{'wave':4,'state':'SETTLEMENT'}]]:
            bad = copy.deepcopy(resumed)
            bad['samples'] = samples
            self.assertTrue(check_resume(checkpoint,bad,'raw_hash'), samples)
        for field,value in [('family_levels',{}),('upgrade_counts',{}),('evolution','arc'),('coins',0)]:
            bad = copy.deepcopy(resumed)
            bad['resume_reference']['restored_growth'][field] = value
            self.assertTrue(check_resume(checkpoint,bad,'raw_hash'), field)

    def test_checkpoint_is_a_saved_natural_boundary_not_victory(self):
        report = fixture()
        report.update(terminal="checkpoint", final={"state": "SETTLEMENT", "snapshot": {"boundary": "settlement", "pending_stage": 2}})
        self.assertEqual([], check_report(report))
        report["final"]["snapshot"] = {}
        self.assertTrue(check_report(report))

    def test_cross_process_resume_requires_same_checkpoint_and_different_pid(self):
        checkpoint = {"terminal": "checkpoint", "valid": True, "process_id": 100, "source_sha256": {"x": "a"}, "config": {"run": "saved", "save_path": "user://natural-run/saved/run.json"}, "final": {"snapshot": {"boundary": "settlement", "coins": 23, "player": {"health": 100}, "settlement": {"generation": 1}}}}
        resumed = {"process_id": 200, "source_sha256": {"x": "a"}, "config": {"resume": "saved", "save_path": "user://natural-run/saved/run.json"}, "resume_reference": {"report_sha256": "raw_hash", "snapshot_before": checkpoint["final"]["snapshot"], "restored": {"player": {"health": 100}, "settlement": {"generation": 1}}, "verified": True}}
        self.assertEqual([], check_resume(checkpoint, resumed, "raw_hash"))
        for key, value in [("process_id", 100), ("source_sha256", {"x": "changed"}), ("resume_reference", {"report_sha256": "wrong", "snapshot_before": {}, "verified": False})]:
            bad = copy.deepcopy(resumed)
            bad[key] = value
            self.assertTrue(check_resume(checkpoint, bad, "raw_hash"))
        bad = copy.deepcopy(resumed)
        bad["resume_reference"]["restored"]["player"]["health"] = 0
        self.assertTrue(check_resume(checkpoint, bad, "raw_hash"))

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
