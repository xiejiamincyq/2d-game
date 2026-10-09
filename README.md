# 废土清剿协议

使用 Godot 4.7 制作的 Windows 桌面纯2D Q版肉鸽战斗游戏。当前分支沿已批准的清爽玩具、薄荷实验农场和加粗轮廓方向制作，每局生成随机障碍地图；方向批准不等于所有资源或许可证验收，环境资源仍为draft。玩家在六个普通波次与最终首领战中移动、瞄准、射击和冲刺，通过波次奖励与金币商店构建枪械、无人机、电弧和地刺流派。标题“废土清剿协议”保留，旧45°/M2美术文档仅作历史记录。

## 本机直接试玩（不需要安装 Godot）

最新本机预览为 **v12**：打开 `build/playtest/5分钟超载-current-v12/`，双击 `five-minute-overdrive.exe`；同目录 `.pck` 必须保留。不需要编辑器或运行测试。旧v11/v10-r2/v9保留，请勿混用PCK。

v12按玩家反馈改为小怪头顶黑边感叹号、短前摇和单道攻击线；提前恢复追击并补偿冷却，不增加既定攻击频率。投掷落点和大型怪/Boss必要范围提示保留，三倍伤害、hitbox和玩家输出不变。86 Godot套件、35 Python套件通过；实际PCK的短节奏31断言、扑击碰撞21断言通过。已录制真实Main受控遭遇的15秒动态预览，真人手感仍待确认。[v12预览交接](docs/local-playtest-handoff-v12.md)。

下面是保留的历史版本验证记录，不冒称v12自然整局验收。

v11应用已选择的AB组合敌怪特效：利落的爪击斩痕/扑击速度线、敌方弹丸短尾迹，以及贴着受击边缘的紧凑描边爆点；持续命中有局部节流。危险边界、敌我伤害、攻击间隔、碰撞、群体移动和现有80ms保色闪白均保持不变。完整回归85 Godot+35 Python套件通过，实际PCK九套1231断言及普通EXE标题启动退出通过；原生受控连续效果、密集场景和真实Main场景截图另行验收。本轮没有重跑正常输入整局，也不代签普通EXE完整通关/真人手感。[v11特效与试玩交接](docs/local-playtest-handoff-v11.md)记录hash和验证边界。

v10-r2历史候选落实全部敌人基础伤害三倍、黑边准心、追击者爪击/扑击、雷网间隔+50%及现行说明同步，并保留v9榴弹与群体移动修复；这些机制在v11仍保留。v10-r2的83/35回归、正常输入源码通关和PCK七套346断言，仅是[v10历史交接](docs/local-playtest-handoff-v10.md)的证据，不冒称v11整局重测。

这是本机文件，不随Git克隆下载，也不是公开发布；含原有未提交资源，不称干净HEAD构建。声音听感、最低硬件、来源许可和人工手感仍待验。

### v8历史冻结与证据

[v9历史交接](docs/local-playtest-handoff-v9.md)的榴弹30%速度继承/基础飞速+20%、局部群体对齐/聚合/分离和慢大怪绕行保留；其78/35回归、194输入和旧自然流程仅为v9记录，不冒称本轮重测。

先前[最终冻结索引](docs/local-project-freeze-v1.md)、[v8交接](docs/local-playtest-handoff-v8.md)、[普通EXE跨进程继续](docs/local-playtest-continue-v8-v2.md)、[自然六景](docs/ground-warning-natural-review-v1.md)、[六景前后](docs/paired-six-scenes-review-v1.md)及[性能基线](docs/performance/native-current-baseline-v1.md)保持历史记录。它们绑定v8/当时源码，不把旧运动、伤亡、性能数字或190份输入声明冒称后续重测。旧v9的194输入以v9交接为准，v10-r2的196输入以v10交接为准，v11的200输入以v11交接为准；不重新启动旧18/36/20矩阵。

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

当前[完整玩法说明](docs/gameplay-guide-v10.md)与[战斗反馈验收](docs/combat-feedback-review-v2.md)：敌人全部基础伤害为v9的三倍；追击者新增锁向扇形爪击和短程扑击，均有无伤预警且不能穿墙；准心有黑色外描边。雷网矩阵电弧触发间隔延长50%，普通电弧不变。卡牌、开始/暂停提示和旧存档卡牌说明同步，历史测试和旧包不改写。

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
