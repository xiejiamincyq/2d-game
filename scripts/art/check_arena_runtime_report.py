"""Independent geometry/input checks for the isolated twenty-map runtime matrix."""
import argparse
import hashlib
import json
import math
from pathlib import Path

SEEDS = list(range(2026100401, 2026100421))
TARGETS = [[-1120, 0], [1120, 0], [0, -680], [0, 680]]
KINDS = {'SCRAPPER', 'BRUISER', 'DASHER', 'SPITTER', 'MARKSMAN', 'LOBBER', 'OVERSEER', 'BOSS'}

def require(condition):
    # Verification is not a debug assertion: python -O must never disable it.
    if not condition:
        raise ValueError('runtime evidence contract failed')

def geometry_signature(descriptors):
    return json.dumps(sorted((d['kind'],d['rect']) for d in descriptors), sort_keys=True)

def circle_clear(point, radius, rects):
    if not all(math.isfinite(v) for v in [*point, radius]) or radius <= 0:
        return False
    for x, y, w, h in rects:
        nearest = [min(max(point[0], x), x+w), min(max(point[1], y), y+h)]
        if math.dist(point, nearest) < radius - 1e-4:
            return False
    return True

def inside(point, radius, bounds):
    x, y, w, h = bounds
    return x+radius <= point[0] <= x+w-radius and y+radius <= point[1] <= y+h-radius

def check_map(data):
    errors = []
    try:
        rects = [d['rect'] for d in data['descriptors']]
        bounds, radius = data['world_bounds'], data['player_radius']
        require(bounds == [-1400, -900, 2800, 1800] and abs(radius-16.9) < 1e-5)
        require(9 <= len(rects) <= 13 and len(data['collision_rects']) == len(rects))
        require(all(len(r) == 4 and all(math.isfinite(v) for v in r) and r[2] > 0 and r[3] > 0 for r in [*rects,*data['collision_rects']]))
        require(all(abs(a-b) <= 1e-4 for actual, expected in zip(data['collision_rects'], rects) for a,b in zip(actual,expected)))
        rects = data['collision_rects'] # Subsequent checks use measured physics footprints.
        require(circle_clear([0,0], radius, rects))
        require(len(data['probes']) == len(rects))
        for i, probe in enumerate(data['probes']):
            require(probe['index'] == probe['collider_index'] == i)
            require(probe['start'] == probe['end'] and probe['motion'][0] > 0 and probe['motion'][1] == 0)
            require(0 < probe['travel'][0] < probe['motion'][0] and abs(probe['travel'][1]) < 1e-5)
            require(probe['start'][0] + probe['travel'][0] <= rects[i][0]-radius+0.01)
            require(circle_clear(probe['start'], radius, rects))
        require({row['kind'] for row in data['spawns']} == KINDS)
        require(len(data['spawns']) == 8)
        for row in data['spawns']:
            require(row['nav_shared'] and circle_clear(row['position'], row['radius'], rects))
            require(inside(row['position'], row['radius'], bounds))
        require(data['portal_player_start'] == [0,0] and len(data['portals']) >= 3)
        for point in data['portals']:
            require(circle_clear(point, 48, rects) and inside(point, 48, bounds))
            require(math.dist(point, data['portal_player_start']) >= 260-1e-4)
        require(all(math.dist(a,b) >= 160-1e-4 for i,a in enumerate(data['portals']) for b in data['portals'][:i]))
        require(len(data['routes']) == 8 and 0 < data['move_speed'] <= 500)
        require(sum(len(route['rows']) for route in data['routes']) <= 12000)
        position, last_frame = [0, 0], -1
        for leg, route in enumerate(data['routes']):
            target = TARGETS[leg//2] if leg % 2 == 0 else [0, 0]
            require(math.dist(route['goal'], target) <= 48 and route['rows'])
            require(len(route['rows']) <= 3000)
            for row in route['rows']:
                require(math.dist(row['before'], position) < 1e-4)
                require(row['frame'] > last_frame and (last_frame < 0 or row['frame'] == last_frame+1))
                require(0 < row['delta'] <= 1/60+1e-5)
                require(math.dist(row['input'], row['actual_input']) < 1e-5)
                require(0 < math.hypot(*row['input']) <= 1.00001)
                require(math.dist(row['before'], row['after']) <= data['move_speed']*row['delta']+0.1)
                position, last_frame = row['after'], row['frame']
                require(circle_clear(position, radius, rects) and inside(position, radius, bounds))
            require(math.dist(position, route['goal']) <= 6)
    except (KeyError, TypeError, ValueError, AssertionError, IndexError):
        errors.append('missing/invalid runtime collision, spawn or continuous Input traversal evidence')
    return errors

def check_report(data):
    errors = []
    try:
        require(data['valid'] is True and data['rng_seeds'] == SEEDS)
        require(data['real_saves_before'] == data['real_saves_after'] and len(data['real_saves_before']) == 6)
        require(data['source_sha256'] == data['source_sha256_after'] and len(data['source_sha256']) >= 10)
        require(all(len(v) == 64 for v in data['source_sha256'].values()))
        require(data['orphan_after'] <= data['orphan_before'] and len(data['maps']) == 20)
        require([m['rng_seed'] for m in data['maps']] == SEEDS)
        require(len({m['map_seed'] for m in data['maps']}) == 20)
        require(len({geometry_signature(m['descriptors']) for m in data['maps']}) == 20)
        for m in data['maps']:
            errors.extend(f"map {m['rng_seed']}: {error}" for error in check_map(m))
    except (KeyError, TypeError, ValueError, AssertionError):
        errors.append('missing/invalid twenty-map, source or save isolation evidence')
    return errors

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('--require-native', action='store_true')
    args = parser.parse_args()
    data = json.loads(args.report.read_text(encoding='utf-8'))
    errors = check_report(data)
    root = Path(__file__).resolve().parents[2]
    for relative, digest in data.get('source_sha256', {}).items():
        path = (root/relative).resolve()
        if not path.is_relative_to(root) or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            errors.append('current source mismatch: ' + relative)
    if args.require_native:
        from PIL import Image
        if data.get('display') in [None, '', 'headless']:
            errors.append('not native rendering')
        for row in data.get('maps', []):
            frame = row.get('overview', {})
            path = (root/frame.get('path', '')).resolve()
            if not path.is_relative_to(root) or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != frame.get('sha256'):
                errors.append('missing/mismatched native overview')
                continue
            with Image.open(path) as image:
                if image.size != (1280, 720) or not any(a != b for a,b in image.convert('RGB').getextrema()):
                    errors.append('empty/wrong-sized native overview')
    print(json.dumps({'valid': not errors, 'errors': errors, 'maps': len(data.get('maps', [])),
                      'scope': 'isolated terrain runtime/Input and native overview, not twenty natural wins/performance/human acceptance'}))
    raise SystemExit(bool(errors))
