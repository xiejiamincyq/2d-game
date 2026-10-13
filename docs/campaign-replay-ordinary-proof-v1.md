# F3真实已通关重玩验证

2026-10-12，F3仍进行中，整个goal未完成。不是通过写存档/调用场景切换模拟重玩：`VerifyChapterReplayRun`继承普通构筑驾驶，空独立存档、实际Main主入口、正常战斗/拾取/UI奖励、真实Boss死亡保存后，才点击实际“重新探索”。

## 验证边界

- 基础驾驶新增默认true的awaitable `after_ordinary_clear`，只在前置保存通关与额外构筑检查无失败时调用；旧chain仍走自身Return路径。
- 钩子先记录真实Boss实例、旧地图、真实保存state/SHA，再等待实际Replay按钮创建另一Chapter实例。检查新地图种子与真实障碍描述改变，金币/家族等级/模块/进化/击杀均从新局开始；永久第1关通关与第2关解锁及保存字节不变。
- 新局最多900个普通第一遭遇驾驶步骤，记录实际`combat_steps`、移动、射击、真实击杀、HP与终态。不是第二次Boss胜利、完整六关链、桌面Window鼠标或真人接受度。
- hook完成后才重算最终valid/assertions并写report；退出成功时关闭实际live Chapter，避免引用已释放旧关卡。

## 首次失败与输入握手

`f3_replay_20261012_v1`真实engine exit1，报告valid=false。父局真实工程进化/击败Boss/保存，新地图3591031700→2686001902，永久保存SHA`17ba485d28713bb545b18dc7eac46cc31565339f78eae139f81848cc7585d81b`不变；新成长全部回到初始。但新局实际仅23移动帧、67发、8击杀，HP0/FAILED，拒绝整个重玩验收。终态后1664条源SHA全部匹配，之后才修诊断；原失败不覆盖。

原因定位在驾驶输入顺序而不是修改角色：Player入场期间提前return；Chapter Proceed再次启动出生输入保护，只有实际物理帧读到零方向且未按dash才解除。原base有首轮中立输入，Replay短循环没有保证此帧，持续按方向可一直被保护过滤但仍开火。独立只读审查亦确认此控制流。

新增`resume_ordinary_input`，真实release按键并await physics/process后再驾驶，明确读出生guardfalse。`ChapterReplayGuardTest`先语义RED要求握手，GREEN通过实际Main/Player：Proceed前真实按方向保证guard保持，握手后12帧正常移动/射击。未写Player状态/HP/存档。

另修正诊断失败清理：真实chain返回Main后，Main属性为`combat_feedback`且cover时可能null，不是Chapter的`feedback`。新`shutdown_failed_scene`按场景能力读属性/null安全，外层始终quit1；`ChapterFailureCleanupTest`真实Main cover检查，不把失败改成exit0。

## 当前相关验证

实际引擎0、唯一PASS且无错误/泄漏：Guard16、FailureCleanup5、PostClearHook6、RewardBudget15、BuildPointer146、BuildAim7、ProjectileAim28、BuildChoice10，共233检查。日志位于`build/diagnostics/campaign-goal/`：Guard为`ChapterReplayGuardTest-replay-green-v2.log`，其余7项为`*-replay-green-v3.log`。hook/guard/cleanup语义RED及初期解析/夹具预期错误日志均保留，不混为GREEN。

UID导入`chapter-replay-import-v2.log`真实0，无错误；runner PowerShell实际解析通过。新增三项已注册，Guard长测试1800帧/120fps预算。上述不代替最终当前源full、独立候选与六关新档链。

## 修复后真实通关与重玩终态

`f3_replay_20261012_v2`重新从空存档实际开始，真实引擎及严格外层exit0、唯一`TEST PASS: VerifyChapterReplayRun 11047`、无错误或泄漏。父局地图3591031700，4091移动、1091射击、101正常击杀/HP100，实际工程进化：free drone→free arc→实付drone_damage（59→6币）→第三风险free drone_pierce→风险35金币后free thunder_matrix（96币）。Boss step2371→4177真正死亡保存，不把先前失败存档作为前置。

实际Replay按钮之后新地图125271437，真实障碍描述不同，新成长coins0/三家族均1/无模块无进化/未通关的新局；保存state仍`{"cleared_chapters":[1],"version":1}`，原永久保存SHA不变。中立输入握手后682个实际普通战斗步骤、682移动帧/145实际射击/16真实击杀，HP100，正常进入COLLECT，未继续到第二Boss。终态1668条源逐SHA一致。实际本主查看Replay intro/combat两图，不宣称其他图全查。

22张图/报告/真实campaign/日志共25份相同SHA保留到[成功重玩证据](art/previews/campaign/chapter-growth-v1/replay-cleared/)。前失败25份单独保留到[失败证据](art/previews/campaign/chapter-growth-v1/replay-input-failed/)，不覆盖、篡改valid或混成通过。独立只读复审两项Required均已消除，未新增Required；审查没有执行引擎。

当前重玩证明闭合，不等于整个F3。接着`f3_fire_uniform_20261012_v1`真实空档火力供给/23017/当前compensated启动，同一生产与统一普通弹/榴弹输入。结束前源冻结、未声称通关；之后仍需机动、有限不同种子/路线比较与测后平衡决策。未中间提交/推送/发阶段完成邮件。

## 统一当前输入：火力供给终态

上述火力复查现已actualengine/严格外层exit0，唯一`TEST PASS: VerifyChapterBuildRun 18285`，无错误/泄漏。1668条源终态全部SHA匹配，与Replay v2相同银行。实际地图481615574，8608移动、863实际射击、59真实击杀，HP100；其中292榴弹/271爆炸，实际鼠标误差最大0。free damage（22币）→free bullet_speed（56币）→供给12币后free orbital_storm（68币），没有测试注入付费或金币。

真实Boss step1682/10800→3600/8082.4892→5400/5117.9320→7200/2400.4212→8679真正通关保存，wall约116.6秒Boss战。正式首领前进化/保存均可达；它与工程风险约30.1秒有显著差别，但路线、地图与报价不同，不能声称单变量强弱对照。该证据不替代真人手感或最终多流派平衡。当前`f3_mobility_uniform_20261012_v1`真实空档机动风险/23018已开始，源冻结到终态；尚未签收F3。
