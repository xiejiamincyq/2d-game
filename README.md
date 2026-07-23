# 废土清剿协议

使用 Godot 4.7 制作的 Windows 桌面 2D 赛博废土肉鸽战斗游戏。玩家需要在五个递进阶段中移动、瞄准、射击和冲刺，通过波次奖励与金币商店构建枪械、无人机、电弧和地刺流派。

## 环境要求

- Godot 4.7 stable
- Windows 10 或 Windows 11
- 运行自动测试时需要 Windows PowerShell 5.1 或 PowerShell 7

## 运行游戏

1. 安装 Godot 4.7 stable。
2. 在 Godot Project Manager 中导入本仓库的 `project.godot`。
3. 打开项目后按 `F6` 运行当前场景，或按 `F5` 运行主场景 `scenes/Main.tscn`。

## 操作

- `WASD`：移动
- 鼠标：瞄准
- 鼠标左键：持续射击
- 鼠标右键：向准星方向冲刺并对路径上的敌人造成伤害
- `Space`：暂停或继续
- `1`–`6`：选择结算界面的卡牌
- `C`：开始页存在有效存档时继续游戏
- `R`：在胜利或失败结算后重新开始

## 游戏内容

- 七类敌人：追击者、疾冲者、喷吐者、重装者、狙击手、投弹手和最终首领。
- 五个递进阶段；敌人从玩家周围的多座传送门持续涌出，最终首领会使用预警攻击并召唤援军。
- 主武器多枪线、射速、伤害、弹速与穿透升级。
- 无人机持续激光、电弧脉冲、移动地刺和冲刺近战构筑。
- 每阶段结算免费领取一张卡牌，之后可用战斗中拾取的金币继续购买；三条流派拥有独立等级与终极进化。
- 连杀充能触发短时无敌超载；超载期间枪线翻倍、紫色发光弹幕和专用击杀音效生效。
- 稳定阶段边界自动保存。开始页可继续上一局，胜利、失败、重开或主动新游戏会清理旧进度。

## 自动测试

在项目根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1
```

严格运行器会为每个测试创建独立 Godot 进程，并同时验证退出码、通过计数、脚本错误、引擎错误和对象泄漏。单项测试和完整测试说明见 [docs/testing.md](docs/testing.md)。

## 导出 Windows 版本

1. 在 Godot 中选择 `Editor > Manage Export Templates`，安装与 Godot 4.7 匹配的导出模板。
2. 选择 `Project > Export`。
3. 点击 `Add...`，选择 `Windows Desktop`。
4. 设置产品名称、图标和输出路径，例如 `build/windows/WastelandProtocol.exe`。
5. 保持 `Embed PCK` 或使用默认的独立 `.pck` 均可；不要把本机调试路径写入导出配置。
6. 点击 `Export Project`，然后在干净目录中启动导出的 `.exe` 做一次启动、暂停、升级和结算检查。

## 代码结构

- `scripts/actors`：玩家和敌人行为
- `scripts/components`：生命、投射物与战斗组件
- `scripts/systems`：阶段、升级、版本化存档和音频系统
- `scripts/pickups`：金币与护盾拾取物
- `scripts/ui`、`scenes/ui`、`themes`：HUD、模态界面和共享主题
- `scripts/tests`：隔离的 headless 回归测试与严格运行器
