"""Synthetic unit records only, never runtime or a production save."""
import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'art'))
from check_late_crowd_report import check_observer,check_binding
import math

def fixture():
    rows = []
    history = []
    for i in range(50):
        bodies = [{'id':j+1,'kind':'LOBBER','radius':17,'health':10,
                   'position':[20+j*40,20], 'transform':[1,0,0,1,20+j*40,20],
                   'visible':True,'screen_rect':[3+j*40,3,34,34]} for j in range(3 if i >= 10 else 2)]
        rows.append({'index':i+1,'frame':100+i,'pre_frame':100+i,'pre_delta':1/60,'post_delta':1/60,
                     'wall':10+i/10,'state':'PLAYING','wave':4,'boss':False,'collection':False,'eligible':True,'segment':1,
                     'pre_position':[i,0],'position':[i+1,0],'input_pre':[1,0],'input_post':[1,0],
                     'walk_budget':1,'along_input':1,'low_progress':False,'low_streak':0,'callback_gap':0,'travelled':i+1,
                     'live':len(bodies),'visible':len(bodies),'kinds':{'LOBBER':len(bodies)},'bodies':bodies,
                     'canvas':[1,0,0,1,0,0],'health_loss':0,'shield_loss':0,'warnings':[],
                     'dash_requested':False,'dash_active':False,'dash_started':False})
        row = rows[-1]
        row.update(player_radius=13,terrain_gap=-13,
                   nearest_enemy_gap=min(math.dist(row['position'],b['position'])-30 for b in bodies))
        history.append({'frame':100+i,'wall':10+i/10,'observation':i+1,'segment':1,'process_frame':200+i})
    frames = [dict(h,path=f'build/diagnostics/natural-run/late-trial/peak-{i:03}.png',sha256=f'{i:064x}')
              for i,h in enumerate(history) if h['wall'] <= 14]
    return {'run':'trial','viewport':[1280,720],'display':'windows','adapter':'unit',
            'observations':rows,'peak':rows[10],'visible_peak':rows[10], 'frames':frames,'capture_history':history,
            'health_loss':0,'shield_loss':0,'loss_events':[], 'cache_limit':120,'max_retained':50,
            'bounds':[0,0,1280,720],'terrain':[]}

class LateCrowdReportTest(unittest.TestCase):
    def test_observer_must_match_actual_base_run_sampling(self):
        data = fixture()
        report = {'samples':[{'late_index':r['index'],'frame':r['frame'],'position':r['position'],
                             'actual_input':r['input_post']} for r in data['observations']]}
        self.assertEqual([],check_binding(data,report))
        for key,value in [('late_index',99),('frame',98),('position',[999,999]),('actual_input',[-1,0])]:
            bad = copy.deepcopy(report)
            bad['samples'][0][key] = value
            self.assertTrue(check_binding(data,bad),key)

    def test_base_cannot_omit_or_duplicate_observations(self):
        data = fixture()
        samples = [{'late_index':r['index'],'frame':r['frame'],'position':r['position'],
                    'actual_input':r['input_post']} for r in data['observations']]
        for sequence in [samples[:-1],samples[:4]+samples[5:],samples+[samples[-1]],list(reversed(samples))]:
            self.assertTrue(check_binding(data,{'samples':sequence}))

    def test_only_real_final_result_may_lack_base_sample(self):
        for terminal,health in [('death',0),('victory',90)]:
            data = fixture()
            samples = [{'late_index':r['index'],'frame':r['frame'],'position':r['position'],
                        'actual_input':r['input_post']} for r in data['observations'][:-1]]
            data['observations'][-1].update(state='RESULT',health=health)
            report = {'samples':samples,'terminal':terminal,'result':{'terminal':terminal,'health':health}}
            self.assertEqual([],check_binding(data,report),terminal)
            report['result']['health'] += 1
            self.assertTrue(check_binding(data,report))

    def test_wall_frame_segment_and_body_origin_are_reconstructible(self):
        for mutate in [lambda r:r.update(frame=100,pre_frame=100),lambda r:r.update(wall=9),
                       lambda r:r.update(segment=7),lambda r:r['bodies'][0].update(position=[999,999]),
                       lambda r:r['bodies'][0].update(health=float('nan'))]:
            data = fixture()
            mutate(data['observations'][1])
            self.assertTrue(check_observer(data,True))

    def test_clearance_and_lob_warnings_cannot_be_invented(self):
        for key,value in [('nearest_enemy_gap',999),('terrain_gap',999),('player_radius',0),
                          ('warnings',[{'id':1,'position':[0,0],'radius':72,'elapsed':1,'duration':.85}])]:
            data = fixture()
            data['observations'][0][key] = value
            self.assertTrue(check_observer(data,True),key)

    def test_positive_and_earliest_tie(self):
        data = fixture()
        self.assertEqual([],check_observer(data,True))
        data['peak'] = data['observations'][11]
        self.assertTrue(check_observer(data,True))

    def test_wrong_phase_is_not_late(self):
        for key,value in [('wave',1),('state','SETTLEMENT'),('boss',True),('collection',True)]:
            data = fixture()
            data['observations'][0][key] = value
            self.assertTrue(check_observer(data,True),key)

    def test_actual_body_records_cannot_be_dead_duplicate_or_miscounted(self):
        for mutate in [lambda r:r.update(live=40), lambda r:r['bodies'][0].update(health=0),
                       lambda r:r['bodies'][1].update(id=1),lambda r:r.update(visible=0),
                       lambda r:r['bodies'][0].update(screen_rect=[0,0,1,1])]:
            data = fixture()
            mutate(data['observations'][0])
            self.assertTrue(check_observer(data,True))

    def test_pre_post_input_frame_path_and_low_progress(self):
        for key,value in [('input_post',[-1,0]),('input_pre',[1]),('pre_frame',99),
                          ('travelled',999),('along_input',0),('low_progress',True)]:
            data = fixture()
            data['observations'][0][key] = value
            self.assertTrue(check_observer(data,True),key)

    def test_health_loss_cannot_disappear_between_samples(self):
        data = fixture()
        data['loss_events'] = [{'kind':'health','previous':100,'current':90,'loss':10,
                                'state':'PLAYING','wall':10.05,'frame':101,'player_id':1}]
        self.assertTrue(check_observer(data,True))
        data['health_loss'] = 10
        for row in data['observations'][1:]:
            row['health_loss'] = 10
        self.assertEqual([],check_observer(data,True))

    def test_window_cannot_be_empty_missing_or_out_of_segment(self):
        for action in [lambda d:d.update(frames=[]),lambda d:d['frames'].pop(3),
                       lambda d:d['frames'][0].update(segment=2),lambda d:d.update(max_retained=121)]:
            data = fixture()
            action(data)
            self.assertTrue(check_observer(data,True))

if __name__ == '__main__':
    unittest.main()
