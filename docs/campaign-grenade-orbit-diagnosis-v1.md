# F3榴弹普通运行：低命中率待区分

2026-10-12，诊断中，不是修复/验收，不改变用户指定的速度公式，不降低Boss生命来制造通过。

## 已见的实际现象

`f3_fire_supply_20261012_v1`从实际Main主按钮/空档开始，普通战斗、拾取、两次火力免费奖励、供给之后，在真实首领前奖励选择榴弹。当前进化可达，不代表整个构筑有良好手感。

运行中实际查看：`frame_015.png`首领整备显示火力3级、金币68、免费榴弹；`frame_017.png`选择后火力4级/进入真实Boss准备；`frame_020.png`实际战斗时间03:28，Boss10595/10800；`frame_022.png`04:28，Boss10348/10800。因此这一个60秒窗口只减少247血。完整终态尚未取得前，不把这些帧作为普通通关证明，也不当成所有火力构筑的平衡结论。

已取得最终真实终态：引擎及外层实际exit1，无PASS；30,000步上限后未击败Boss、未保存通关，报告valid=false。30,161是已执行检查数，不是通过断言数。实际移动29,933帧、射击2,977次、44正常敌人击杀、HP100；最后采样step28,800仍Boss9358.89579/10800。初始RNG23017对应实际地图481615574，完整1650条源银行在结束后逐一仍一致。真实免费选择依次bullet_speed（22金币未花）→damage（56金币未花）→orbital_storm（供给后68金币未花）；第三笔是实际2遭遇后的新transaction3，资格/真实Player进化成功，但普通胜利失败。不是脚本解析错误、模型补血、用户存档异常或被提前强杀。

30图/报告/原失败日志共32份已按相同SHA保留到[未补偿火力失败证据](art/previews/campaign/chapter-growth-v1/fire-direct-failed/)，退出观察单独记录于其delivery-sha256.json；不修改失败valid、不删TEST FAIL，不混进GREEN计数。源冻结解除后的驾驶改动会让此银行成为历史，不再宣称与后续同源。

## 已查源码与假设

Player仍按用户要求：`grenade.velocity = velocity * 0.30 + direction * projectile_speed * 0.48`，48%是原40%提高20%；没有全速继承。射速乘0.20、榴弹伤害乘3.0均原有机制，不在此次成长改动改变。GrenadeProjectile真敌群provider含Boss，44近敌半径触发、82爆炸半径+目标体积伤害；实际Boss加入active_enemies，不是目标名单漏Boss。

普通驾驶继承的瞄准只指向敌人当前中心，同时绕圈横移；没有根据飞行时间、目标运动和继承玩家的横向速度作瞄准补偿。30%继承仍会在较慢榴弹飞行时间里形成横向偏移。当前假设是驾驶策略和武器弹道互动导致大量未命中，而不是已证明武器伤害本身错误。需要真正新独立试验区分，不能在运行途中改驾驶源码破坏同源证据。

## 独立诊断改动与当前运行

已在诊断层完成两项，不改正式武器、Boss、奖励或存档：

- `DiagnosticProjectileAim` 解 `|相对位置 + (目标速度 - 玩家速度×0.30)t| = 基础弹速×t`，取6秒寿命内最早正根；不可达/非有限/零速使用有限的直接瞄准。22项真实GREEN，先保留可编译语义RED；最初测试类型推断编译错误也保留，不计RED证明。
- 普通驾驶增加默认不变的世界瞄准钩子，构筑驾驶只有显式`compensated`且真实Player已有榴弹时才补偿鼠标位置。只读当前枪口，不调用会改姿态的`prepare_shot`。实际鼠标仍经原视口转换/边缘限幅；每帧速度与后续姿态可能变化，因此纯数学命中不能替代实际战斗。6项集成夹具检查直接模式、补偿方向、不改actor、未进化/无目标回退。
- 连续REWARD的新transaction现在单独重置诊断选择预算；同一transaction保留免费加付费共3次约定。独立代理只写测试，本主实际运行缺API语义RED再修复、15项GREEN。最初代理静态Script调用的编译错误保留并修正，不算有效语义RED。

五项当前相关回归`ChapterBuildAimTest 6 / ChapterBuildChoiceTest 10 / ChapterRewardBudgetTest 15 / DiagnosticProjectileAimTest 22 / NativeChapterPilotThreatTest 8`共61检查，逐项引擎实际0、唯一PASS、无错误或泄漏。runner注册新增3项，实际导入0和PowerShell解析通过。前一轮完整16项成长结果仍是对应版本证据，不冒充此后全项目full。

新实际GPU运行`f3_fire_compensated_20261012_v1`，参数`ballistics supply 23017 compensated`，日志`f3-fire-compensated-ordinary-v1.log`。尚未取得终态前不声明改善/通关；源冻结直到实际退出，另外模型只读审查诊断代码。原始未补偿失败32份继续保留。两次运行初始RNG相同不自动保证所有地图/动态奖励完全一致，最终比较必须读实际地图seed与全部报价。

上述补偿Window运行现已实际终态exit1/valid=false，仍为30,000步内未通关的两项失败，无解析/运行错误或泄漏；30,163是执行检查不是通过数。29,923移动、2,536射击、50正常击杀、HP24；最后采样Boss7300.17549。实际地图仍481615574，与旧失败同地图，但第二结算另实付fire_rate使56币→3币，免费榴弹后15币，因此不把伤害变化当单一补偿变量。1658条源银行结束逐一匹配，30图/报告/失败日志共32份原SHA保存到[补偿Window失败证据](art/previews/campaign/chapter-growth-v1/fire-compensated-window-failed/)。原始valid/日志不改。

独立只读审查已完成：未发现Required缺陷，明确两个Optional限制。实际发射先执行新移动速度再重采样枪口，读取旧帧解算可能残留误差；像235速90°转向，继承项可相差约99.7像素/秒。补偿解经原屏幕限幅后也可能改变射线，`compensated_frames`只证明尝试，不是实际命中数。固定枪口夹具不覆盖这些变化，不能把61项GREEN当实际命中率。若终态仍过慢，下轮只读`fired`/爆炸观测量化实际起点、速度、目标与限幅，不在冻结中改源码。审查未运行引擎或改文件。

### 实际输入链路问题与独立视口验证

本主查看新Window运行017/019/029；独立审查实际看017/018/019/020/021/023六图。019玩家朝左、近枪口榴弹向左而Boss在右下，021Boss在上方仍朝左；不能解释为只随移动转身体，因为真实Player每物理帧用实际鼠标更新gun_angle再选择四方向外观。系统焦点/跨帧鼠标覆盖或空间换算仍是候选，截图不是根因定论。[Godot官方Input.warp_mouse](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-warp-mouse)说明其相对于当前焦点游戏窗口；[Viewport.push_input](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-push-input)明确事件传播与视口坐标，这不足以独立证明跨帧实际读值正确。

构筑驾驶单独复用已有Foundry运行的SubViewport/同一GPU纹理显示方式，不修改正式Main默认Window。`ChapterBuildPointerTest`先实际语义RED拒绝Window依赖；修复后122检查跨48个真实physics/process帧，四方向实际子弹读同一鼠标空间。再先RED要求只读shot观测，补齐后最终146项headless及实际RTX5060 OpenGL均实际0/唯一PASS/无错误泄漏。早期测试通过`_leave(...true)`触发引擎提前退出、没有PASS的日志单独保留，不能算通过，之后用正确夹具清理取得终态。

当前5项相关`Pointer146 / Aim6 / Choice10 / Budget15 / ProjectileAim22`合计199检查逐项实际0；旧Hosting9/Threat8对应上一步未受相关修改的回归记录。新shot观测只订阅正式fired/exploded，最多30普通射击与120榴弹/爆炸样本，记录真实指针、速度、枪口、朝向、Boss位置/血量，每实际射击核对指针一致；不改变Actor/Projectile/敌人或奖励。爆炸位置不是独立伤害归因。UID导入实际0，新pointer长测试注册1800帧。

当前新实际运行`f3_fire_viewport_20261012_v1`（`ballistics supply 23017 compensated`）尚未取得终态。源冻结到实际退出；它是正常Main/Chapter/Actor/physics与普通输入，但不是OS桌面鼠标或真人手感证明。不能在终态前宣称通关或F3闭合。

### 已取得独立视口火力败局终态

现已真实terminal exit1/valid=false，step6791玩家死亡，不是步数耗尽或提前结束。Boss从step2602/10800到step3600/8970.9062、step5400/4434.7536、最终886.3116；约69.8秒真实Boss战造成9913.6884血量下降，不能再沿用旧Window每60秒247掉血判断火力强度。正常HP100→40→0，58正常击杀、6698移动、1018实际射击，其中362真实榴弹、340爆炸；每实际发射鼠标误差最大0，150射击与120爆炸样本真实记录。程序两项失败是没有真实Boss胜利/没有保存通关；14660是执行检查数，不当作全部通过。

实际地图仍481615574，报价/取币不同：free pierce→free gun_lines→实付damage（56→6币）→供给后free orbital_storm（18币）。因此新运行是输入正常的火力组合案例，不是与其他窗口结果严格单变量对照，也不是所有火力组合或真人最终平衡结论。结束1660条源逐hash全部一致。18图/报告/实际失败日志共20份原SHA保存到[真实准心火力败局](art/previews/campaign/chapter-growth-v1/fire-viewport-defeated/)。不保存虚假通关、不改HP或Boss来变成胜局。

下一实际机动冒险运行`f3_mobility_risk_20261012_v1`已启动（`mobility risk 23018 compensated`）；实际未获得榴弹时补偿函数保持直接点，不改变机动武器。它将真实经历额外遭遇、风险结算与独立finale transaction，用普通UI取模块、原源同版输入检查。未终态，不宣布资格/胜利；F3仍不闭合。

### 机动冒险终态与统一主武器诊断策略

机动运行现已actualexit1/valid=false，step10697正常死亡、94击杀、10597移动、2617射击，Boss3757.0301，最大真实指针误差0。地图503484326，不与火力同地图假配对。实际免费mine→dash_impact→第三风险免费dash_impact并实付spike_density（115→35币）→风险奖励35币之后新transaction4免费rift_overdrive（70币）；正常取得真实Player机动进化。额外遭遇、实际付款与REWARD→REWARD预算均真实经过。1660源结束逐项一致后才继续编辑；23图/报告/失败日志共25份相同SHA保留到[机动冒险败局](art/previews/campaign/chapter-growth-v1/mobility-risk-defeated/)。三次受击60/60/余量致死，期间两次正常心形拾取各20回血，未测试补血或存档注入。

上述机动版本使用了当时“仅榴弹补偿”的策略，普通子弹仍直接指向目标。源码明确普通弹继承完整玩家速度，此时绕圈输入的偏差会不公平地影响机动/工程比较。因此诊断策略单独升级为同样读取真实武器的运动内核：普通弹`玩家速度×1.0 + 基础弹速`；真实榴弹保留`玩家速度×0.30 + 基础弹速×0.48`。没有改这两个正式公式或任何数值，只修改显式compensated模式的鼠标提前量；direct仍原样。旧机动结果是诚实的真实案例，不冒充新版统一瞄准策略对比。

先实际语义RED显示普通弹横移下未补偿，之后7项Hook/28项运动/10选择/15预算/146跨帧真实发射，共当前206项GREEN，逐项实际0、唯一PASS、无错误泄漏；更新后实际GPU Pointer146也通过（`chapter-build-pointer-all-primary-gpu-v1.log`）。[独立诊断日志交付](art/previews/campaign/chapter-growth-v1/diagnostic-input-v1/)含当时五个GREEN、旧GPU与五个语义RED共11个原SHA日志；最新GPU原日志仍位于build，不能混称该11份含更新后GPU。数学测试包含普通弹全继承与原榴弹30%两种轨迹。长期goal未完整验证，未邮件/提交/推送。

当前工程冒险`f3_automation_risk_20261012_v1`（`automation risk 23019 compensated`）已启动统一普通弹/榴弹策略，来源同版冻结；未终态，不声明进化/通关。后续仍需合理种子/供给风险差异、真实已通关重玩和最终当前源联合验证。

### 工程冒险真正通关

现已真实terminal引擎/严格外层exit0、唯一`TEST PASS: VerifyChapterBuildRun 10044`、无错误/泄漏。真实空档Main、三次遭遇、风险35金币/第三次真实购买与新首领前transaction4，free drone→free arc→free arc_capacitor→实付arc（114→19币）→free thunder_matrix（54币）；真实Player无人机1、电弧2、电容1和雷网进化。实际地图3591031700。4339移动、1148射击、101正常击杀，HP96；曾正常100→76后拾取心形→96，并非测试补血。所有实际发射准心最大误差0。1660源终态逐SHA全部相同。

Boss真实step2540/10800→3600/5026.5055→4413真实CLEARED，约31.2秒Boss战，独立`campaign.json`实际`{"cleared_chapters":[1],"version":1}`，正常第2关解锁。它不是六关链或真人平衡证明；不是用日志PASS替代游戏内部保存检查。20图/报告/真实campaign/日志共23份按原SHA保留到[工程冒险通关](art/previews/campaign/chapter-growth-v1/automation-risk-cleared/)。本主实际查看016首领说明、018实际战斗、019真实已保存/解锁提示，不宣称20图全看过。

当前三系均有正常取进化证据，但只有工程此例胜利；火力与机动败局保持。工程的31.2秒与火力69.8秒败局、机动124秒败局是不同地图/报价且普通弹补偿版本不同，不够直接下结论“工程必选”。下一应在统一当前输入策略复查多种子/相近路线与真正已通关重玩，再决定是否最小数值调整。真实基础伤害、榴弹30%/20%提速与雷网触发间隔×1.5规则本轮均未改变。F3仍未整体闭合、F4和最终同版full/独立候选/新档六关仍需做；无中间Git或邮件。

## 下一步

1. 保留当前运行完整退出/报告/截图，失败或超时也保留；记录每笔实际offer/价格/构筑和Boss血量时间序列。
2. 当前终态后，对驾驶瞄准作单独纯函数RED→GREEN：从可观察位置/速度和现有武器基础速度计算提前量/继承速度补偿，最终仍仅通过真实鼠标瞄准输入。不得改Player、Boss、伤害、金币或奖励。分别记录未经补偿与经补偿驾驶，不混成一次运行。
3. 新同源普通火力证据并对比机动/工程/风险/重玩；若合理瞄准下仍过长，再针对游戏机制/数值拟最小改动、RED与真实重新运行。自动驾驶补偿不证明真人手感已经好。
4. 全部生产代码变化后，最终当前源full/独立本地包/新档六关链仍必做；F3不提前闭合，整个goal active。
