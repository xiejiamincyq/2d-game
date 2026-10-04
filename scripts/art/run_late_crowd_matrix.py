"""Sequential source-frozen natural third-wave-copy matrix; no production writes."""
import re
import hashlib
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime,timezone
from pathlib import Path

SEEDS = (20260908,20260909,20260910)
PILOT_SUPPORT = ('scripts/tests/LateCrowdLedgerTest.gd','scripts/tests/test_late_crowd_report.py',
                 'scripts/tests/test_natural_run_report.py','scripts/tests/run_tests.ps1')

def check_baseline(report,reference):
    return [] if (report.get('valid') is True and report.get('config',{}).get('run')=='late-observer09-dash-v1'
                  and report.get('source_sha256')==reference) else ['not the accepted pilot baseline']

def check_registration(progress,digest):
    return [] if progress.get('acceptance')=='registered' and progress.get('registration_sha256')==digest else ['registration changed or already started']

def make_slots(batch):
    if not isinstance(batch,str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,40}',batch):
        raise ValueError('safe unique batch ID required')
    slots = [{'run':f'{batch}-prefix-{seed}','seed':seed,'kind':'prefix','repeat':0,
              'mode':'checkpoint','movement':'dash','resume':'','resume_strategy':'consume'} for seed in SEEDS]
    slots += [{'run':f'{batch}-{seed}-{movement}-{repeat}','seed':seed,'kind':'trial','repeat':repeat,
               'mode':'flow','movement':movement,'resume':f'{batch}-prefix-{seed}','resume_strategy':'copy'}
              for seed in SEEDS for repeat in (1,2,3) for movement in ('walk','dash')]
    return slots

def check_slot_config(slot,config):
    expected = {k:v for k,v in slot.items() if k not in ('repeat','kind')}
    expected.update(steps=18000,clock='realtime',checkpoint_wave=3,
                    save_path=f"user://natural-run/{slot['run']}/run.json")
    return [f'wrong registered config: {key}' for key,value in expected.items() if config.get(key)!=value]

def command_for(godot,project,slot):
    config = {k:v for k,v in slot.items() if k not in ('repeat','kind')}
    config.update(steps=18000,clock='realtime',checkpoint_wave=3)
    return [str(godot),'--path',str(project),'--windowed','--resolution','1280x720',
            '--max-fps','60','--script','res://scripts/art/VerifyLateCrowd.gd','--']+[
                f'--{key}={value}' for key,value in config.items()]

def verify_sources(project,hashes):
    root = project.resolve()
    errors = []
    for relative,digest in hashes.items():
        path = (root/relative).resolve()
        if not path.is_relative_to(root) or not path.is_file() or sha256(path)!=digest:
            errors.append('source mismatch: '+relative)
    return errors

def fresh_errors(output,store,slots):
    errors = []
    for slot in slots:
        run = slot['run']
        paths = [output/name for name in (f'{run}.json',f'{run}.log',f'late-{run}.json',f'late-{run}')]
        paths += [store/run/('run.json'+suffix) for suffix in ('','.tmp','.bak')]
        if any(path.exists() for path in paths):
            errors.append('existing evidence or save: '+run)
    return errors

def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda:source.read(1024*1024),b''):
            digest.update(block)
    return digest.hexdigest()

def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def check_process_identity(launcher_pid,engine_pid,witness):
    bound = launcher_pid==engine_pid or any(p['ProcessId']==engine_pid and p['ParentProcessId']==launcher_pid for p in witness)
    return [] if bound and type(engine_pid) is int and engine_pid>0 else ['unbound engine process']

def process_witness(process):
    if os.name!='nt':
        return []
    script = f"Get-CimInstance Win32_Process -Filter 'ParentProcessId={process.pid}' | Select-Object ProcessId,ParentProcessId,Name | ConvertTo-Json -Compress"
    # Only observe direct children of this live owned launcher. A delayed child
    # gets a bounded startup observation, never a retry of the gameplay case.
    for attempt in range(8):
        if process.poll() is not None:
            return []
        result = subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-Command',script],
                                capture_output=True,timeout=2,creationflags=subprocess.CREATE_NO_WINDOW,check=True)
        raw = result.stdout.decode('utf-8-sig').strip()
        value = json.loads(raw) if raw else []
        value = value if isinstance(value,list) else [value]
        if value:
            return value
        if attempt<7:
            time.sleep(.1)
    return []

def stop_owned_process(process):
    if process.poll() is not None:
        return
    if os.name=='nt':
        # Godot's console wrapper owns the visible engine child. Stop only this
        # still-live Popen tree, not a PID inferred from a stale progress file.
        stopped = subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=15)
        if stopped.returncode and process.poll() is None:
            raise RuntimeError('could not stop owned Godot process tree')
    else:
        process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=10)

def save_json(path,value):
    # Progress is generated local state. All original per-run evidence is write-once.
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value,ensure_ascii=False,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    temporary.replace(path)

def run_case(slot,project,godot,output,base,store,hashes,runtime_hashes):
    run = slot['run']
    record = dict(slot,status='invalid',errors=[])
    errors = record['errors']
    errors += verify_sources(project,hashes)+fresh_errors(output,store,[slot])
    if errors:
        return record
    log = output/f'{run}.log'
    command = command_for(godot,project,slot)
    record['command'] = command
    record['started_utc'] = datetime.now(timezone.utc).isoformat()
    with log.open('x',encoding='utf-8') as sink:
        process = subprocess.Popen(command,cwd=project,stdout=sink,stderr=subprocess.STDOUT)
        record['launcher_process_id'] = process.pid
        print(f"CASE PROCESS {run} pid={process.pid} logfile={log}",flush=True)
        try:
            record['process_witness'] = process_witness(process)
            record['exit_code'] = process.wait(timeout=930)
        except subprocess.TimeoutExpired:
            stop_owned_process(process)
            errors.append('owned process exceeded registered external watchdog; stopped, no retry')
        finally:
            if process.poll() is None:
                stop_owned_process(process)
    record['finished_utc'] = datetime.now(timezone.utc).isoformat()
    errors += verify_sources(project,hashes)
    if errors or record.get('exit_code')!=0:
        errors.append('native process did not complete valid measurement')
        return record
    report_path = output/f'{run}.json'
    manifest_path = output/f'late-{run}.json'
    report,data = read_json(report_path),read_json(manifest_path)
    errors += check_slot_config(slot,report['config'])
    record['process_id'] = report['process_id']
    errors += check_process_identity(record['launcher_process_id'],record['process_id'],record['process_witness'])
    if report['source_sha256']!=runtime_hashes:
        errors.append('process or registered runtime source mismatch')
    checkpoint = output/f"{slot['resume']}.json" if slot['resume'] else None
    checker = [sys.executable,'-B',str(project/'scripts/art/check_late_crowd_report.py'),str(manifest_path),
               '--report',str(report_path),'--log',str(log)]
    if checkpoint:
        checker += ['--checkpoint',str(checkpoint)]
    checked = subprocess.run(checker,cwd=project,capture_output=True,timeout=120)
    (base/f'{run}-external.log').write_bytes(checked.stdout+checked.stderr)
    if checked.returncode!=0:
        errors.append('external observer/base/PNG verifier rejected original records')
    record.update(report_sha256=sha256(report_path),observer_sha256=sha256(manifest_path),log_sha256=sha256(log))
    if slot['kind']=='prefix':
        source = store/run/'run.json'
        if report['terminal']!='checkpoint' or not source.is_file() or sha256(source)!=report['isolated_save_sha256']:
            errors.append('natural prefix did not leave authenticated third-wave checkpoint')
        else:
            destination = base/'saves'/f'{run}.json'
            shutil.copyfile(source,destination)
            record['checkpoint_sha256'] = sha256(destination)
    else:
        origin = read_json(checkpoint)
        if sha256(store/slot['resume']/'run.json')!=origin['isolated_save_sha256']:
            errors.append('original checkpoint changed after copied trial')
    samples = report['samples']
    record['metrics'] = {'steps':len(samples),'terminal':report['terminal'],'map_seed':report['map_seed'],
        'min_hp':min(s['health'] for s in samples),'dash_requests':sum(s['dash_requested'] for s in samples),
        'dash_active_steps':sum(s['dash_active'] for s in samples),'max_low_streak':max(r['low_streak'] for r in data['observations']),
        'random_changes':samples[-1]['pilot_random_heading_changes'],'escape_attempts':samples[-1]['pilot_escape_events'],
        'peak':{k:data['peak'].get(k) for k in ('wave','wall','live','visible','kinds')},
        'native_frames':len(data['frames']),'max_retained':data['max_retained'],
        'window_coverage':slot['kind']=='trial' and bool(data['peak']) and len(data['frames'])>=2}
    record['coverage_status'] = ('not_applicable_prefix' if slot['kind']=='prefix' else
                                 'window_present' if record['metrics']['window_coverage'] else 'coverage_missing')
    record['status'] = 'invalid' if errors else 'valid_measurement'
    return record

def matrix_acceptance(slots,records):
    complete = len(slots)==len(records)==21 and all(s['run']==r['run'] and r['status']=='valid_measurement' for s,r in zip(slots,records))
    return 'measurement_matrix_complete' if complete else 'incomplete_or_invalid'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch',required=True)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--source-report',type=Path,default=Path('build/diagnostics/natural-run/late-observer09-dash-v1.json'))
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--register-only',action='store_true')
    action.add_argument('--run-registered',action='store_true')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    godot = args.godot.resolve()
    slots = make_slots(args.batch)
    output = project/'build/diagnostics/natural-run'
    base = project/'build/diagnostics/late-matrix'/args.batch
    store = Path(os.environ['APPDATA'])/'Godot/app_userdata/废土清剿协议/natural-run'
    if not godot.is_file():
        parser.error('existing configured Godot required; no installer')
    registry_path = base/'registration.json'
    progress_path = base/'matrix.json'
    if args.run_registered:
        registry = read_json(registry_path)
        if check_registration(read_json(progress_path),sha256(registry_path)) or registry['slots']!=slots or registry['godot']!=str(godot):
            parser.error('only an unchanged, not-yet-started registration may launch')
    else:
        baseline = read_json(project/args.source_report)
        reference = read_json(project/'build/diagnostics/late-observer/source-v1-sha256.json')
        if len(reference)!=60 or not all(path in reference for path in PILOT_SUPPORT):
            parser.error('accepted 60-file pilot freeze required')
        reference = {path:digest for path,digest in reference.items() if path not in PILOT_SUPPORT}
        if check_baseline(baseline,reference):
            parser.error('only the accepted pilot report and its exact frozen baseline may register')
        runtime_hashes = baseline['source_sha256']
        if len(runtime_hashes)!=56 or verify_sources(project,runtime_hashes) or fresh_errors(output,store,slots):
            parser.error('current 56-source baseline and unused evidence/save IDs required')
        hashes = dict(runtime_hashes)
        for relative in (*PILOT_SUPPORT,
                         'scripts/art/run_late_crowd_matrix.py','scripts/tests/test_late_crowd_matrix.py',
                         'build/diagnostics/late-observer/encode_peak.py',
                         'build/diagnostics/late-observer/source-v1-sha256.json'):
            hashes[relative] = sha256(project/relative)
        base.mkdir(parents=True,exist_ok=False)
        (base/'saves').mkdir()
        for relative in hashes:
            target = base/'source'/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(project/relative,target)
        binaries = {str(godot):sha256(godot)}
        engine = Path(str(godot).replace('_console.exe','.exe'))
        if engine!=godot and engine.is_file():
            binaries[str(engine)] = sha256(engine)
        registry = {'batch':args.batch,'registered_utc':datetime.now(timezone.utc).isoformat(),
                    'slots':slots,'godot':str(godot),'tool_sha256':binaries,
                    'runtime_sha256':runtime_hashes,'frozen_sha256':hashes,
                    'commands':[command_for(godot,project,slot) for slot in slots],
                    'scope':'3 natural prefixes +18 copied native R trials; not stress60/performance/human acceptance',
                    'steps':18000,'outer_watchdog_seconds':930,'native_viewport':[1280,720],
                    'window':'earliest ordinary waves4-6 living peak; same-segment wall +/-3s, native at most10fps,120-image cap',
                    'coverage_policy':'missing window or Lobber coverage stays missing; never replace seeds or rerun failed slots',
                    'offline_encoder_sha256':hashes['build/diagnostics/late-observer/encode_peak.py']}
        save_json(registry_path,registry)
        save_json(progress_path,{'batch':args.batch,'acceptance':'registered','registration_sha256':sha256(registry_path),
                                'runs':[dict(s,status='not_run') for s in slots]})
    errors = verify_sources(project,registry['frozen_sha256'])+fresh_errors(output,store,slots)
    errors += verify_sources(base/'source',registry['frozen_sha256'])
    errors += [f'tool changed: {path}' for path,digest in registry['tool_sha256'].items() if sha256(Path(path))!=digest]
    if errors:
        raise RuntimeError('; '.join(errors))
    print(f"MATRIX REGISTERED {args.batch} slots={len(slots)} frozen={len(registry['frozen_sha256'])}",flush=True)
    if args.register_only:
        return 0
    progress = read_json(progress_path)
    progress['acceptance'] = 'running'
    progress['registration_sha256'] = sha256(registry_path)
    save_json(progress_path,progress)
    for index,slot in enumerate(slots):
        print(f"MATRIX RUN {index+1}/{len(slots)} {slot['run']}",flush=True)
        progress['runs'][index]['status'] = 'running'
        save_json(progress_path,progress)
        try:
            record = run_case(slot,project,godot,output,base,store,registry['frozen_sha256'],registry['runtime_sha256'])
        except (KeyboardInterrupt,OSError,ValueError,TypeError,KeyError,RuntimeError,subprocess.SubprocessError) as exc:
            record = dict(slot,status='invalid',errors=[f'{type(exc).__name__}: {exc}'])
        progress['runs'][index] = record
        save_json(progress_path,progress)
        print(f"MATRIX RESULT {slot['run']} {record['status']} {record.get('metrics',{})} errors={record['errors']}",flush=True)
        if record['status']!='valid_measurement':
            for remaining in progress['runs'][index+1:]:
                remaining.update(status='cancelled',errors=['prior slot failed; stopped without retry'])
            break
    progress['acceptance'] = matrix_acceptance(slots,progress['runs'])
    progress['window_covered_trials'] = sum(r.get('metrics',{}).get('window_coverage',False) for r in progress['runs'])
    progress['window_coverage_status'] = 'all_18_windows_present' if progress['window_covered_trials']==18 else 'coverage_missing'
    progress['finished_utc'] = datetime.now(timezone.utc).isoformat()
    save_json(progress_path,progress)
    print(f"MATRIX COMPLETE {progress['acceptance']} {progress_path}",flush=True)
    return 0 if progress['acceptance']=='measurement_matrix_complete' else 2

if __name__=='__main__':
    raise SystemExit(main())
