from copy import deepcopy
from pathlib import Path
import sys
import subprocess
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'art'))
from check_arena_runtime_report import check_report, check_map, circle_clear, TARGETS, KINDS, SEEDS

def valid_map_fixture():
    # Synthetic unit data only, never presented as actual runtime evidence.
    rects = [[-1300, -700+i*50, 10, 10] for i in range(9)]
    data = {'world_bounds': [-1400,-900,2800,1800], 'player_radius': 16.9,
            'descriptors': [{'rect': r, 'kind': 'tank'} for r in rects], 'collision_rects': rects,
            'move_speed': 240, 'probes': [], 'spawns': [], 'portal_player_start':[0,0],
            'portals': [[500,0],[-500,0],[0,500]], 'routes': []}
    for i, r in enumerate(rects):
        data['probes'].append({'index':i, 'collider_index':i, 'start':[-1325,r[1]+5],
                              'end':[-1325,r[1]+5], 'motion':[100,0], 'travel':[8,0]})
    data['spawns'] = [{'kind':k, 'radius':14, 'position':[200,200], 'nav_shared':True} for k in KINDS]
    current, frame = [0,0], 0
    for target in TARGETS:
        for goal in [target,[0,0]]:
            rows = []
            while current != goal:
                before = current[:]
                direction = [0,0]
                for axis in range(2):
                    direction[axis] = (goal[axis]>current[axis])-(goal[axis]<current[axis])
                    current[axis] += direction[axis]*min(2,abs(goal[axis]-current[axis]))
                frame += 1
                rows.append({'before':before, 'after':current[:], 'frame':frame,
                             'input':direction, 'actual_input':direction, 'delta':1/60})
            data['routes'].append({'goal':goal, 'rows':rows})
    return data

def valid_report_fixture():
    maps = []
    base = valid_map_fixture()
    for i, seed in enumerate(SEEDS):
        row = deepcopy(base)
        row.update(rng_seed=seed, map_seed=i+100)
        row['collision_rects'] = deepcopy(row['collision_rects'])
        row['descriptors'][0]['rect'][0] += i*0.001
        row['collision_rects'][0][0] += i*0.001
        row['probes'][0]['start'][0] += i*0.001
        row['probes'][0]['end'][0] += i*0.001
        maps.append(row)
    return {'valid':True, 'maps':maps, 'rng_seeds':SEEDS, 'real_saves_before':dict.fromkeys(range(6),'absent'),
            'real_saves_after':dict.fromkeys(range(6),'absent'), 'source_sha256':dict.fromkeys(range(14),'a'*64),
            'source_sha256_after':dict.fromkeys(range(14),'a'*64), 'orphan_before':0, 'orphan_after':0}


class ArenaRuntimeReportTest(unittest.TestCase):
    def test_complete_runtime_fixture_accepted(self):
        self.assertEqual([], check_map(valid_map_fixture()))

    def test_complete_twenty_map_unit_fixture_accepted(self):
        self.assertEqual([], check_report(valid_report_fixture()))

    def test_zero_input_with_motion_rejected(self):
        data = valid_map_fixture()
        data['routes'][0]['rows'][0].update(input=[0,0],actual_input=[0,0])
        self.assertTrue(check_map(data))

    def test_portal_not_from_center_or_too_near_rejected(self):
        for key,value in [('portal_player_start',[800,0]),('portals',[[100,0],[-500,0],[0,500]]),
                          ('portals',[[500,0],[501,0],[0,500]])]:
            data = valid_map_fixture()
            data[key] = value
            self.assertTrue(check_map(data), (key,value))

    def test_reordered_identical_geometry_not_another_map(self):
        data = valid_report_fixture()
        duplicate = deepcopy(data['maps'][0])
        duplicate.update(rng_seed=SEEDS[1],map_seed=101)
        for section in ['descriptors','collision_rects','probes']:
            duplicate[section].reverse()
        for i,probe in enumerate(duplicate['probes']):
            probe.update(index=i,collider_index=i)
        data['maps'][1] = duplicate
        self.assertTrue(check_report(data))

    def test_invalid_report_rejected_even_under_python_optimization(self):
        script = "from check_arena_runtime_report import check_report; raise SystemExit(bool(check_report({'maps':[]})))"
        result = subprocess.run([sys.executable,'-O','-B','-c',script], cwd=Path(__file__).resolve().parents[1]/'art', capture_output=True)
        self.assertNotEqual(0,result.returncode)

    def test_transformed_float_collider_roundoff_but_not_shift_accepted(self):
        data = deepcopy(valid_map_fixture())
        data['collision_rects'] = deepcopy(data['collision_rects'])
        data['collision_rects'][0][1] += 3.0517578e-5
        self.assertEqual([], check_map(data))
        data['collision_rects'][0][1] += 0.01
        self.assertTrue(check_map(data))

    def test_missing_teleported_embedded_or_wrong_input_route_rejected(self):
        original = valid_map_fixture()
        for key, value in [('after', [-1300,-700]), ('before',[500,500]),
                           ('after',[-200,0]), ('actual_input',[0,1]), ('delta',1), ('frame',-1)]:
            data = deepcopy(original)
            data['routes'][0]['rows'][0][key] = value
            self.assertTrue(check_map(data), (key,value))
        for section in ['routes','probes','spawns','portals']:
            data = deepcopy(original)
            data[section] = []
            self.assertTrue(check_map(data), section)

    def test_circle_rectangle_contact_and_corner(self):
        self.assertFalse(circle_clear([5, 5], 1, [[0, 0, 10, 10]]))
        self.assertFalse(circle_clear([-0.5, 5], 1, [[0, 0, 10, 10]]))
        self.assertTrue(circle_clear([-1, -1], 1, [[0, 0, 10, 10]]))
        self.assertTrue(circle_clear([-1, 5], 1, [[0, 0, 10, 10]]))

    def test_descriptor_only_twenty_maps_rejected(self):
        data = {'valid': True, 'maps': [{'map_seed': i, 'descriptors': []} for i in range(20)]}
        self.assertTrue(check_report(data))

    def test_empty_duplicate_or_incomplete_report_rejected(self):
        for data in [{}, {'valid': True, 'maps': []}, {'valid': True, 'maps': [{}] * 20}]:
            self.assertTrue(check_report(data))

    def test_false_valid_and_changed_save_rejected(self):
        data = {'valid': False, 'real_saves_before': {'x': 'absent'}, 'real_saves_after': {'x': 'changed'}, 'maps': []}
        self.assertTrue(check_report(data))

    def test_penetration_tolerance_is_not_a_pixel_allowance(self):
        self.assertFalse(circle_clear([-0.99, 5], 1, [[0, 0, 10, 10]]))
        self.assertFalse(circle_clear([float('nan'), 5], 1, [[0, 0, 10, 10]]))


if __name__ == '__main__':
    unittest.main()
