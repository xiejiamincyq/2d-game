"""Read-only late-ordinary-wave observer and selected native-frame verifier."""
import math
import re
from collections import Counter

def finite_vector(value, size):
    return isinstance(value,list) and len(value)==size and all(type(x) in (int,float) and math.isfinite(x) for x in value)

def point(transform, xy):
    return [transform[0]*xy[0]+transform[2]*xy[1]+transform[4],
            transform[1]*xy[0]+transform[3]*xy[1]+transform[5]]

def check_binding(data, report):
    rows = {r['index']:r for r in data['observations']}
    indices = [s.get('late_index') for s in report['samples']]
    expected = list(rows)
    # The base leaves the final game_over physics step to the real result UI.
    final = rows[expected[-1]] if expected else {}
    result = report.get('result',{})
    if (final.get('state')=='RESULT' and report.get('terminal') in ('death','victory')
            and result.get('terminal')==report['terminal'] and final.get('health')==result.get('health')
            and (report['terminal']=='victory' or final.get('health')==0)):
        expected.pop()
    if indices != expected:
        return ['observer/base sample coverage mismatch']
    for sample in report['samples']:
        row = rows.get(sample.get('late_index'))
        if not row or any(sample[key] != row[other] for key,other in
                          [('frame','frame'),('position','position'),('actual_input','input_post')]):
            return ['observer/base physics sample mismatch']
    return []

def body_rect(body, canvas):
    r = body['radius']
    corners = [point(canvas,point(body['transform'],[x,y])) for x in (-r,r) for y in (-r,r)]
    xs,ys = zip(*corners)
    return [min(xs),min(ys),max(xs)-min(xs),max(ys)-min(ys)]

def check_entities(info, canvas):
    bodies = info['bodies']
    if not finite_vector(canvas,6) or len({b['id'] for b in bodies}) != len(bodies):
        return ['invalid canvas or duplicate actor identity']
    visible = 0
    for body in bodies:
        if (not finite_vector([body['health'],body['radius']],2) or body['health'] <= 0 or body['radius'] <= 0 or type(body['id']) is not int or body['id'] <= 0
                or not finite_vector(body['position'],2) or not finite_vector(body['transform'],6)
                or not finite_vector(body['screen_rect'],4) or body['position'] != body['transform'][4:]):
            return ['invalid live body']
        rect = body_rect(body,canvas)
        on_screen = rect[0] <= 1280 and rect[1] <= 720 and rect[0]+rect[2] >= 0 and rect[1]+rect[3] >= 0
        if body['visible'] is not on_screen or any(not math.isclose(a,b,abs_tol=0.001) for a,b in zip(rect,body['screen_rect'])):
            return ['invalid body screen envelope']
        visible += on_screen
        if 'windup' in body:
            windup = body['windup']
            if (body['kind']!='LOBBER' or not finite_vector(windup['position'],2)
                    or windup['radius']!=72 or not finite_vector([windup['remaining']],1) or windup['remaining']<0):
                return ['invalid lobber windup']
    return [] if (info.get('live',len(bodies)) == len(bodies) and info['visible'] == visible
                  and info['kinds'] == dict(Counter(b['kind'] for b in bodies))) else ['live/visible/kind counts mismatch']

def check_clearance(row, data):
    position,radius = row['position'],row['player_radius']
    if not finite_vector([radius],1) or radius<=0:
        return ['invalid player radius']
    x,y,w,h = data['bounds']
    gap = min(position[0]-x,x+w-position[0],position[1]-y,y+h-position[1])-radius
    for x,y,w,h in data['terrain']:
        nearest = [max(x,min(x+w,position[0])),max(y,min(y+h,position[1]))]
        gap = min(gap,math.dist(position,nearest)-radius)
    enemy_gap = min((math.dist(position,b['position'])-radius-b['radius'] for b in row['bodies']),default=None)
    if (not math.isclose(gap,row['terrain_gap'],abs_tol=.001) or
            (enemy_gap is None and row['nearest_enemy_gap'] is not None) or
            (enemy_gap is not None and not math.isclose(enemy_gap,row['nearest_enemy_gap'],abs_tol=.001))):
        return ['conservative clearance mismatch']
    for warning in row['warnings']:
        if (not finite_vector(warning['position'],2) or not finite_vector([warning['radius'],warning['elapsed'],warning['duration']],3)
                or warning['radius']<=0 or not 0<=warning['elapsed']<warning['duration']):
            return ['invalid lobbed flight warning']
    return []

def check_observer(data, require_window=False):
    errors = []
    rows = data['observations']
    if not rows:
        return ['no physics observations']
    travelled, streak, previous, segment = 0.0, 0, None, 0
    for index,row in enumerate(rows,1):
        eligible = row['state']=='PLAYING' and row['wave'] in (4,5,6) and not row['boss'] and not row['collection']
        if (row['index'] != index or row['frame'] != row['pre_frame'] or row['eligible'] is not eligible
                or row['pre_delta'] != row['post_delta'] or not 0 < row['pre_delta'] <= 1/60+1e-6
                or not finite_vector(row['input_pre'],2) or not finite_vector(row['input_post'],2)
                or math.dist(row['input_pre'],row['input_post']) > 1e-5
                or not finite_vector(row['pre_position'],2) or not finite_vector(row['position'],2)
                or (previous and (row['frame']<=previous['frame'] or row['wall']<=previous['wall']))):
            return ['invalid phase/frame/delta/input']
        if not previous or not eligible or not previous['eligible'] or row['frame'] != previous['frame']+1 or row['wave'] != previous['wave']:
            segment += 1
        if row['segment'] != segment:
            return ['incorrect continuous segment']
        gap = math.dist(previous['position'],row['pre_position']) if previous and previous['frame']+1==row['frame'] else 0
        distance = math.dist(row['pre_position'],row['position'])
        travelled += gap+distance
        vector = row['input_pre']
        norm = math.hypot(*vector)
        along = sum((a-b)*v for a,b,v in zip(row['position'],row['pre_position'],vector))/norm if norm else 0
        low = row['walk_budget'] > 0 and along < row['walk_budget']*.1
        streak = streak+1 if low and previous and row['segment']==previous['segment'] else int(low)
        if (not math.isclose(gap,row['callback_gap'],abs_tol=0.001)
                or not math.isclose(travelled,row['travelled'],abs_tol=0.01,rel_tol=1e-6)
                or not math.isclose(along,row['along_input'],abs_tol=0.001)
                or row['low_progress'] is not low or row['low_streak'] != streak):
            errors.append('motion or low-progress reconstruction mismatch')
            break
        errors += check_entities(row,row['canvas'])
        errors += check_clearance(row,data)
        previous = row
    losses = {'health':0.0,'shield':0.0}
    for event in data['loss_events']:
        loss = max(0,event['previous']-event['current'])
        if not math.isclose(loss,event['loss'],abs_tol=1e-6):
            errors.append('loss callback arithmetic mismatch')
        if event['state']=='PLAYING':
            losses[event['kind']] += loss
    if any(not math.isclose(losses[k],data[k+'_loss'],abs_tol=1e-5) for k in losses):
        errors.append('accumulated callback losses mismatch')
    for row in rows:
        for kind in losses:
            observed = sum(e['loss'] for e in data['loss_events'] if e['kind']==kind and e['state']=='PLAYING' and e['wall']<=row['wall'])
            if not math.isclose(observed,row[kind+'_loss'],abs_tol=1e-5):
                return errors+['sample loss ledger mismatch']
    candidates = [r for r in rows if r['eligible']]
    peak = max(candidates,key=lambda r:r['live'],default={})
    visible_peak = max(candidates,key=lambda r:r['visible'],default={})
    if data['peak'] != peak or data['visible_peak'] != visible_peak:
        errors.append('wrong global ordinary-wave peak or tie')
    if data['viewport'] != [1280,720] or data['display'] in ('','headless') or not data['adapter']:
        errors.append('not expected native viewport')
    if data['cache_limit'] != 120 or not 0 <= data['max_retained'] <= 120:
        errors.append('unbounded capture cache')
    history = data['capture_history']
    previous = None
    for capture in history:
        row = rows[capture['observation']-1]
        if (not row['eligible'] or capture['frame'] != row['frame'] or capture['segment'] != row['segment']
                or capture['wall'] < row['wall'] or (previous and
                (capture['wall']-previous['wall'] < .1-1e-6 or capture['frame'] <= previous['frame']
                 or capture['process_frame'] <= previous['process_frame']))):
            errors.append('invalid wall-paced draw binding')
            break
        previous = capture
    expected = [h for h in history if peak and h['segment']==peak['segment'] and abs(h['wall']-peak['wall']) <= 3]
    frames = data['frames']
    if len(frames) != len(expected) or any(any(frame[k] != h[k] for k in h) for frame,h in zip(frames,expected)):
        errors.append('selected window omits or substitutes drawn frames')
    for i,frame in enumerate(frames):
        if frame['path'] != f"build/diagnostics/natural-run/late-{data['run']}/peak-{i:03}.png" or not re.fullmatch(r'[0-9a-f]{64}',frame['sha256']):
            errors.append('invalid frame path/hash')
        if 'entities' in frame:
            errors += check_entities(frame['entities'],frame['entities']['canvas'])
    if require_window and (not peak or len(frames)<2):
        errors.append('ordinary late window missing')
    return errors

if __name__ == '__main__':
    import argparse
    import hashlib
    import json
    from pathlib import Path
    from PIL import Image
    from check_natural_run_report import check_report,check_log,check_resume
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest',type=Path)
    parser.add_argument('--report',type=Path,required=True)
    parser.add_argument('--log',type=Path,required=True)
    parser.add_argument('--checkpoint',type=Path)
    parser.add_argument('--require-window',action='store_true')
    args = parser.parse_args()
    data = json.loads(args.manifest.read_text(encoding='utf-8'))
    report = json.loads(args.report.read_text(encoding='utf-8'))
    errors = check_observer(data,args.require_window)+check_binding(data,report)+check_report(report)+check_log(args.log.read_text(encoding='utf-8-sig'),data['run'])
    if data['run'] != report['config']['run'] or data['source_sha256'] != report['source_sha256']:
        errors.append('observer/report source binding mismatch')
    if data['map_seed'] != report['map_seed']:
        errors.append('frozen combat map mismatch')
    if report['config']['resume']:
        if args.checkpoint is None:
            errors.append('original checkpoint missing')
        else:
            checkpoint = json.loads(args.checkpoint.read_text(encoding='utf-8'))
            errors += check_report(checkpoint)+check_resume(checkpoint,report,hashlib.sha256(args.checkpoint.read_bytes()).hexdigest())
    project = Path(__file__).resolve().parents[2]
    for relative,digest in data['source_sha256'].items():
        source = (project/relative).resolve()
        if not source.is_relative_to(project) or hashlib.sha256(source.read_bytes()).hexdigest()!=digest:
            errors.append('current source mismatch: '+relative)
    for frame in data['frames']:
        source = (project/frame['path']).resolve()
        if not source.is_relative_to(project) or hashlib.sha256(source.read_bytes()).hexdigest()!=frame['sha256']:
            errors.append('native frame bytes mismatch')
            continue
        with Image.open(source) as image:
            if image.size != (1280,720) or len(set(image.convert('L').getextrema())) != 2:
                errors.append('flat or incorrectly sized native frame')
    print(json.dumps({'valid':not errors,'errors':errors,'observations':len(data['observations']),
                      'frames':len(data['frames']),'peak_live':data['peak'].get('live'),
                      'scope':'ordinary late observer integrity, not full matrix/performance/human'},ensure_ascii=False))
    raise SystemExit(bool(errors))
