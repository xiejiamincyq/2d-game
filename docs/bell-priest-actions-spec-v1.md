# E4 钟骨司祭：动作资源与待实施实战规格

2026-10-11 E5第五关阶段已完成，详见[真实通关及当前验收](art/echo-chapter-review-v1.md)：两条普通输入路线/新进程恢复、方向牌避开身体、281 Godot261848断言/36 Python272、独立PCK53专项32168+315资源检查/Main120/release通过，59源不变；新E5本地EXE用已验证同SHA PCK启动120帧退出0。Ready1–5，第六禁入；资源draft/整体goal active，未中间提交/推送/发布。下一第六关阶梯设备岛与独立机关/Boss。下方E4b及更早为历史快照。

2026-10-11 E4b战斗阶段完成：[最新实际骨骼战斗审查](art/bell-priest-combat-review-v1.md)。取消重入233、Actor GPU518（36关键/180连续/六小尺度）、地图HUD127及20/42源SHA/23交付文件通过；最终全量v2退出0、277 Godot259296断言/36 Python272测试。独立同PCK49专项29615+315资源检查/Main120/release通过，6814400字节，51规范夹具与52日志核对。最终全量v1缺UID失败保留，正常导入修复，不删原规则。Main[1,2,3,4]；E5真实首领接线已语义RED但未实现/绿色，正式入口/正常通关/解锁6仍待做。draft/整体active，无中间提交/推送/发布，旧名册/v1/候选保留；阶段邮件记录见审查。以下旧全量数字及E4a“无Actor”为历史版本。

2026-10-11，整体goal active。E3已完成；E4a独立v2资源、Motion契约与GPU专项、最终264 Godot/36 Python以及独立PCK/release已通过，详见[资源审查](art/bell-priest-actions-review-v1.md)。E4b实际Actor/导演与三招已经实现、13专项普通物理与所有权已通过，详见[当前实战进展](bell-priest-combat-progress-v1.md)；实际GPU/HUD/同源/全量/当前独立PCK与release终态仍待验收，E4b不勾完成，不是第五关就绪声明。以下原始未定方向/数值为实施前草案，以进展中的实测参数区分当前代码和整阶段验收。依据[长期规格](campaign-skeleton-spec-v1.md)和[第五关依赖](../tasks/echo-fifth-chapter-plan-v1.md)。用户已自主授权美术判断，无付费/安装/发布或删除旧资源授权扩张。

## 假设、目标与风格

延续已原创的26骨纸偶钟骨司祭：哑光铜钟、独立钟舌、肋板、两侧带坠短链、头冠。身体动作解释伤害，不能仅把大特效挂在不动的身体上。普通敌人/全部基础骨骼已在冻结名册门完成，大型攻击动画的延期门已解除；v1仍保留五个非攻击片段，不修改冻结名册或旧验证。

已制作独立v2场景/动作库/manifest，不改写v1。五个新原生基础片段加三招各warning/attack/recovery，共14片段，沿用既有原生动作命名；沿用真实Skeleton2D/Bone2D权重和rest，动作不移动物理根，不依赖动画事件造成伤害。连续骨骼采样、左右面向、关节拼缝、实色边缘、取消和死亡不复活分别验收。仅视觉取样时长为钟槌0.24/0.42/0.54、双坠0.22/0.56/0.66、冠钟0.24/0.48/0.60秒；未来判定时间须普通物理门实证，不能把资源时长当已验证躲避时间。

三招原始方向（具体范围/速度/时长必须后续物理RED/GREEN再冻结）：

1. 钟槌落击：胸钟抬起、钟舌下敲，前方局部短窄冲击，定向后不追踪玩家；不用扩张空心环或全屏圆。
2. 双坠召回：双臂链坠甩出、有限两枚坠锤沿固定方向往返，手链有明确回收姿态；返回固定施放原点，不无限追随移动Boss。整招有界，出/回不能重复刷同一目标伤害。
3. 冠钟三奏：头冠与肋板打开，三段短定向音钉发射，有限总弹数/寿命，和地面双拍或哨兵空心音波区分。阶段提高组合压力，不用无限增援或密度堆满全图。

先为真实已有Marker2D设计动作：Bell/Clapper/BeatOrigin，Head/Crown/RecallOrigin及左右PendantOrigin。挂点由骨骼局部运动，实战以施放时采样的固定世界起点/方向为事实；动画采样或恢复本身不能重新发射/伤害。小头顶感叹号表达短准备，范围提示只保留真正必要且小的局部部分，数值不得短于普通移动完整身体可逃离的实际门。

## 实施顺序与成功条件

- [x] E4a-1：独立v2资源/授权先语义RED再实现。小型bake/v2场景/外部动作库/manifest，授权16、资源1148；原v1/冻结名册SHA保持、26骨/14片段、三个动作各自不同关节链，取消后rest，无物理根移动。

  先单独验证新的bell_priest_attack_v1请求与NativeRigCheckpoint白名单，指向已冻结覆盖而不改原覆盖。现有all_character_rigs_v1只授权stone_carrier，其他Boss各有独立请求，不能拿其中任何一份授权冒用给钟骨司祭；资源输出必须新路径，旧v1输出存在时不能覆写。
- [x] E4a-2：真实Motion27契约、GPU638/168姿态+90连续样本/左右/闪白/真实挂点，保留取景RED后仅修视觉padding。独立包315检查含新旧权重/身体/rest逐项一致，最终264 Godot250733/36 Python272、独立PCK36专项21055/Main120/release。只勾资源门，不开放第五章；像素不替代普通战斗。
- [ ] E4b-1：Actor和唯一攻击导演最小所有权/三阶段框架，未完成招式明确拒绝，不先发伪通关。两者真实Health/入场/短头标/HUD、死亡/暂停/玩家离場取消；动作与战斗唯一时钟对应。
- [ ] E4b-2：逐一纵向实现钟槌、双坠、冠钟，每招各资源挂点+真实形状/碰撞+普通移动躲避/站立命中对照，30/60/120Hz且235速度/16.9真实玩家身体，无冲刺/加速/隐身或中途传送。固定施放、薄墙、反复回调、暂停/死亡/离场和有限产物清理先RED，再最小实现。
- [ ] E4b-3：完整自动轮换、真实Health阈值阶段与真正Boss死亡归属。当前GPU、同源检查、原前四关与E3回归、独立同PCK和release终态，只有此门后勾E4b。完整第五章普通两路线/跨进程解锁6仍归E5。

依赖：E3终态→E4a-1→E4a-2→E4b-1→三招逐一→E4b-3→E5。每个专项资源/导演/普通物理和实际像素独立标注，任何一个失败不改称整个阶段通过；不并发启动Godot任务，不中间提交/推送。

## 项目路径、接口与验证命令

Godot 4.7、typed GDScript、蛇形函数/变量；作者bake/render在scripts/art，运行Actor在scripts/actors，唯一导演/Motion在scripts/components，v2原生场景在scenes/actors/native，动作库在assets/art/actors/native，专项在scripts/tests，许可/审查在docs/art。沿用既有AttackDirector/NativeBossMotion的有限状态和取消方式，不新加第三方依赖或整个通用战斗框架。

已有同类导演使用 `func start_action(kind: StringName) -> bool:`，配置真实Actor/玩家/产物主人后，由导演检查入场、生命和所有者并固定施放起点/方向；无需让外部调用者提交另一套施放事实。后续钟祭导演沿用此边界，反复采样动画不能启动或重发攻击。具体内部几何接口待各招专项，不凭草案新增通用战斗API。

在指定5分钟超载工作树执行，验收目标先列于每个新专项，再创建实际文件：

```powershell
$taskEngine='C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
& $taskEngine --headless --audio-driver Dummy --path . --editor --quit
& scripts/tests/run_tests.ps1
& scripts/tests/run_release_checks.ps1
```

新增资源、授权与Motion专项已经存在，实际命令和边界记录于E4a review；E4b真实Actor/导演及13专项已接入规范runner，当前局部门与待完成门另见进展记录，不把计划GPU或包命令冒称已执行。每次终态退出0、唯一正PASS、无ERROR/TEST FAIL/资源或RID泄漏；源码、像素、夹具和包均逐SHA，不能绕过正确排除的制作目录。

## 边界与未定参数

始终：原创、保留原资源/真实保存/失败证据、TDD、当前真实圆身体和地形、有限所有权与唯一伤害；需要另问：付费资源、依赖/MCP安装、外部发布或不可逆迁移；禁止：收费提取/抄袭、删除失败检查、改玩家数值骗躲避、冻结名册改写、未完成解锁6和中间推送。没有用户待决项；数值未定留给后续实证调整，不提前将艺术方向当可玩性通过。
