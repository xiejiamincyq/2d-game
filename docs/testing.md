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
godot --headless --path . --script res://scripts/tests/DamageTest.gd --quit-after 120
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
| `BalanceTest` | 伤害来源音效映射、升级经验曲线和波次经验倍率 |
| `DamageTest` | 护盾/生命原子受击、0.35 秒无敌窗口和拒绝命中不续期 |
| `ProjectilePickupTest` | 真实物理碰撞击杀、延迟掉落与拾取物单次结算 |
| `RateTest` | 30/60/120Hz 下十秒持续射击的帧率一致性 |
| `DashTest` | 165 像素冲刺距离和跨帧扫掠伤害 |
| `WaveTest` | 帧率无关刷怪和四角共 40,000 个安全出生点样本 |
| `UpgradeTest` | 多级排队、事务令牌、伪造/重复选择和升级上限 |
| `StateTest` | Main 状态机、合法转换和唯一暂停所有权 |
| `UITest` | 四种分辨率、模态遮罩、焦点回收和 Toast Tween 生命周期 |
| `PerformanceTest` | 敌人注册表、静态重绘、固定音频 voice 和 250 敌人基线 |
| `SmokeTest` | START → PLAYING → PAUSED → PLAYING → RESULT 生命周期 |

### 美术套件（Godot）

| 套件 | 职责 |
| --- | --- |
| `EnemyDasherArtTest` | Dasher A/B 图集与运行时表现契约 |
| `PlayerM2RuntimeAnimationTest` | M2 玩家运行时动作动画集成与帧契约 |
| `PlayerCardinalPreviewTest` | 四基方向分层预览与武器遮挡 |
| `PlayerTurnaroundModelTest` | 转面模型构建工具契约 |
| `PlayerTurnaroundMVPreviewTest` | 多视图转面预览渲染 |
| `PlayerWeaponModelPreviewTest` | 武器模型预览渲染 |
| `PlayerGripPosePreviewTest` | 握持姿势候选板与运行时图集 |
| `PlayerGripRigTest` | 握持绑定（挂点/角度）逻辑 |
| `PlayerGripRigPreviewTest` | 握持绑定预览渲染 |
| `PlayerMotionRigTest` | 动作绑定计算 |
| `PlayerMotionRecoilPreviewTest` | 射击后坐力动作候选渲染 |
| `PlayerMotionRefinementRigTest` | 动作精修绑定参数 |
| `PlayerMotionRefinementPreviewTest` | 动作精修候选预览 |
| `PlayerMotionRefinementA2MultiYawTest` | A2 多朝向动作精修渲染 |
| `PlayerProductionTopologyMaterialPreviewTest` | 生产拓扑与材质预览门 |
| `PlayerM2Ready120YawBakeTest` | 120 朝向分层烘焙 |
| `PlayerM2RuntimeAnimationBakeTest` | 运行时动作帧烘焙 |
| `PlayerDirectionalArtTest` | 玩家方向图集运行时契约 |

### Python 管线套件

| 套件 | 职责 |
| --- | --- |
| `test_acquire_hunyuan3d_2mv` | Hunyuan3D-2MV 模型获取工具 |
| `test_build_player_action_preview` | 动作预览合成工具 |
| `test_build_player_action_slice` | 动作切片合成工具 |
| `test_build_player_cardinal_previews` | 基方向预览合成工具 |
| `test_build_player_grip_pose_preview` | 握持姿势预览合成工具 |
| `test_build_player_sample` | 玩家样例合成工具 |
| `test_generate_player_turnaround_model_mv` | 多视图转面生成脚本 |
| `test_remove_player_modeling_backgrounds` | 建模图去背景工具 |
| `test_split_player_modeling_sheet` | 建模图切分工具 |
| `test_split_player_weapon_sheet` | 武器图切分工具 |
| `test_validate_asset_registry` | 资产注册表校验器 |
| `test_validate_manifest` | 资产清单校验器 |
| `validate_art_pipeline_skill` | 美术管线技能结构与行为契约 |

## 严格失败条件

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

`PerformanceTest` 使用 250 个第八波敌人，验证：

- WaveDirector 注册表与节点退出同步；
- Player 在生产路径使用注册表，仅保留一个测试兼容扫描入口；
- 100 次命中不会增加 AudioStreamPlayer 节点数；
- Projectile、ExperienceShard 和 ShieldPickup 不进行逐帧静态重绘。

最新数据记录在 [performance/wave-8-baseline.md](performance/wave-8-baseline.md)。

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
git diff --check
rg -n 'get_tree\(\)\.paused\s*=' scripts -g '*.gd'
git status --short
```

暂停赋值只能出现在 `scripts/Main.gd`。提交不得包含密钥、`.godot` 本地状态、临时输出或无关 `.superpowers/sdd` 文件。
