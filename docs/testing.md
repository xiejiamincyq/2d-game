# 测试与验收

## 标准命令

从项目根目录运行完整测试：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1
```

运行单个套件：

```powershell
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/DamageTest.gd --quit-after 120
```

如果 `godot` 不在 PATH 中，可将 `GODOT_BIN` 设置为 Godot 4.7 console 可执行文件的绝对路径。严格运行器也会自动查找 WinGet 安装的 Godot 4.7。

## 套件职责

| 套件 | 职责 |
| --- | --- |
| `BalanceTest` | 伤害来源、战斗反馈与基础数值边界 |
| `DamageTest` | 护盾/生命原子受击、0.35 秒无敌窗口和拒绝命中不续期 |
| `ProjectilePickupTest` | 真实物理碰撞击杀、金币/护盾掉落与拾取物单次结算 |
| `RateTest` | 30/60/120Hz 下十秒持续射击的帧率一致性 |
| `DashTest` | 165 像素冲刺距离和跨帧扫掠伤害 |
| `WaveTest` | 帧率无关刷怪和世界边界内安全出生点样本 |
| `PortalTest` | 多传送门预警、持续涌兵、边界与出生分散 |
| `Phase5CombatTest` | 五阶段压力、4:30–5:30 节奏预算、新远程敌人与最终首领 |
| `SnapshotTest` | 版本化原子快照、损坏/未知版本拒绝、成长与玩家状态重建 |
| `ContinueTest` | 继续入口、稳定边界恢复、胜负/新游戏清档和运行时状态隔离 |
| `UpgradeTest` | 多级排队、事务令牌、伪造/重复选择和升级上限 |
| `StateTest` | Main 状态机、合法转换和唯一暂停所有权 |
| `UITest` | 四种分辨率、模态遮罩、焦点回收和 Toast Tween 生命周期 |
| `PerformanceTest` | 敌人注册表、静态重绘、固定音频 voice 和 250 敌人基线 |
| `SmokeTest` | START → WAVE_INTRO → PLAYING → SETTLEMENT → PAUSED → RESULT 生命周期 |

## 严格失败条件

每个套件必须：

- 在 120 秒内结束；
- 进程退出码为 0；
- 输出且只输出一个 `TEST PASS: <suite> <positive-count>` 标记；
- 不包含 `SCRIPT ERROR`、`ERROR:` 或 `TEST FAIL:`；
- 不包含 ObjectDB、RID 或仍在使用的 Resource 泄漏警告。

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
- Player 在生产路径使用注册表，仅保留一个测试兼容扫描入口；
- 100 次命中不会增加 AudioStreamPlayer 节点数；
- Projectile、CoinPickup 和 ShieldPickup 不进行逐帧静态重绘。

## 推送前检查

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1
git diff --check
rg -n 'get_tree\(\)\.paused\s*=' scripts -g '*.gd'
git status --short
```

暂停赋值只能出现在 `scripts/Main.gd`。提交不得包含密钥、`.godot` 本地状态、临时输出或无关 `.superpowers/sdd` 文件。
