# 测试与验收

## 标准命令

从项目根目录运行完整测试（Godot 玩法/美术套件 + Python 管线套件）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1
```

按分组运行（日常迭代更快）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1 -Group gameplay  # 仅玩法 Godot 套件
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1 -Group art       # 美术 Godot + Python 套件
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1 -Group python    # 仅 Python 套件
```

受限环境无 Python 时可加 `-SkipPython` 跳过 Python 套件；推送前检查不应跳过。

运行单个 Godot 套件：

```powershell
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/DamageTest.gd --quit-after 120
```

运行单个 Python 套件：

```powershell
python scripts/tests/test_validate_manifest.py
```

如果 `godot` 不在 PATH 中，可将 `GODOT_BIN` 设置为 Godot 4.7 console 可执行文件的绝对路径。严格运行器也会自动查找 WinGet 安装的 Godot 4.7。Python 套件需要 Python 3.10+ 与 Pillow；解释器默认查找 `python`，其次 `py -3`，可用 `PYTHON_BIN` 覆盖。

## 套件职责

### 玩法套件（Godot）

| 套件 | 职责 |
| --- | --- |
| `BalanceTest` | 伤害来源、战斗反馈与基础数值边界 |
| `EconomyBuildTest` | 192 局固定种子经济、购买力、路线成型、进化与 Boss TTK 代理样本 |
| `CombatEventTest` | 统一伤害与击杀事件（命中方向、死亡判定）契约 |
| `CombatFeedbackTest` | 有边界的战斗反馈：VFX、相机冲击与受限 hit-stop 生命周期 |
| `DamageTest` | 护盾/生命原子受击、0.35 秒无敌窗口和拒绝命中不续期 |
| `ProjectilePickupTest` | 真实物理碰撞击杀、金币/护盾掉落与拾取物单次结算 |
| `RateTest` | 30/60/120Hz 下十秒持续射击的帧率一致性 |
| `DashTest` | 165 像素冲刺距离和跨帧扫掠伤害 |
| `StealthTerrainTest` | 30/60/120 Hz 独立进程、等时长真实输入；隐身地形碰撞、滑墙、接触/墙角与恢复边界 |
| `StealthRecoveryTest` | 30/60/120 Hz；5秒安全保持、2秒上下退离、移除阻挡、封口开门、第二实体和真实暂停 |
| `StealthRecoverySideEffectTest` | 30/60/120 Hz；只读恢复提案触及、实际接受位置未触及的Area负例，以及真实拾取/伤害阳性 |
| `StealthRecoveryQueryTest` | 30/60/120 Hz；六种启用/禁用形状场景，真实零位移恢复查询的13项状态不变前提 |
| `StealthRecoveryAccountingTest` | 30/60/120 Hz；独立R/U位移分账、四槽上限、每段地形/实体几何及恢复退出检查 |
| `MovementTest` | 移动响应、敌人速度分层与相机跟随参数 |
| `ArenaMapTest` | 障碍竞技场布局、描述符与版本化种子稳定性 |
| `ArenaRuntimeTest` | 竞技场运行时障碍导航、遮挡与回收 |
| `WaveTest` | 帧率无关刷怪和世界边界内安全出生点样本 |
| `PortalTest` | 多传送门预警、持续涌兵、边界与出生分散 |
| `Phase5CombatTest` | 五阶段压力、4:30–5:30 节奏预算、新远程敌人与最终首领 |
| `BossTest` | 最终 Boss 基础行为、阶段与入场演出 |
| `BossHealthBarTest` | Boss 血条精确数值与显示契约 |
| `BossTentacleTest` | Boss 触手攻击（`TentacleAttack`）行为 |
| `BossPatternTest` | Boss 弹幕模式（瞄准扇射等）边界 |
| `BossDirectorTest` | Boss 攻击导演调度与隐身交互 |
| `SnapshotTest` | 版本化原子快照、损坏/未知版本拒绝、成长与玩家状态重建 |
| `ContinueTest` | 继续入口、稳定边界恢复、胜负/新游戏清档和运行时状态隔离 |
| `OverdriveTest` | 连杀超载充能、无敌窗口与伤害/射速倍率 |
| `Phase19Test` | 叠层灼烧、惯性弹道与从天而降入场 |
| `Phase20Test` | 敌速分层、隐身碰撞恢复与工程输出 |
| `Phase21Test` | 无人机射线转向、Boss 弹幕中断与移动冲刺 |
| `EnemyBehaviorTest` | 敌人追击层次、攻击前摇与状态恢复回归 |
| `UpgradeTest` | 多级排队、事务令牌、伪造/重复选择和升级上限 |
| `StateTest` | Main 状态机、合法转换和唯一暂停所有权 |
| `GateFailureTest` | 波次启动失败的安全结算与失败门故障处理 |
| `UITest` | 四种分辨率、模态遮罩、焦点回收和 Toast Tween 生命周期 |
| `SettlementUITest` | 波次结算、商店与结果操作 UI |
| `PerformanceTest` | 250 敌人、五门生成、无人机索敌、Boss 弹幕/VFX 回收和固定音频 voice |
| `SmokeTest` | START → WAVE_INTRO → PLAYING → SETTLEMENT → PAUSED → RESULT 生命周期 |

### 美术套件（Godot）

| 套件 | 职责 |
| --- | --- |
| `EnemyDasherArtTest` | Dasher A/B 图集与运行时表现契约 |
| `EnemyStaticArtTest` | 静态敌人精灵运行时契约 |
| `ProjectileLandingVisualTest` | 投射物落点视觉表现 |
| `ChibiRuntimeArtTest` | chibi 运行时美术资产契约 |
| `PlayerOcclusionOutlineTest` | 玩家被遮挡时的轮廓提示契约 |

### Python 管线套件

| 套件 | 职责 |
| --- | --- |
| `test_acquire_hunyuan3d_2mv` | Hunyuan3D-2MV 模型获取工具 |
| `test_art_stress_performance_report` | 美术压力性能报告工具 |
| `test_build_dasher_runtime_lod_candidates` | Dasher 运行时 LOD 候选合成 |
| `test_build_player_action_preview` | 动作预览合成工具 |
| `test_build_player_action_slice` | 动作切片合成工具 |
| `test_build_player_cardinal_previews` | 基方向预览合成工具 |
| `test_build_player_grip_pose_preview` | 握持姿势预览合成工具 |
| `test_build_player_sample` | 玩家样例合成工具 |
| `test_dasher_action_assets` | Dasher 动作资产契约 |
| `test_generate_player_turnaround_model_mv` | 多视图转面生成脚本 |
| `test_pack_environment_atlas` | 环境图集无损打包工具 |
| `test_prepare_chibi_assets` | chibi 资产清洗/切分/校验工具 |
| `test_prepare_static_enemy_sprite` | 静态敌人精灵制备与校验工具 |
| `test_project_status_docs` | 项目状态文档一致性 |
| `test_release_pack_policy` | 发布包内容策略（制作资源禁入） |
| `test_remove_connected_light_background` | 连通亮部去背景工具 |
| `test_remove_player_modeling_backgrounds` | 建模图去背景工具 |
| `test_repack_animation_sheet` | 动画表重打包工具 |
| `test_split_player_modeling_sheet` | 建模图切分工具 |
| `test_split_player_weapon_sheet` | 武器图切分工具 |
| `test_uid_policy` | UID 唯一性与源文件配对策略 |
| `test_validate_asset_registry` | 资产注册表校验器 |
| `test_validate_manifest` | 资产清单校验器 |
| `validate_art_pipeline_skill` | 美术管线技能结构与行为契约 |

## 严格失败条件

`StealthTerrainTest`、`StealthRecoveryTest`、`StealthRecoverySideEffectTest` 各自的三个进程同时设置 `--fixed-fps N` 和 `-- --physics-hz=N`（N 为30/60/120）。每一步必须恰有一次物理采样；12000帧只是上限，不能代替正常退出、唯一通过标记及错误检查。例如：

```powershell
godot_console --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://scripts/tests/StealthTerrainTest.gd --quit-after 12000 -- --physics-hz=60
```

两套夹具都在根节点 ready 后才创建并冻结真实玩家；恢复测试另检查碰撞层、disabled、真实敌体命中与实际玩家物理回调。`StealthRecoveryBudgetProbe.gd` 只是外凸角逐步取证，不是回归套件；其 `COMPLETE` 标记不代表位移预算验收，不能代替 `TEST PASS`。

每个 Godot 套件必须：

- 在 120 秒内结束；
- 进程退出码为 0；
- 输出且只输出一个 `TEST PASS: <suite> <positive-count>` 标记；
- 不包含 `SCRIPT ERROR`、`ERROR:` 或 `TEST FAIL:`；
- 不包含 ObjectDB、RID 或仍在使用的 Resource 泄漏警告。

每个 Python 套件必须：

- 在 120 秒内结束且进程退出码为 0；
- 输出且只输出一条 `Ran N tests` 汇总且 `N ≥ 1`；
- 不包含 `FAILED` 行或 `Traceback`。

Python 套件的通过标记由运行器输出：`TEST SUITE PASS: <文件名> (python, N tests)`。

运行器任一条件不满足都会汇总违规并返回非零退出码，避免 Godot 脚本错误被进程码 0 掩盖。

## UI 分辨率

`UITest` 逐一应用以下逻辑视口尺寸：

- 960×540
- 1280×720
- 1920×1080
- 2560×1080

HUD、升级面板、暂停面板和结算面板必须保持在视口内；升级、暂停和结算遮罩必须拦截鼠标；关闭模态界面后焦点必须回到 HUD 暂停按钮。

## 性能基线

`PerformanceTest` 使用 250 个终局强度敌人，验证：

- WaveDirector 注册表与节点退出同步；
- Player 在生产路径使用注册表，四架无人机每帧只读取一次敌人快照；
- 五个传送门在 30/60/120 Hz 下都生成 250 个敌人并释放门队列；
- Boss 弹幕自然销毁后移出控制器追踪表，VFX 记录严格受容量限制；
- 100 次命中和 400 次 Boss 提示不会增加 AudioStreamPlayer 节点数；
- 压力夹具释放后节点数回到测试前基线；
- Projectile、CoinPickup 和 ShieldPickup 不进行逐帧静态重绘。

## 推送前检查

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/prepush.ps1
```

`prepush.ps1` 按顺序执行以下检查，任一失败即返回非零退出码：

1. `git diff --check`（含暂存区）捕获空白错误；
2. 暂停赋值扫描，确保 `get_tree().paused =` 只出现在 `scripts/Main.gd`；
3. 相对 HEAD 的变更密钥扫描，命中高置信凭证模式即失败；
4. 完整严格测试套件；纯文档改动可加 `-SkipTests` 跳过。

等价手动命令：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1
powershell -ExecutionPolicy Bypass -File scripts/tests/run_release_checks.ps1
git diff --check
rg -n 'get_tree\(\)\.paused\s*=' scripts -g '*.gd'
git status --short
```

暂停赋值只能出现在 `scripts/Main.gd`。提交不得包含密钥、`.godot` 本地状态、临时输出或无关 `.superpowers/sdd` 文件。

`run_release_checks.ps1` 使用版本化的 `Windows Desktop` 预设在系统临时目录生成 PCK，再从该 PCK 启动主场景 120 帧。它不需要导出模板；生成正式独立 EXE 前仍需安装与 Godot 4.7 完全匹配的官方模板。
