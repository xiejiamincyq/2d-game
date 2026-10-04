"""Pure unit registration/config records; never game or save evidence."""
import copy
import sys
import unittest
import tempfile
import hashlib
import subprocess
from pathlib import Path
from unittest.mock import Mock,patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'art'))
from run_late_crowd_matrix import make_slots,check_slot_config,command_for,verify_sources,fresh_errors,run_case,check_process_identity,stop_owned_process,matrix_acceptance
import run_late_crowd_matrix as matrix

class LateCrowdMatrixTest(unittest.TestCase):
    def test_launch_action_must_be_explicit(self):
        result = subprocess.run([sys.executable,'-B',matrix.__file__,'--batch','unit','--godot','not-existing.exe'],capture_output=True)
        self.assertEqual(2,result.returncode)
        self.assertIn(b'--register-only --run-registered',result.stderr)

    def test_delayed_child_is_witnessed_without_relaxing_parent_binding(self):
        process = Mock(pid=123,poll=Mock(return_value=None))
        child = b'{"ProcessId":456,"ParentProcessId":123,"Name":"Godot.exe"}'
        with patch.object(matrix.os,'name','nt'),patch.object(matrix.subprocess,'CREATE_NO_WINDOW',0,create=True),patch.object(matrix.subprocess,'run',side_effect=[Mock(stdout=b''),Mock(stdout=child)]),patch.object(matrix.time,'sleep'):
            self.assertEqual([],check_process_identity(123,456,matrix.process_witness(process)))

    def test_pilot_baseline_and_registration_binding_are_exact(self):
        reference = {'one.gd':'hash'}
        report = {'source_sha256':reference,'valid':True,'config':{'run':'late-observer09-dash-v1'}}
        self.assertEqual([],matrix.check_baseline(report,reference))
        for bad in (dict(report,valid=False),dict(report,source_sha256={'two.gd':'hash'}),dict(report,config={'run':'other'})):
            self.assertTrue(matrix.check_baseline(bad,reference))
        self.assertEqual([],matrix.check_registration({'acceptance':'registered','registration_sha256':'hash'},'hash'))
        self.assertTrue(matrix.check_registration({'acceptance':'registered','registration_sha256':'other'},'hash'))

    def test_three_natural_prefixes_and_eighteen_independent_copy_slots(self):
        slots = make_slots('unit')
        self.assertEqual(21,len(slots))
        self.assertEqual(21,len({s['run'] for s in slots}))
        self.assertEqual([20260908,20260909,20260910],[s['seed'] for s in slots[:3]])
        for seed in (20260908,20260909,20260910):
            for movement in ('walk','dash'):
                group = [s for s in slots[3:] if s['seed']==seed and s['movement']==movement]
                self.assertEqual([1,2,3],[s['repeat'] for s in group])
                self.assertEqual({f'unit-prefix-{seed}'},{s['resume'] for s in group})
                self.assertTrue(all(s['resume_strategy']=='copy' for s in group))

    def test_unsafe_or_oversized_batch_is_rejected(self):
        for batch in ('','../outside','a/b','a'*41):
            with self.assertRaises(ValueError):
                make_slots(batch)

    def test_runtime_config_must_match_preregistration(self):
        for slot in make_slots('unit'):
            config = {k:v for k,v in slot.items() if k not in ('repeat','kind')}
            config.update(steps=18000,clock='realtime',checkpoint_wave=3,
                          save_path=f"user://natural-run/{slot['run']}/run.json")
            self.assertEqual([],check_slot_config(slot,config))
            for key,value in [('seed',1),('clock','fixed'),('steps',600),('movement','bogus'),
                              ('resume','other'),('save_path','user://real.json'),('mode','idle')]:
                bad = copy.deepcopy(config)
                bad[key] = value
                self.assertTrue(check_slot_config(slot,bad),key)

    def test_copy_cannot_consume_original_or_lie_about_checkpoint_wave(self):
        for slot in make_slots('unit'):
            config = {k:v for k,v in slot.items() if k not in ('repeat','kind')}
            config.update(steps=18000,clock='realtime',checkpoint_wave=3,
                          save_path=f"user://natural-run/{slot['run']}/run.json")
            config['checkpoint_wave']=1
            self.assertTrue(check_slot_config(slot,config))
            if slot['kind']=='trial':
                config['checkpoint_wave']=3
                config['resume_strategy']='consume'
                self.assertTrue(check_slot_config(slot,config))

    def test_command_uses_native_real_input_and_registered_budget(self):
        slot = make_slots('unit')[3]
        command = command_for(Path('godot.exe'),Path('project'),slot)
        self.assertIn('--windowed',command)
        self.assertIn('res://scripts/art/VerifyLateCrowd.gd',command)
        self.assertIn('--steps=18000',command)
        self.assertIn('--clock=realtime',command)
        self.assertIn('--resume_strategy=copy',command)
        self.assertFalse(any(x in command for x in ('--headless','--fixed-fps','--write-movie')))

    def test_changed_missing_or_outside_source_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root/'one.gd'
            source.write_bytes(b'original')
            hashes = {'one.gd':hashlib.sha256(b'original').hexdigest()}
            self.assertEqual([],verify_sources(root,hashes))
            source.write_bytes(b'changed')
            self.assertTrue(verify_sources(root,hashes))
            self.assertTrue(verify_sources(root,{'missing.gd':hashes['one.gd']}))
            self.assertTrue(verify_sources(root,{'../outside':hashes['one.gd']}))

    def test_any_old_report_log_capture_or_save_transaction_blocks_launch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            slots = make_slots('unit')
            output,store = root/'output',root/'store'
            output.mkdir(); store.mkdir()
            self.assertEqual([],fresh_errors(output,store,slots))
            run = slots[0]['run']
            for relative in (f'{run}.json',f'{run}.log',f'late-{run}.json',f'late-{run}'):
                path = output/relative
                path.write_bytes(b'existing')
                self.assertTrue(fresh_errors(output,store,slots),relative)
                path.unlink()
            (store/run).mkdir()
            for suffix in ('','.tmp','.bak'):
                path = store/run/('run.json'+suffix)
                path.write_bytes(b'existing')
                self.assertTrue(fresh_errors(output,store,slots),suffix)
                path.unlink()

    def test_preflight_cannot_launch_or_replace_existing_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output,store,base = root/'output',root/'store',root/'base'
            output.mkdir(); store.mkdir(); base.mkdir()
            slot = make_slots('unit')[0]
            path = output/f"{slot['run']}.log"
            path.write_bytes(b'original')
            record = run_case(slot,root,root/'not-an-executable',output,base,store,{}, {})
            self.assertEqual('invalid',record['status'])
            self.assertTrue(record['errors'])
            self.assertNotIn('process_id',record)
            self.assertEqual(b'original',path.read_bytes())

    def test_console_launcher_and_witnessed_engine_are_distinct_valid_processes(self):
        # IDs mirror the real native startup probe, but this is a pure unit record.
        witness = [{'ProcessId':55360,'ParentProcessId':44088,'Name':'Godot_v4.7-stable_win64.exe'}]
        self.assertEqual([],check_process_identity(44088,55360,witness))
        self.assertEqual([],check_process_identity(44088,44088,[]))
        for bad in ([],[dict(witness[0],ParentProcessId=1)],[dict(witness[0],ProcessId=1)]):
            self.assertTrue(check_process_identity(44088,55360,bad))

    def test_terminal_handle_is_never_killed_from_stale_pid(self):
        process = Mock(pid=123,poll=Mock(return_value=0))
        with patch('run_late_crowd_matrix.subprocess.run') as launch:
            stop_owned_process(process)
            launch.assert_not_called()
        process.terminate.assert_not_called()
        process.kill.assert_not_called()

    def test_missing_cancelled_or_duplicate_slot_cannot_be_complete(self):
        slots = make_slots('unit')
        records = [dict(s,status='valid_measurement') for s in slots]
        self.assertEqual('measurement_matrix_complete',matrix_acceptance(slots,records))
        for bad in (records[:-1],records[:-1]+[records[0]],
                    records[:-1]+[dict(records[-1],status='cancelled')]):
            self.assertEqual('incomplete_or_invalid',matrix_acceptance(slots,bad))

if __name__=='__main__':
    unittest.main()
