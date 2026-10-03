# 自然整局输入验证 v1（2026-10-04）

本片用于补足既往组件/人工构造边界测试不能证明自然流程的缺口。预注册见[计划](../tasks/natural-run-validation-plan.md)。不发布，不把本报告当成整项目、视觉或人工验收。

后续进展：独立OS进程继续和自然败局已在[恢复与败局验证](natural-run-flow-validation-v1.md)单独完成。本页下文的“尚未验证”指本页原提交当时的范围，不代表最新状态；三次整局记录仍绑定原v3提交，不能用后续改动的当前源码冒充历史SHA通过。

## 实施与边界

`NaturalRunMain`只预先设置隔离存档、初始随机种子和静音；世界构建、入口/状态机、导演、角色、Boss、升级、伤害与CombatFeedback均继承正式Main。输入pilot只调用Input动作和Viewport的正常输入事件；没有改血量、强制击杀、跳波、删怪、传送、跳动画、补金币或关闭顿帧。

策略使用全世界可观测敌人/拾取和地图导航，因此不是人类体验、操作可达性或公平AI代理证明。固定60物理Hz、max-fps60，clock标记为调用方声明；记录真实墙钟/物理delta/time_scale，不用fixed-fps模拟当作实时时钟通过。

第一自然结算保存后，同进程重载诊断场景，再通过正式C入口继续，核验保存文件、地图、击杀和金币。商店通过1—6键和Close按钮焦点+Enter交易。胜败后通过正式R入口重开，核验标题/无Continue/隔离存档已清。尚未验证独立OS进程退出后继续；没有伪造暂停菜单里的“返回标题/退出”选项。

诊断场景置于 `scripts/art/`，沿用既有导出排除，不能把依赖被排除脚本的诊断tscn混入正式包。

## 确证缺陷：商店卡牌不被存档接受

正式UpgradeSystem已有 `drone_pierce`（automation/上限1）和 `shield_capacity`（automation/上限3），RunSnapshotStore的CARD_LIMITS缺失它们。新目录全覆盖红测实际失败：`current catalog card drone_pierce cannot be saved`，退出1。最小生产修改只补两项精确映射，不放宽未知ID、family、等级上限、不改存档版本或既有迁移。

SnapshotTest为25张当前目录分别做接受、实际写/读、越上限拒绝、错family拒绝，另拒绝未知已购和未知offer；既有快照损坏、运行态排除、继续和旧卡迁移测试保留。最终计数/完整回归以本报告末节实际输出为准。

## 无效尝试（全部保留，不算正式通过）

- 最早root Window注入鼠标、随后SubViewportContainer夹具未被角色读取：新严格瞄准断言实际首步失败。引擎会根据viewport所在section决定鼠标来源；改为非SubViewportContainer父节点的独立SubViewport + TextureRect展示后，实际请求/读取位置一致，180步通过。依据[Godot viewport实现](https://github.com/godotengine/godot/blob/master/scene/main/viewport.cpp)的get_mouse_position分支，具体兼容性以本机实测为证，不声称master源码就是本机二进制版本。
- `smoke-01`在补瞄准断言前曾打印valid=true，不能算可靠射击证据；`smoke-02/03/04`invalid_aim已保留。
- `flow-smoke-01`3600步可靠短测走到第二波，但策略持续巡角不能接近最后的远程尾怪。正式预注册策略改为只剩<=5怪时接近，仍只输入、不改敌人。
- `formal-20260908-v1`2228步清场收集期间导航为零、请求瞄准点等于角色，aim_dot=0。空瞄准右移500px的红绿测试补齐，严格0.9999阈值不放宽。
- `formal-20260908-v2`8460步实际出现胜利，但R按下同步移除旧视口后继续发释放事件，原日志报`!is_inside_tree`。其valid=true不是通过。v3先验证视口仍在树内，三种子从头复跑。
- NaturalRunPolicyTest最早check()失败后仍执行quit(0)并打印PASS的问题已在正式使用前修正为累计失败、仅成功打印PASS、失败退出1。真实行为红日志为policy-red，而非把最早误报作为成功。

外部Python检查同时要求报告、真实输入/瞄准/时序/存档/清理和原日志。日志有错误或泄漏、标记缺失/重复均拒绝，不能只相信工具自己的valid字段。checker-log红测和绿色9项Python测试已执行。

## 三种子实测（同一v3绑定源哈希）

| 初始RNG种子 | 实际地图种子 | PLAYING步数 | 游戏统计秒 / 首至末样本墙钟秒 | 胜利HP / 全程最低HP | 击杀 |
| --- | --- | --- | --- | --- | --- |
| 20260908 | 426363786 | 8980 | 139.188 / 168.927 | 120 / 93 | 603 |
| 20260909 | 2573397633 | 9216 | 142.467 / 173.362 | 100 / 88 | 603 |
| 20260910 | 4177793213 | 10624 | 166.400 / 196.330 | 120 / 100 | 603 |

三个独立进程均：六次自然结算/关店、Boss前结算与登场、自然Boss击败/最终清场、胜利Result、正式R重开回到START。首结算C继续均通过，真实默认/测试存档含tmp/bak哈希不变，owned-tree orphan最终0，观察到time_scale低至0.05。生命超过100来自正式商店health卡；未注入生命。三次输出日志均退出0且无错误/泄漏；外部checker逐条通过，共28820战斗步。三次不意味着随机轨迹确定性或独立审查通过。

逐帧JSON、所有早期无效尝试、红绿日志及完整回归日志将归档于 `natural-run-evidence-v1.zip`。原始正式JSON SHA256：

- 08：`e435cb6256b0d5e5bfeb4a06b246b4cb97b2feba8aefb4d1a8942b0c131121ef`
- 09：`6581543792dc6ad9c0b957f8723bfe89f65cc6dbb54ba94084cb2ff6341ac679`
- 10：`2cd34c6f5935616d58390de1b884589db8818ccd7e69abaf70ba9de0a664f7ab`

复现（每次使用从未使用的run，顺序独立运行三个种子）：

```powershell
godot_console --headless --path . --audio-driver Dummy --max-fps 60 --script res://scripts/art/VerifyNaturalRun.gd -- --seed=20260908 --run=fresh-unique-08 --steps=36000 --clock=realtime
python -B scripts/art/check_natural_run_report.py build/diagnostics/natural-run/fresh-unique-08.json --log original-run.log
```

第二条中的original-run.log须是第一条保留的原输出；源哈希比对针对当前工作树，后续修改后应检出原提交再检查历史记录。首次诊断不要直接启动NaturalRunDiagnostic.tscn，它缺少隔离metadata时会拒绝启动。

## 当前未完成

整个S4保持未完成：自然败局、独立OS进程续存档、20实际地图种子、真实连续渲染与六景、人工手感/最低硬件均不得由headless结果代签。此次为根代理自审，未取得新独立最终审查，不能冒充独立复跑。

## 最终回归与交付

最终完整预推送实际退出0：56 Godot套件166418断言，27 Python套件168测试；资源导入、暂停所有权、白空/暂存检查和密钥扫描通过。单项失败/早期错误仍保留于归档，不能把整个ZIP里的全部日志称为绿色。

[证据ZIP](natural-run-evidence-v1.zip)共2412868字节，SHA256：`8e81295e40dfead1301dcdd4021c0df1d01235652b71fa3462a339f637345824`，已只读确认三份正式JSON/原日志及最终预推送日志实际存在。只包含新生成诊断报告/日志，不含真实用户存档内容、凭据或发行包。

自审结论：唯一生产行为差异是存档允许现有两卡；原Gameplay条件、legacy兼容和拒绝规则保留。输入/状态工具在导出排除目录，孤立世界与保存路径在初始化前绑定；后台运行串行，无残留测试进程。没有新增依赖、删除旧证据、改变远端权限或加入无关脏图/音频。下一片优先独立OS进程续存档和自然败局/连续实际渲染，禁止用本片测试数字代替视觉签收。
