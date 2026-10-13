# F3统一输入有限实际矩阵

2026-10-12，三个案例均来自实际空独立存档、正常Main主按钮、普通生产角色战斗、拾取与实际奖励卡点击；正常击败首领保存。没有属性/金币/模块/伤害/Boss死亡注入。GPU为RTX5060Laptop/OpenGL591.91、1280×720 SubViewport；是可靠引擎指针驾驶，不是桌面Window鼠标或真人试玩。

三者使用相同1668条源银行和同一当前主武器解算输入：普通弹继承速度1.0、榴弹0.30/基础0.48，源结束逐SHA核对无差异。只设菜单启动前的全局RNG，实际地图seed和动态报价另记；不同报价不能假作同一构筑。

| 实际案例 | 地图seed | 路线/进化 | 付费次数 | Boss战wall秒 | 终态HP/检查 |
|---|---:|---|---:|---:|---|
| f3_fire_uniform_20261012_v1 | 481615574 | 供给/榴弹协议 | 0 | 116.6 | 100/18285 |
| f3_mobility_uniform_20261012_v1 | 503484326 | 风险/顶级刺客 | 2 | 94.7 | 100/19421 |
| f3_replay_20261012_v2 父局 | 3591031700 | 风险/雷网矩阵 | 1 | 30.1 | 100/11047含重玩 |

三次真实引擎和严格外层exit0、唯一正数PASS、无错误或泄漏；断言属于各自scope，不能求和冒充full。此前真实败局保留而不改成通过。自动驾驶高反应/提前量、不同地形/奖励及路线会影响压力与胜率，HP100不证明真人游戏已经平衡。

## 火力

8608移动、863发/292榴弹/271爆炸、59正常击杀，鼠标误差0。free damage→free bullet_speed→free orbital_storm，未付费；供给金币56→68。Boss10800→8082.4892→5117.9320→2400.4212→真正CLEARED。首120爆炸样本有117个处于Boss体积+爆炸半径附近，仅为几何而非独立伤害归因。不能再将旧Window每分钟极低掉血说成正式榴弹一直不命中。

19图/报告/真实campaign/日志22份SHA一致保存到[火力终态](art/previews/campaign/chapter-growth-v1/fire-uniform-cleared/)，实际本主查看015战斗与018已保存图，不称全19图实看。

## 机动

8515移动、2161发/无榴弹、102正常击杀、鼠标误差0。free mine→free dash_cooldown→实付spike_density63→4币→风险第三次free dash_cooldown→35币后finale free rift_overdrive91币→实付spike_density91→11币。extra遭遇、真实消费、家族只由免费卡升级、finale新交易均正常经过。

Bossstep2908/10800→3600/9700→5400/6260→7200/2720→8590真正CLEARED，正常第1关保存/解锁2。22图/报告/真实campaign/日志25份SHA一致保存到[机动终态](art/previews/campaign/chapter-growth-v1/mobility-uniform-cleared/)，本主实际查看021已保存图。

## 工程与重玩

[真实重玩完整证明](campaign-replay-ordinary-proof-v1.md)含父局正常雷网进化/通关、新地图125271437、成长归零和永久存档SHA不变；682步真实首遭遇战斗/145发/16击杀，正常COLLECT。不是第二Boss胜利。

## 测后决定与下一步

当前已证明三系正式可达、三个不同地图、两种路线与通关后重玩。工程约30秒而其他两系约95–117秒有显著输出差距，火力此例没有付费而机动/工程有2/1次，尚不能把它归为单一伤害倍率错误。

源码另显示榴弹射速0.20×伤害3.0，在单目标/同等枪线/不考虑范围情况下仅为普通弹理论0.60输出；范围收益与额外目标不能当作已测Boss收益。这是原明确数值设计，不在未配对情况下静默改掉，也不把本公式当实际命中DPS。用户要求的30%速度继承、基础速度提高20%、雷网间隔+50%继续保留。

下一用同地图/同版本输入做火力风险23017与工程供给23019：记录实际地图/报价/支付、Boss输出和压力，区分奖励经济与流派；若仍稳定过长/必选，再以单独RED和真实重测作最小规则/数值变化。保留损坏档安全门和真实用户存档。F3整体仍未签收，不发阶段完成邮件，不提交/推送中间工作；F4黑边/死亡暂停/文字许可/性能及最终当前源full、独立候选、新六关链仍需继续。

当前额外7项同源回归：ChainEvidence197/ChainFile66/ChainFlow16/SharedChapter12/Context298/FinaleFlow108/FinaleUI33，共730检查，逐项actual0/唯一PASS/无错误泄漏；原输入/重玩8项233检查合计15项963，均按各自scope，不算全项目full。日志`*-replay-regression-v1.log`。实际ChainFlow验证不被post-clear默认hook影响，但不冒充新的完整普通六关链。

`f3_fire_risk_pair_20261012_v1`已真实空档开始（ballistics/risk/23017/current compensated），独占Godot串行，源冻结到实际退出；未终态，不宣布配对结果。

## 配对真实终态暴露碰撞失败

上述配对现已actualengine/严格外层exit1、valid=false。真实地图仍481615574与供给配对；真实Boss已击败并保存（step5951/HP40，99击杀），但第2遭遇出现两次`actual player penetrated terrain`，不能把后来真实胜利当验收GREEN。13484为执行检查数不是全部通过。1668条源终态逐SHA匹配后才解除freeze/编辑诊断。

free damage→free gun_lines→实付damage56→6币→风险第三次free gun_lines→35币后finale free orbital_storm93币→实付fire_rate93→22币。5863移动、1508实际射击；Bossstep2547→5951 wall约56.8秒（供给116.6秒），有实际追加枪线与付费，提示路线/构筑经济确实影响Boss输出；不是固定同构筑数值对照。工程供给配对暂缓，先定位碰撞失败，不在红灯上继续其他功能。

现有首次失败没有逐失败帧位置/速度，不能定性为容差误报或直接认定敌人推挤。新增仅诊断`body_clearance_witness`：最近实际圆-矩形/物理bounds有符号gap、障碍编号与rect；实际驾驶最多记录16次失败的step/physicsframe/位置before与after/velocity/dash/stealth/碰撞数量，原0.05px阈值完全不改，不移动或恢复Actor。纯几何先语义RED，后`ChapterTerrainWitnessTest21`、Hook6、Budget15共42actual0/唯一PASS/无错误泄漏；不是已修复真实碰撞或已复现原GPU错误。

下一真实physics最小复现优先审查普通dash结束停在贴墙敌实体重叠后，原生move_and_slide恢复是否进入地形；目前只是静态候选，未声称根因。需要实际RED→最小生产修复→专项与普通原地图复测，不能放宽clearance阈值掩盖。之前三系同版通关和实际重玩证据保留为对应源历史；F3整体仍不签收，F4/最终当前源full/PCK/新链亦保留。

## 最新：受控冲刺机制已复现并修复，自然复测进行中

[专项契约与证据](player-dash-body-recovery-v1.md)：真实最小物理RED复现普通冲刺结束敌体恢复推入墙；又以暂停恢复RED发现保护生命周期被清除。两步最小修复后30/60/120Hz六案例各355/625/1165 GREEN及10项11224相关回归通过。原0.05px阈值、普通碰撞层/掩码、速度/伤害不改。独立只读复核无新增Required/Critical，仍不等于完整暂停UI/原自然错误已关闭。

`f3_fire_risk_recovery_20261012_v1`已真实空档开始，ballistics/risk/23017/current compensated，串行GPU原种子复测，代码冻结至实际终态。失败帧观察新增dash/stealth pending及受限body-recovery trace，不移动Actor。原失败canonical保留；本次未退出前不写胜利，不继续工程配对或F4修改。

复测现在已严格exit0/唯一14265/无错误泄漏：同地图481615574、6298移动/1410射击/99击杀、terrain_witnesses0、Boss真通关存档HP96；1672源终态SHA完全一致。Boss67.55秒，free damage/gun_lines、paid damage、第三free fire_rate、free榴弹、paid pierce，不能与首败局不同报价做单因果比较。21图+报告+campaign+日志24SHA份canonical保留，原败局不动。下一`f3_engineering_supply_recovery_20261012_v1` automation/supply/23019/current compensated真空档运行，同版代码继续冻结，尚未终态。

## 工程供给配对终态与测后决定

`f3_engineering_supply_recovery_20261012_v1`实际exit0/唯一8547/无错误泄漏，地图3591031700，3722移动/909发/60击杀，witnesses0，HP100，Boss约31.89秒、正常保存第1关。free drone20币→free arc59币→paid drone_damage59→6→供给12币→free thunder_matrix18币。17图/报告/campaign/日志20SHA份保留至`engineering-supply-recovery-cleared/`。1672当前源逐SHA一致且与火力复测银行完全相同，真实引擎退出后解冻。

相同工程地图的历史风险案例约30.1秒、供给当前31.89秒；两者均有drone/arc/paid drone_damage/雷网，但风险额外遭遇获得的第三卡和金币不同，且历史源不同。不能冒充严格单变量实验。火力风险实跑约67.55秒且额外枪线/两次购买，供给历史116.6秒未购买；奖励经济确实重要，但不是纯数值因果证明。

本轮决定：不基于高反应自动驾驶、不同构筑和少量地图全面削弱工程/加速榴弹；继续保持用户已有30%速度继承、基础弹速+20%、雷网间隔+50%和明确旧倍率。已闭合“正式三系可达/两路线/多地图/真实重玩”和碰撞stop-line，可以进入F4视觉收尾；不宣称真人长期平衡已验证。F3整体最终签收与全项目full/PCK/新同源六关链仍留在最终门，不发阶段完成邮件、不中间Git。
