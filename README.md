# 废土清剿协议

使用 Godot 4.7 制作的 Windows 桌面纯2D Q版肉鸽战斗游戏。当前分支沿已批准的清爽玩具、薄荷实验农场和加粗轮廓方向制作，每局生成随机障碍地图；方向批准不等于所有资源或许可证验收，环境资源仍为draft。玩家在六个普通波次与最终首领战中移动、瞄准、射击和冲刺，通过波次奖励与金币商店构建枪械、无人机、电弧和地刺流派。标题“废土清剿协议”保留，旧45°/M2美术文档仅作历史记录。

## 本机直接试玩（不需要安装 Godot）

本机已保留最近一次冻结的 Windows 试玩候选：打开 `build/playtest/5分钟超载-current-v7/`，双击 `five-minute-overdrive.exe`；同目录的 `.pck` 必须保留。可以复制整个目录，不需要打开编辑器或运行测试。旧包保留；v7导出冻结时的工作树，加入普通敌人受击颜色修复，并保留音频退出收尾和开局波次显示修复。

这是本机文件，不随 Git 克隆下载，也不是公开发布。v7第一个实际EXE进程验证了开局、冲刺、自然失败/R回标题、暂停冻结和普通关窗，退出0且三路日志无错误或泄漏；第二进程窗口工具占用/截图错配，验证未完成，不算通过。完整EXE通关、声音听感和人工手感未代签。操作、核验哈希及失败记录见[本地试玩交接](docs/local-playtest-handoff-v7.md)。

v7的190份生产输入与冻结时工作树逐hash一致；相对[历史v6包](docs/local-playtest-handoff-v6.md)只改变[普通敌人持续受击可读性修复](docs/enemy-readability-review-v1.md)。构建包含原有未提交资源，不称干净HEAD；旧v6不含该修复，历史验证不自动移植为v7通过。随后源码新增[地面预警分层修复](docs/ground-warning-review-v1.md)，**v7不含该修复，不能称与现行源码全同**；更新本地包前可用Godot运行现行源码。

分层修复前的生产输入另有[一次自然通关与完整首收集窗口](docs/collection-natural-review-v1.md)的62原图、六景短片和修订离线校验；原检查器失败独立保留，不等于修复后源码的自然运行、独立EXE完整流程或全项目验收。

## 环境要求

- Godot 4.7 stable
- Windows 10 或 Windows 11
- 运行自动测试时需要 Windows PowerShell 5.1 或 PowerShell 7
- 运行 Python 美术管线自动测试时需要 Python 3.10+ 与 Pillow

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
- 六个普通波次；敌人从玩家周围的多座传送门持续涌出，随后进入最终首领战，首领会使用预警攻击并召唤援军。
- 主武器多枪线、射速、伤害、弹速与穿透升级。
- 无人机持续激光、电弧脉冲、移动地刺和冲刺近战构筑。
- 每阶段结算免费领取一张卡牌，之后可用战斗中拾取的金币继续购买；三条流派拥有独立等级与终极进化。
- 连杀充能触发短时无敌超载；超载期间枪线翻倍，友方弹幕采用青绿/薄荷/奶油色并播放专用击杀音效。Boss地面危险提示另用珊瑚色；其他旧攻击语汇仍列入视觉待验，不声称所有敌方特效已统一。
- 稳定阶段边界自动保存。开始页可继续上一局，胜利、失败、重开或主动新游戏会清理旧进度。

## 自动测试

在项目根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1
```

严格运行器会为每个测试创建独立进程（Godot 套件为独立 Godot 进程，美术管线工具为独立 Python 解释器进程），并同时验证退出码、通过计数、脚本错误、引擎错误和对象泄漏。可用 `-Group gameplay`、`-Group art`、`-Group python` 分组运行以加快迭代。单项测试和完整测试说明见 [docs/testing.md](docs/testing.md)。

## 导出 Windows 版本

1. 在 Godot 中选择 `Editor > Manage Export Templates`，安装与 Godot 4.7 匹配的导出模板。
2. 仓库已经提供 `Windows Desktop` 导出预设；选择 `Project > Export` 后直接检查输出路径即可，不要写入本机调试路径。
3. 命令行发布前先运行数据包与主场景冒烟：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_release_checks.ps1
```

4. 安装模板后可用 Godot UI 导出，或执行 `godot --headless --path . --export-release "Windows Desktop" build/windows/WastelandProtocol.exe`。
5. 在干净目录中启动导出的 `.exe`，人工检查开始、暂停、升级、Boss 战和最终结算。

## 代码结构

- `scripts/actors`：玩家和敌人行为
- `scripts/components`：生命、投射物与战斗组件
- `scripts/systems`：阶段、升级、版本化存档和音频系统
- `scripts/pickups`：金币与护盾拾取物
- `scripts/ui`、`scenes/ui`、`themes`：HUD、模态界面和共享主题
- `scripts/tests`：隔离的 headless 回归测试与严格运行器
