# Implementation Plan: 五分钟超载清剿

## Overview

把当前八波、零散刷新的生存战斗改造为五阶段、约五分钟的高速构筑局。敌人通过玩家周围 3–5 个传送门成群涌出；连续击杀积累超载，满槽后自动进入约 2.8 秒的无敌高输出窗口；玩家在单局内完成一条能力进化，并可从最近完成的阶段继续游戏。

## Product Success Criteria

- 正常构筑的单局时长落在 4:30–5:30，目标中位数为 5:00。
- 玩家在 90 秒内获得第一个构筑联动，并在最终阶段前获得终极进化。
- 每次传送门攻势在可读预警后形成明显的集中涌出，任何敌人都不在玩家危险近距离内出生。
- 一局通常触发 2–4 次超载；超载期间不消耗生命或护盾，输出提升清晰可感知，结束后所有倍率准确恢复。
- 250 个敌人的既有性能基线不退化，密集传送门生成不造成单帧无上限实例化。
- 退出后可从最近阶段检查点继续；损坏或旧版本存档安全回退到新游戏。

## Architecture Decisions

- `WaveDirector` 只负责阶段、传送门编排、敌人注册和活跃上限；新的 `SpawnPortal` 节点负责预警、局部批次队列和传送门生命周期。
- 传送门位置在以玩家为中心的环带内采样，初始调参范围为 300–520 像素；靠近世界边界时采用拒绝采样和安全回退，禁止简单钳制后落入近距离。
- 每次攻势生成 3–5 个传送门，预警约 0.6 秒，主要敌群在约 0.8 秒内涌出。底层按帧预算分批创建，视觉同步不等于同一帧实例化。
- 新建 `OverdriveSystem` 管理槽值、连杀衰减、触发和持续时间。`Main` 负责连接系统，不承载倍率计算。
- 超载默认自动触发，基础持续时间 2.8 秒。玩家在窗口内完全拒绝伤害且不消耗护盾；初始平衡目标为全伤害 4 倍、主武器射速 2 倍，并加快已有被动能力。倍率统一由运行时修饰器计算，禁止直接反复乘除基础属性。
- 超载音频沿用现有合成音频架构，拆为触发重击、短循环和结束尾音。画面使用独立的程序化效果层：单次冲击闪光、青色主轮廓、少量品红分层、武器橙色强调、扩张能量环和轻量镜头震动；不使用持续频闪。
- 升级继续复用三选一界面，但增加能力家族、前置条件和里程碑进化选择。首版只实现三条进化路线，避免把升级池扩成大量低辨识度选项。
- 存档使用带 `schema_version` 的阶段快照，写入 `user://`。只保存阶段起点可重建的数据，不保存活跃敌人、弹幕、拾取物或传送门实例。
- 视觉 MVP 保持当前程序化 `_draw()` 路线。若之后引入生成式特效贴图，必须按 `godot-neon-art-pipeline` 先建立有效 manifest、完成 combat/effect style-lock，再进入 Godot 导入验收。

## Dependency Graph

```text
传送门节点与安全采样
  -> 传送门攻势编排
     -> 五阶段节奏与最终强敌

击杀来源与超载状态机
  -> 玩家无敌/输出修饰器
     -> 超载音画反馈与 HUD

升级家族与进化条件
  -> 三条进化效果
     -> 五阶段升级里程碑

稳定的阶段与构筑状态
  -> 阶段快照
     -> 继续游戏 UI

所有路径
  -> 五分钟平衡与性能验收
```

## Task 1: 建立传送门生成竖切

**Description:** 新增可独立测试的 `SpawnPortal` 节点。节点先显示预警，再按给定队列和帧预算请求生成敌人，最后在队列耗尽后关闭。先用程序化环形和粒子线条表现，不引入最终贴图。

**Acceptance criteria:**
- [ ] 传送门严格经历 `TELEGRAPH -> BURST -> CLOSING`，关闭后不再发出生成请求。
- [ ] 同一帧发出的生成请求不超过配置预算，完整生命周期发出的敌人类型和数量与输入队列一致。
- [ ] 预警使用敌对品红与橙色提示，实际游戏尺寸下不与经验、护盾或玩家攻击混淆。

**Verification:**
- [ ] `godot --headless --path . --script res://scripts/tests/PortalTest.gd --quit-after 120`
- [ ] 手动检查单个传送门的预警、爆发和关闭节奏。

**Dependencies:** None

**Files likely touched:**
- `scripts/systems/SpawnPortal.gd`
- `scripts/tests/PortalTest.gd`
- `scripts/tests/run_tests.ps1`

**Estimated scope:** Medium

## Task 2: 接入环带传送门攻势

**Description:** 让 `WaveDirector` 按攻势建立 3–5 个传送门，并将敌人队列分配给各门。位置必须处于玩家周围安全环带且落在世界边界内；敌人从对应门口的小范围内涌出，不再从全地图随机点逐只出现。

**Acceptance criteria:**
- [ ] 常规空间中所有门距玩家 300–520 像素，边界退化场景仍不小于硬安全距离 260 像素。
- [ ] 一个攻势的全部敌人只由传送门请求生成，并保持原有敌人注册、死亡掉落和剩余数量统计。
- [ ] 3–5 个门在约 0.8 秒的主要爆发窗口内制造集中涌出，同时遵守全局单帧生成预算。

**Verification:**
- [ ] `godot --headless --path . --script res://scripts/tests/WaveTest.gd --quit-after 120`
- [ ] 30/60/120 Hz 下比较传送门数量、总生成量和爆发完成时间。

**Dependencies:** Task 1

**Files likely touched:**
- `scripts/systems/WaveDirector.gd`
- `scripts/systems/SpawnPortal.gd`
- `scripts/tests/WaveTest.gd`
- `scripts/tests/PerformanceTest.gd`

**Estimated scope:** Medium

## Checkpoint: 传送门暴兵

- [ ] PortalTest、WaveTest 和 PerformanceTest 通过。
- [ ] 玩家中心、四角和世界边缘位置均无近身出生。
- [ ] 密集攻势有暴兵观感，且没有同帧无上限实例化。

## Task 3: 建立超载状态机

**Description:** 新增 `OverdriveSystem`，接收击杀及伤害来源，维护连杀窗口和 0–100 槽值。槽满后自动触发固定时长超载，并发出开始、进度、结束信号。敌人死亡链路需保留最后一次有效伤害来源，以支持冲刺等行为奖励。

**Acceptance criteria:**
- [ ] 普通击杀稳定充能，冲刺/地刺击杀可配置额外充能，超时后连杀归零但已获得槽值按规则保留。
- [ ] 满槽只触发一次 2.8 秒超载，窗口内不重复触发，结束后槽值回到零。
- [ ] 同一敌人死亡只记一次击杀，未知伤害来源安全回退为普通充能。

**Verification:**
- [ ] `godot --headless --path . --script res://scripts/tests/OverdriveTest.gd --quit-after 120`
- [ ] ProjectilePickupTest 继续覆盖真实击杀与延迟掉落。

**Dependencies:** None

**Files likely touched:**
- `scripts/systems/OverdriveSystem.gd`
- `scripts/actors/Enemy.gd`
- `scripts/systems/WaveDirector.gd`
- `scripts/Main.gd`
- `scripts/tests/OverdriveTest.gd`

**Estimated scope:** Medium

## Task 4: 实现无敌高输出窗口

**Description:** 为玩家增加统一的临时战斗修饰器。超载期间拒绝所有伤害且不消耗护盾，并将主武器、无人机、电弧、地刺和冲刺纳入同一输出倍率合同。结束、死亡、重启和加载时都必须恢复正常状态。

**Acceptance criteria:**
- [ ] 超载期间任何伤害源都不能降低护盾或生命，原有 0.35 秒受击无敌逻辑在非超载状态保持不变。
- [ ] 初始目标为全伤害 4 倍、主武器射速 2 倍；所有能力从有效倍率读取，不直接污染基础升级数值。
- [ ] 超载结束后伤害、射速和被动计时器精确回到进入前合同，多次触发不累乘。

**Verification:**
- [ ] OverdriveTest 覆盖伤害拒绝、护盾不消耗、所有伤害族倍率和两次连续触发后的恢复。
- [ ] `godot --headless --path . --script res://scripts/tests/DamageTest.gd --quit-after 120`
- [ ] `godot --headless --path . --script res://scripts/tests/RateTest.gd --quit-after 120`

**Dependencies:** Task 3

**Files likely touched:**
- `scripts/actors/Player.gd`
- `scripts/systems/OverdriveSystem.gd`
- `scripts/components/Projectile.gd`
- `scripts/tests/OverdriveTest.gd`
- `scripts/tests/RateTest.gd`

**Estimated scope:** Medium

## Task 5: 完成超载音画反馈

**Description:** 增加独立 `OverdriveVisual` 效果层和三段式音频反馈。触发瞬间必须成为全局视觉与听觉焦点，持续阶段保持强烈但可读，结束时明确收束；同时在 HUD 中显示充能和剩余时间。

**Acceptance criteria:**
- [ ] 音频包含触发重击、可无缝短循环和结束尾音，重复触发不创建新的 AudioStreamPlayer，也不残留循环。
- [ ] 画面包含单次冲击闪光、玩家青色高亮、少量品红层、武器橙色强调、扩张环和轻量镜头震动，不使用持续频闪或遮挡危险提示。
- [ ] HUD 在四种目标分辨率下清楚显示槽值、满槽状态和 2.8 秒倒计时，暂停时不会继续消耗时间。

**Verification:**
- [ ] `godot --headless --path . --script res://scripts/tests/UITest.gd --quit-after 120`
- [ ] `godot --headless --path . --script res://scripts/tests/PerformanceTest.gd --quit-after 120`
- [ ] 手动以普通音量和静音模式检查开始、循环、结束、暂停和重启。

**Dependencies:** Task 4

**Files likely touched:**
- `scripts/components/OverdriveVisual.gd`
- `scripts/systems/AudioManager.gd`
- `scripts/ui/HUD.gd`
- `scripts/ui/GameUI.gd`
- `scripts/Main.gd`

**Estimated scope:** Medium

## Checkpoint: 超载必杀窗口

- [ ] OverdriveTest、DamageTest、RateTest、UITest 和 PerformanceTest 通过。
- [ ] 一次完整超载从触发到结束没有倍率、音频节点或暂停状态泄漏。
- [ ] 试玩者无需解释即可指出“无敌高输出窗口”何时开始和结束。

## Task 6: 建立升级家族与进化选择

**Description:** 为现有升级增加家族、层级、前置条件和进化标识。普通升级仍为三选一，但达到阶段里程碑并满足条件时，至少提供一个与当前构筑相关的终极进化，不让随机洗牌完全阻断成型。

**Acceptance criteria:**
- [ ] 升级能按弹幕、无人机/电弧、冲刺/地刺家族统计投入，并可序列化已选次数和进化 ID。
- [ ] 进化只有满足前置条件才出现，每局只能选择一个终极进化，伪造或过期选择继续被拒绝。
- [ ] 在标准经验曲线下，90 秒内可形成家族方向，最终阶段前必有一次合法进化机会。

**Verification:**
- [ ] `godot --headless --path . --script res://scripts/tests/UpgradeTest.gd --quit-after 120`
- [ ] BalanceTest 验证标准击杀收益下的升级时间点。

**Dependencies:** None

**Files likely touched:**
- `scripts/systems/UpgradeSystem.gd`
- `scripts/Main.gd`
- `scripts/tests/UpgradeTest.gd`
- `scripts/tests/BalanceTest.gd`

**Estimated scope:** Medium

## Task 7: 实现弹幕终极进化

**Description:** 将多枪线、穿透和射速路线收敛为一种可辨认的弹幕进化。初始候选为“轨道风暴”：固定间隔的主武器齐射追加受严格上限约束的环形弹幕，超载时缩短触发间隔而不是无限增加节点。

**Acceptance criteria:**
- [ ] 未获得进化时现有主武器行为完全不变，获得后在固定、可测试的齐射计数上触发环形弹幕。
- [ ] 超载能明显提高进化爆发，但单次追加弹量和单帧射弹量均有显式上限。
- [ ] 进化投射物继承伤害来源、穿透、世界边界和清理合同。

**Verification:**
- [ ] UpgradeTest 覆盖前置条件和仅一次进化。
- [ ] RateTest 覆盖 30/60/120 Hz 的追加齐射计数。
- [ ] PerformanceTest 覆盖超载弹幕节点上限。

**Dependencies:** Tasks 4, 6

**Files likely touched:**
- `scripts/actors/Player.gd`
- `scripts/components/Projectile.gd`
- `scripts/tests/RateTest.gd`
- `scripts/tests/PerformanceTest.gd`

**Estimated scope:** Medium

## Task 8: 实现无人机终极进化

**Description:** 将无人机与电弧路线收敛为“雷网矩阵”。无人机持续锁定目标，达到节拍时在已锁定目标之间释放一次受上限约束的电弧脉冲；超载时提高节拍而不复制无限激光节点。

**Acceptance criteria:**
- [ ] 雷网只选择有效、未退出树的敌人，目标不足时安全降级。
- [ ] 同一节拍对单个敌人的命中次数有上限，超载结束后节拍恢复。
- [ ] 无人机、激光和电弧视觉节点数量继续受现有上限约束。

**Verification:**
- [ ] UpgradeTest 覆盖进化申请与重复拒绝。
- [ ] BalanceTest 覆盖雷网伤害和超载倍率。
- [ ] PerformanceTest 覆盖 250 敌人目标选择与节点数量。

**Dependencies:** Tasks 4, 6

**Files likely touched:**
- `scripts/actors/Player.gd`
- `scripts/components/ArcPulseVisual.gd`
- `scripts/tests/BalanceTest.gd`
- `scripts/tests/PerformanceTest.gd`

**Estimated scope:** Medium

## Task 9: 实现冲刺地刺终极进化

**Description:** 将冲刺和地刺路线收敛为“裂地超载”。冲刺路径产生强化地刺，冲刺击杀额外充能；超载期间冲刺冷却显著缩短，但每个敌人每次冲刺仍只受一次扫掠伤害。

**Acceptance criteria:**
- [ ] 进化前后的冲刺位移、跨帧扫掠和世界边界合同不变。
- [ ] 强化地刺的间距、持续时间和伤害有显式上限，不因高帧率重复生成。
- [ ] 冲刺击杀的额外超载充能只结算一次，超载结束后冷却恢复。

**Verification:**
- [ ] `godot --headless --path . --script res://scripts/tests/DashTest.gd --quit-after 120`
- [ ] OverdriveTest 覆盖冲刺击杀额外充能。
- [ ] PerformanceTest 覆盖地刺节点上限。

**Dependencies:** Tasks 4, 6

**Files likely touched:**
- `scripts/actors/Player.gd`
- `scripts/components/SpikeTrap.gd`
- `scripts/tests/DashTest.gd`
- `scripts/tests/OverdriveTest.gd`
- `scripts/tests/PerformanceTest.gd`

**Estimated scope:** Medium

## Checkpoint: 三条极速构筑

- [ ] 三条路线都能在最终阶段前稳定进化。
- [ ] 每条路线在普通状态和超载状态下都有明显不同的战斗形态。
- [ ] UpgradeTest、BalanceTest、RateTest、DashTest 和 PerformanceTest 通过。

## Task 10: 重构五阶段节奏

**Description:** 将八波数量表替换为五阶段攻势表。每阶段定义传送门轮次、敌人构成、最早结束时间、升级里程碑和活跃敌人上限；最终阶段加入一个复用传送门主题的简化强敌，作为完整构筑的火力验证。

**Acceptance criteria:**
- [ ] 五阶段按配置顺序推进，阶段内所有传送门队列和活跃敌人清空后才能结算。
- [ ] 标准自动化战力模型下总时长目标为 4:30–5:30，第四阶段结束前触发进化选择。
- [ ] 最终强敌至少包含一个可预警攻击和一次召唤传送门援军，不依赖单纯堆高生命值。

**Verification:**
- [ ] WaveTest 覆盖阶段推进、传送门队列、最终强敌和胜利信号。
- [ ] BalanceTest 输出每阶段预计时长、敌人总生命和经验供给。
- [ ] 手动完成三条构筑各一局并记录时长。

**Dependencies:** Tasks 2, 6, 7, 8, 9

**Files likely touched:**
- `scripts/systems/WaveDirector.gd`
- `scripts/actors/PortalOverseer.gd`
- `scripts/Main.gd`
- `scripts/tests/WaveTest.gd`
- `scripts/tests/BalanceTest.gd`

**Estimated scope:** Medium

## Task 11: 建立阶段快照存档

**Description:** 新增版本化 `RunSaveSystem`，在开局模块确定和每阶段升级结算后写入原子阶段快照。快照只包含重建下一阶段所需的玩家、升级、经验、超载和运行统计数据。

**Acceptance criteria:**
- [ ] 快照包含 schema 版本、待开始阶段、玩家基础状态、升级次数、进化 ID、等级/经验、击杀和用时。
- [ ] 写入采用临时文件替换策略；缺字段、非法数值、损坏 JSON 和未知版本均安全拒绝并保留新游戏能力。
- [ ] 加载后从阶段开头重建，不恢复敌人、弹幕、拾取物、传送门或进行中的超载。

**Verification:**
- [ ] `godot --headless --path . --script res://scripts/tests/SaveTest.gd --quit-after 120`
- [ ] SaveTest 覆盖往返、损坏文件、旧版本、数值钳制和无存档场景。

**Dependencies:** Tasks 3, 6, 10

**Files likely touched:**
- `scripts/systems/RunSaveSystem.gd`
- `scripts/systems/UpgradeSystem.gd`
- `scripts/actors/Player.gd`
- `scripts/tests/SaveTest.gd`
- `scripts/tests/run_tests.ps1`

**Estimated scope:** Medium

## Task 12: 接入继续游戏流程

**Description:** 在开始界面只在有效存档存在时显示“继续游戏”，在暂停退出和阶段结算时协调保存。胜利或失败后清除当前局存档；加载过程必须通过 `Main` 的状态机进入合法状态。

**Acceptance criteria:**
- [ ] 无有效存档时不显示继续入口；有效存档可恢复玩家构筑和待开始阶段。
- [ ] 暂停、升级、结果界面继续保持唯一暂停所有权，加载不会绕过状态转换。
- [ ] 胜利、失败和主动新游戏清理旧局存档，普通中途退出保留最近阶段快照。

**Verification:**
- [ ] `godot --headless --path . --script res://scripts/tests/StateTest.gd --quit-after 120`
- [ ] `godot --headless --path . --script res://scripts/tests/UITest.gd --quit-after 120`
- [ ] SmokeTest 覆盖新游戏、继续、失败清档和重新开始。

**Dependencies:** Task 11

**Files likely touched:**
- `scripts/Main.gd`
- `scripts/ui/GameUI.gd`
- `scripts/ui/PauseScreen.gd`
- `scripts/tests/StateTest.gd`
- `scripts/tests/SmokeTest.gd`

**Estimated scope:** Medium

## Checkpoint: 完整五分钟续玩流程

- [ ] 新游戏、阶段保存、退出、继续、胜利和失败形成闭环。
- [ ] 三条构筑都能完成最终阶段，且继续后属性与升级一致。
- [ ] SaveTest、StateTest、UITest、SmokeTest 和 WaveTest 通过。

## Task 13: 完成平衡与性能验收

**Description:** 用自动化数据和手动试玩收敛传送门距离、敌人批量、经验曲线、超载充能、2.8 秒倍率、进化输出和最终强敌生命。只调配置和常量，不在此阶段引入新机制。

**Acceptance criteria:**
- [ ] 三条构筑各至少三次测试局的中位时长落在 4:30–5:30，且通常触发 2–4 次超载。
- [ ] 超载期间每秒击杀显著高于普通期间，玩家全程无伤且音画起止明确；窗口外挑战仍然存在。
- [ ] 250 敌人基线、最密集传送门攻势和最高弹幕进化均通过性能测试，无对象或音频节点泄漏。

**Verification:**
- [ ] `powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1`
- [ ] `git diff --check`
- [ ] 手动检查 960x540、1280x720、1920x1080、2560x1080 下的门、HUD 和超载画面。

**Dependencies:** Tasks 5, 10, 12

**Files likely touched:**
- `scripts/systems/WaveDirector.gd`
- `scripts/systems/OverdriveSystem.gd`
- `scripts/systems/UpgradeSystem.gd`
- `scripts/tests/BalanceTest.gd`
- `docs/performance/five-minute-overdrive-baseline.md`

**Estimated scope:** Medium

## Checkpoint: Complete

- [ ] 全部自动化测试严格通过，无脚本错误、对象泄漏或资源泄漏。
- [ ] 五分钟目标、传送门暴兵、三条进化、超载必杀窗口和阶段续玩全部满足验收标准。
- [ ] 提交仅包含完成且相关的文件，不包含 `.godot`、临时生成状态或现有 `.superpowers/sdd` 文件。

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| 大量敌人同帧实例化造成卡顿 | High | 视觉同步、分帧生成；门级与全局双重预算；保留活跃敌人上限。 |
| 传送门靠近玩家或在边界采样失败 | High | 环带拒绝采样、硬安全距离、确定性回退点和四角压力测试。 |
| 无敌 4 倍输出让普通战斗失去意义 | High | 将窗口压缩到约 2.8 秒，控制每局 2–4 次，用充能速度而非削弱爽感调平衡。 |
| 临时倍率反复触发后污染基础属性 | High | 统一有效属性修饰器，测试两次以上触发和加载/重启恢复。 |
| 高频弹幕、无人机和地刺放大节点数量 | High | 每个进化设置显式节点、目标和单帧生成上限，并扩展 PerformanceTest。 |
| 升级随机性导致五分钟内无法成型 | Medium | 家族权重、里程碑保底进化和标准经验模型测试。 |
| 自动超载在低敌量时浪费 | Medium | 先记录触发时敌人密度；若常见，再加入短暂等待条件或手动触发。 |
| 超载特效遮挡危险提示或造成视觉疲劳 | Medium | 单次闪光、持续边缘效果、限制震动和 bloom，不使用持续频闪。 |
| 存档架构拖慢核心玩法 | Medium | 只存阶段快照；存档任务排在核心战斗验证之后。 |

## Open Questions To Validate During Implementation

- 超载满槽后立即自动触发，还是允许最多等待 1–2 秒直到附近敌人数达到阈值？默认先实现立即触发并采集数据。
- 传送门硬安全距离 260 像素、目标环带 300–520 像素是否在 960x540 下仍然公平？以四种目标分辨率实测为准。
- 最终强敌是否需要独立美术资产？MVP 先用程序化轮廓和传送门特效完成玩法验证。
