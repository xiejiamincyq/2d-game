# 普通冲刺与实体恢复：受控修复及原地图自然复测

2026-10-12；仅“5分钟超载”。不放宽原地形0.05px误差，不改变速度/伤害，不关闭正常实体碰撞，不用瞬移回滚。

## 实际发现

真实Player普通输入冲刺、真实Nursery墙与静止BRUISER碰撞体的受控测试，在从未隐身状态下复现：冲刺仅扫地形，可能结束于敌体重叠；下一原生move_and_slide的重叠恢复可把玩家推入墙，最深约11px。无敌体对照不穿墙。日志`player-dash-wall-candidate-60-v1.log`实际exit1/三失败案例。这证明一种真实机制，不直接证明原自然试玩两帧的所有原因。

## 最小生产变化

普通冲刺结束设置dash_recovery_pending，复用已有启用碰撞体的StealthRecoveryMotion地形约束恢复；实体重叠和恢复窗口真正清除后才回归原生运动。正式恢复输入guard若取消活跃冲刺，必须先pending OR dash_active；已完成但仍待恢复也不清除。新入场仍按新生命周期清理。

首轮修复又被暂停恢复测试击穿：`player-dash-wall-resume-red-60-v1.log`实际exit1/两失败案例。生命周期修复后，30/60/120Hz各六案例与真实沿墙逃离检查通过，355/625/1165断言，actual0/唯一正数PASS/无错误或泄漏。日志`player-dash-wall-resume-green-{30,60,120}-v2.log`。30Hz冲刺接墙和自然结束同回调，测试中途取消改在仍活跃、真实敌体重叠且距墙<10px时调用正式Player guard，并立即检查pending，未改生产冲刺计时。

独立只读复核未发现新增Required/Critical；这些是正式Player入口受控物理证据，仍不是完整章节暂停UI验收。

## 回归与边界

Dash215、Movement26、ChapterReplayGuard16、TerrainWitness21、Phase19 25、Phase20 17、StealthRecovery8388、SideEffect1204、Accounting1214、Query98，共10项11224相关断言。实际各exit0/唯一PASS/无错误或泄漏；不是full。Query标记另含hz/cases，首个外层过严尾锚未识别，原引擎为0且实际标记98，不重新跑不改结果。

Movement强行fixed-fps60曾报4个音频WAV/playback泄漏，verbose确认音频退出资源；使用正式测试器真实节拍max-fps120后actual0且无泄漏。失败日志保留，未为“绿灯”移除错误检测，也未更改生产音频。

三Hz测试注册正式run_tests；PowerShell解析、git diff --check和Godot资源导入actual0通过。原失败种子23017、ballistics/risk、当前普通鼠标提前量输入的真实GPU复测`f3_fire_risk_recovery_20261012_v1`正在进行，冻结生产与诊断代码直到退出。不得提前称修复原试玩已验收；F3/F4/最终full、独立候选和新六关链未完成，不做中间Git或阶段完成邮件。

## 原失败地图实际终态

复测现已actualengine/严格外层exit0、唯一VerifyChapterBuildRun14265、无错误泄漏。实际地图仍481615574，6298真实移动/1410射击/360榴弹/317爆炸/99击杀，鼠标误差0、terrain_witnesses0，Boss真击败并保存第1关/解锁第2关，HP96，Boss约67.55秒。不是改容差后略过报警。

真实free damage→free gun_lines→paid damage56→6→第三遭遇free fire_rate→风险35币→free orbital_storm93币→paid pierce93→9。报价与首个失败案例不完全相同，故不把两局耗时/HP差异全归于碰撞修复。

1672条当前源终态逐SHA全部相等后才解除freeze。21图/报告/真实campaign/日志24份SHA一致保留在`docs/art/previews/campaign/chapter-growth-v1/fire-risk-recovery-cleared/`，另有manifest；旧失败未覆盖。原案例这次已通过，不推论所有地图/真人体验/完整暂停UI均验收。工程供给路线进入下一实际配对；整个F3仍未签收。
