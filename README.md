# 废土清剿协议

当前六关原生骨骼工程与验证已完成，见[F12逐需求验收](docs/campaign-final-f12-requirements-audit-v1.md)。[Boss公平性与二关机关](docs/campaign-boss-fairness-v1.md)：热喷口0.70秒锁点预警、正式热区10/10/16，主线17伤害技能无普通撤离路线则取消；兼容监工终态回调漏洞已修复。本机最新F12可双击 `build/playtest/native-campaign-f12-terminal-safety-v1/five-minute-overdrive.exe`，同目录PCK必须保留。[F12验包与边界](docs/campaign-f12-package-review-v1.md)。完整361 Godot/340162、38 Python/290、真空档六链/风险双恢复、同包23套7020+GPU12、三尺寸密集复算均通过；最终Git交付以本对话记录为准。旧候选保留，不混配PCK，不公开发布。

使用 Godot 4.7 制作的 Windows 桌面纯2D Q版肉鸽战斗游戏。“5分钟超载”源码采用原创墨线纸偶、Godot原生Skeleton2D动画与六关逐Boss解锁制，每局随机障碍地图。首关保留8%血包/10%小护盾及每场保底，根刺0.8秒预警/错峰。当前24身体/27动作库与既有签收逐SHA一致；旧验证保留历史版本边界。用户已明确确认F11正常移动、四向瞄准射击与暂停恢复，F12未改对应输入源。工程完成不等于真人通六关、最低硬件保证或公开发行。保留旧波次兼容模式；旧45°/M2仅作历史。

## 当前源码：六关探索

在Godot导入本工作树的 `project.godot` 后按F5。主界面“开始探索”从新进度进入第1区，已解锁时“继续探索”进入最高已解锁区；“六区档案”可选择已经解锁的关卡。击败该关真实首领并成功保存才永久解锁下一关；第6关完成后不会生成第7关。每次重新探索生成新地图种子，局内成长重新开始。永久进度不保存关卡中途状态。

当前机制见[六关玩法说明](docs/campaign-gameplay-guide-v1.md)。[旧六关链](docs/campaign-fresh-chain-acceptance-v1.md)及[构筑矩阵](docs/campaign-build-uniform-matrix-v1.md)绑定各自历史源码；不能代替最近地图、资源退役与音频更新后的最终同源验收。未公开发布，不把自动驾驶测试当真人试玩。

[当前收尾状态](tasks/campaign-final-live-state-v1.md)、[原生角色限定签收](docs/art/reviews/final-native-production-acceptance-v1.md)、[开始页轻动效](docs/art/reviews/paper-menu-motion-v1.md)。历史manifest/旧失败保留，pending来源素材不假批；正式消费者不使用这些待核素材。

最新六关本机候选为上方F12；F10/F11及更早候选仅供历史对照。不需要编辑器，不混配旧PCK。本机文件不随Git克隆分发，未公开发布。[首关修正历史](docs/campaign-first-chapter-fairness-v1.md)。

[首关真实密集性能](docs/performance/chapter-ordinary-v1.md)记录三分辨率实际风险路线与首领通关、完整慢帧/硬件/采样范围；不是冻结演员的视觉负载，也不是全六关或最低配置性能承诺。

## 历史原生骨骼/前四关本机候选（不含后续六关更新）

如需对照旧阶段，打开 `build/playtest/5分钟超载-native-a5-v1/` 并双击 `five-minute-overdrive.exe`；同目录 `.pck` 必须保留，不需要编辑器。这是当时只有前四关的冻结候选，不是当前六关版本。不要复制自动测试的隔离进度到玩家存档，也不要混用不同候选的EXE/PCK。

[第四关A5交付与验证](docs/art/archive-chapter-review-v1.md)：两条完整正常引擎输入路线实际胜利并永久解锁5，各新进程恢复通过；251 Godot套件/36 Python套件全量、当前同PCK25专项/3325检查及实际EXE Main120通过。新候选未覆盖旧v13，非公开发布、非真人/OS输入或全六关/密集性能/全许可验收。后续[第五关回声墓庭](tasks/echo-fifth-chapter-plan-v1.md)。

## 旧版v13直接试玩（保留，不含本次原生骨骼/章节）

旧冻结本机预览 **v13**：打开 `build/playtest/5分钟超载-current-v13/`，双击 `five-minute-overdrive.exe`；同目录 `.pck` 必须保留。不需要编辑器或运行测试。旧v12/v11/v10-r2/v9保留，请勿混用PCK。

v13为所有存活小怪添加常驻血量条，随真实血量缩短，头顶感叹号移到血条上方；大型怪和Boss原有显示规则不变。87 Godot套件、35 Python套件通过，实际PCK三套162断言通过；原生七类敌人满血/半血摆拍用于检查布局，不当作自然整局验收。[v13交接](docs/local-playtest-handoff-v13.md)。骨骼动画仍是[待批准的制作方案](docs/enemy-skeletal-animation-assessment-v1.md)，本轮未替换动画或安装MCP。

v12按玩家反馈改为小怪头顶黑边感叹号、短前摇和单道攻击线；提前恢复追击并补偿冷却，不增加既定攻击频率。投掷落点和大型怪/Boss必要范围提示保留，三倍伤害、hitbox和玩家输出不变。86 Godot套件、35 Python套件通过；实际PCK的短节奏31断言、扑击碰撞21断言通过。已录制真实Main受控遭遇的15秒动态预览，真人手感仍待确认。[v12预览交接](docs/local-playtest-handoff-v12.md)。

以下v12及更早版本的验证保持历史记录，不冒称v13自然整局验收。

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
3. 打开项目后按 `F5` 运行正式主场景 `scenes/Main.tscn`；不要用美术诊断场景代替正式入口。

## 操作

- `WASD`：移动
- 鼠标：瞄准
- 鼠标左键：持续射击
- 鼠标右键：向准星方向冲刺并对路径上的敌人造成伤害
- `Space`：暂停或继续
- `1`–`6`：选择结算界面的卡牌
- 六关主界面：按按钮继续最高已解锁区，或从“六区档案”选关；通关/失败页可“重新探索”或“返回帐篷”。
- `C` / `R`：仅旧版波次兼容模式的继续旧局/结算重开快捷键，不是六关中途续玩。

## 游戏内容

正式六关的流程、敌族、机关、首领与保存规则以[当前六关玩法说明](docs/campaign-gameplay-guide-v1.md)为准。以下v10/七类敌人/六波次描述属于旧版兼容玩法；保留其历史验证，不当作当前全部内容。

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
