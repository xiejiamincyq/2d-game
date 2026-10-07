# v8 本机试玩候选交接（不发布）

2026-10-07。双击本机 `build/playtest/5分钟超载-current-v8/five-minute-overdrive.exe`，同目录PCK必须保留。不需安装Godot或打开测试。目录仅在本机，Git没有EXE/PCK；旧v7保留。

v8包含当前地面预警/非碰撞友弹拖尾分层修复，不改变既定纯2D Q版方向、枪附着、地图、碰撞或伤害。构建基线HEAD d0995e8，但包含原有脏资源，不称干净HEAD克隆可复现。fresh副本1226输入/190eligible；与自然登记和现行工作树190逐hash一致，相对v7恰好5生产路径改变。导入39604/导出13292均退出0，无超时，三路日志错误/泄漏空。

| 文件 | 字节 | SHA256 |
| --- | ---: | --- |
| five-minute-overdrive.exe | 109019648 | b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0 |
| five-minute-overdrive.pck | 3006344 | 07181c736a115e7ec1e610a7b527c9aed3c97ba3cd158b511f72784d99bd4981 |

## 普通EXE实际窗口门

两次Popen OS进程使用真实release EXE/PCK与默认音频，仅child APPDATA/1280×720/log；没有script、注入驾驶、写游戏状态、复制真实存档或Dummy音频。

- 第一PID25780：Enter启动；误按Esc不暂停，静止00:09正常死亡，保留失败/R标题图；R再开/Enter启动，实际Space暂停。HP31、00:07、剩余41在相隔56.283秒的两次截图保持，正常Alt+F4退出0，三路错误空、正式六存档及EXE/PCK指纹不变。
- 第二PID32912：只复用前者诊断APPDATA。窗口读取两次报`foreground window did not report a process id`，没有输入C、没有继续/死亡/R/正常退出证明。遵照Computer Use恢复边界停止；按已登记PID核对精确v8路径后Stop-Process清理，退出4294967295，launcher退出1，clean_exit_gate=false。不是游戏存档损坏证据，也不算通过，不反复重试或绕过工具。
- 预登记[验证计划](../tasks/current-v8-final-validation-plan.md)中的Escape是执行前误判，原记录冻结保留；正式暂停键为Space，[输入源与README](../README.md)一致。上面的失败与正确动作分列，不覆盖初次结果。

这不是普通EXE整局胜利、跨OS继续通过或人工听感验收。旧真实跨OS源码诊断与普通新EXE窗口验证分开；窗口目标本次均是实际v8路径，无其他游戏截图。

## 阶段证据适用表

| 范围 | 本轮判断与证据边界 |
| --- | --- |
| S2运动/脱困 | [3+18自然矩阵](late-natural-matrix-v1.md)未复现长期堵截，均正常完成；[36压力](pressure-n01-v1.md)保留最长3.43s低进展和死亡，不当永久卡死或平衡通过线。之后地形/恢复运动代码未因5绘制改动改变；当前三局、此片自然及性能自然均完整结束，现行定向回归保留。已证地形穿透/恢复阻断已修复，在已测范围可接受；不保证所有地图/输入无堵截。较早敌弹半径实改使旧受伤/死亡数字不能作为当前版本36次平衡结果，不要求为画层重跑整个矩阵。 |
| S3视觉 | [40真实组件严格配对](ground-warning-review-v1.md)+[当前六景after/首收集](ground-warning-natural-review-v1.md)支持本次层级修复。玩家/主要危险可辨；未发现新增Required。原六景连续完全同条件前后项仍未完整产生，明确未勾，不能把after+组件改写成六景严格配对。 |
| S4局/地图/保存 | [当前三局](current-motion-review-v1.md)、[历史自然败局/跨OS恢复](natural-run-flow-validation-v1.md)、[20地图](arena-runtime-matrix-v1.md)与当前自然胜利分列。Main/地图/存档格式未因5绘制文件改变，结构/运动/保存合同可按未变来源继承；历史运行不是本轮重跑。当前同进程结算C和R已验，普通v8跨OS继续仍未验。 |
| S5回归/性能/冻结 | 同源完整74 Godot173603 +34 Python250门实际退出0沿用，不重跑未变套件；[当前无读回本机基线](performance/native-current-baseline-v1.md)、fresh副本/190输入/EXE/PCK、第一普通EXE退出已绑定。第二普通EXE门不通过，整体未宣称完成。 |
| 外部/来源 | human_pending、声音听感、最低硬件、环境draft、既有未知许可保持；[Bone Breaking候选作品/作者](audio/overdrive-bone-breaking-source-v1.md)不等于本地文件精确对应或许可通过。没有新增不明资源、下载音频或发布。 |

当前有限未完成项：S3原六景严格配对记账、工具可用时普通v8跨OS继续，以及最终整体冻结裁决。不得重新启动已完成18/36/20矩阵或增加玩法来代替这几项。

## 归档

[输入/构建/两OS进程/截图hash摘要](local-playtest-handoff-v8.json)；[小型交接证据](local-playtest-evidence-v8.zip)：33成员、312421字节、SHA256 `067c19f95f93bff07b2e11a4d55060c944dd651990f226eba173121af26371ba`，CRC/逐成员原字节通过。含5张实际v8游戏JPEG及其窗口/时间元数据、两进程实际终态、fresh输入和导入/导出日志/launcher，不含发行文件、APPDATA存档或凭据。观察工具错误原文本另保留在本对话及本说明，不伪称游戏日志报错。
