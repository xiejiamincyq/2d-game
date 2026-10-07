import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'art'))
import check_natural_render as checker


def manifest():
    run = 'collection-fixture'
    frames = []
    for i in range(61):
        remaining = max(0.0, 3.0 - i * .05)
        frames.append({'wall': 1.0 + i * .05, 'frame': 60 + 3*i, 'process_frame': 60 + 3*i,
                       'remaining': remaining, 'bar_value': remaining, 'bar_max': 3.0,
                       'label': f'倒计时：{remaining:.1f}s', 'visible': i < 60,
                       'alpha': min(1.0, remaining / .35), 'state': 'PLAYING' if i < 60 else 'WAVE_CLEAR',
                       'rect': [450, 600, 380, 58], 'overdrive_visible': True,
                       'overdrive_rect': [460, 662, 360, 40],
                       'path': f'build/diagnostics/natural-run/captures-{run}/collection-{i:03}.png',
                       'sha256': ('a' if i%2 else 'b') * 64})
    return {'run':run, 'collection':{'start':{'wall':1.0,'duration':3.0,'wave':1},
                                   'end':{'wall':4.0,'remaining':0.0,'wave':1},
                                   'complete':True,'frames':frames}}


class CollectionCaptureTests(unittest.TestCase):
    def check(self, data):
        self.assertTrue(hasattr(checker, 'check_collection_metadata'), 'old six-scene checker has no complete-window contract')
        return checker.check_collection_metadata(data)

    def test_complete_real_window_metadata(self):
        self.assertEqual(self.check(manifest()), [])

    def test_rejects_short_old_quota_and_missing_end(self):
        data = manifest()
        data['collection']['frames'] = data['collection']['frames'][:30]
        self.assertTrue(self.check(data))
        data = manifest()
        data['collection']['end'] = {}
        self.assertTrue(self.check(data))

    def test_rejects_missing_first_second_and_hidden_tail(self):
        data = manifest()
        data['collection']['frames'] = data['collection']['frames'][20:]
        self.assertTrue(self.check(data))
        data = manifest()
        data['collection']['frames'][-1]['visible'] = True
        self.assertTrue(self.check(data))

    def test_rejects_wrong_duration_and_nonfinite_time(self):
        data = manifest()
        data['collection']['start']['duration'] = 1.9
        self.assertTrue(self.check(data))
        data = manifest()
        data['collection']['frames'][2]['wall'] = float('nan')
        self.assertTrue(self.check(data))

    def test_rejects_counter_or_ui_divergence(self):
        for field, value in [('remaining', 3.1), ('bar_value', .1), ('bar_max', 5.0), ('label','倒计时：5.0s'), ('alpha', .2)]:
            data = manifest()
            data['collection']['frames'][3][field] = value
            self.assertTrue(self.check(data), field)

    def test_rejects_bad_cadence_state_path_and_overlap(self):
        for field, value in [('process_frame', 60), ('wall', 1.5), ('state','PAUSED'), ('path','../other.png'), ('rect',[450,660,380,58])]:
            data = manifest()
            data['collection']['frames'][3][field] = value
            self.assertTrue(self.check(data), field)

    def test_rejects_repeated_or_too_close_physics_frames(self):
        data = manifest()
        for row in data['collection']['frames']:
            row['frame'] = 60
        self.assertTrue(self.check(data))
        for delta in (1, 2):
            data = manifest()
            data['collection']['frames'][3]['frame'] = data['collection']['frames'][2]['frame'] + delta
            self.assertTrue(self.check(data))

    def test_rejects_invalid_frame_numbers_and_rectangles(self):
        for field in ('frame', 'process_frame'):
            for value in (float('nan'), -1, 1.5):
                data = manifest()
                data['collection']['frames'][3][field] = value
                self.assertTrue(self.check(data))
        for field in ('rect', 'overdrive_rect'):
            for value in ([450,600,0,58], [450,600,-10,58], [450,600,380,float('nan')]):
                data = manifest()
                data['collection']['frames'][3][field] = value
                self.assertTrue(self.check(data))

    def test_hidden_tail_can_share_last_physics_frame(self):
        data = manifest()
        data['collection']['frames'][-1]['frame'] = data['collection']['frames'][-2]['frame']
        self.assertEqual(self.check(data), [])

    def test_rejects_wrong_lifecycle_and_early_hidden_tail(self):
        data = manifest()
        for row in data['collection']['frames'][:-1]:
            row['state'] = 'WAVE_CLEAR'
        self.assertTrue(self.check(data))
        data = manifest()
        data['collection']['frames'][-1]['state'] = 'PLAYING'
        self.assertTrue(self.check(data))
        data = manifest()
        row = data['collection']['frames'][-2]
        row.update(remaining=0.0, bar_value=0.0, label='倒计时：0.0s', alpha=0.0,
                   visible=False, state='WAVE_CLEAR')
        self.assertTrue(self.check(data))

    def test_accepts_real_range_step_and_hidden_layout(self):
        data = manifest()
        row = data['collection']['frames'][1]
        row.update(remaining=2.9658347, bar_value=2.97, label='倒计时：3.0s')
        data['collection']['frames'][-1]['rect'] = [450,658,380,60]
        self.assertEqual(self.check(data), [])

    def test_rejects_wrong_quantized_value_and_visible_bottom_margin(self):
        data = manifest()
        row = data['collection']['frames'][1]
        row.update(remaining=2.9658347, bar_value=2.96, label='倒计时：3.0s')
        self.assertTrue(self.check(data))
        data = manifest()
        data['collection']['frames'][1]['rect'] = [450,658,380,60]
        self.assertTrue(self.check(data))


if __name__ == '__main__':
    unittest.main()
