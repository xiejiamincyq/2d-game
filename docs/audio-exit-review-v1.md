# 音频退出生命周期修复与实际 EXE 短测

2026-10-07，5分钟超载，输入HEAD `e2308650de51f59d5741f95e700755bac707c0c0` 加本片改动。取消网页监督规则继续有效；不发布，不改变音频文件或许可状态。

## 结果与边界

所测正常关窗/重开路径的音频退出泄漏已修复。最终完整门真实退出0：**71 Godot套件170771断言 + 33 Python套件238测试**，Godot退出码、engine/stdout/stderr三路均检查。五个实际release EXE进程普通输入短测均退出0，未触发300秒watchdog，三路没有SCRIPT ERROR/ERROR/ObjectDB/RID/资源泄漏标记，六正式存档路径前后均absent，20原脏文件guard无变化。

这不是完整EXE六波/Boss/胜利验收、最低硬件、物理音频听感或授权证明，也不保证强制终止/系统断电能收尾。入场等内部状态的精确关闭覆盖来自单测，不能把GUI开场截图当内部状态探针。S2—S5整体继续待验。

## 为什么不是仅 stop + clear

前轮v4/v5实际EXE退出0仍有2个ObjectDB泄漏。定位用native编辑器引擎探针明确AudioStreamWAV/AudioStreamPlaybackWAV；只在_exit_tree停播/清引用的实验有状态pass但仍泄漏，未提交。

[Godot 4.7 AudioServer源码](https://raw.githubusercontent.com/godotengine/godot/4.7/servers/audio/audio_server.cpp)将停止对象交给混音线程退场，再由主线程清理；[Dummy驱动](https://raw.githubusercontent.com/godotengine/godot/4.7/servers/audio/audio_driver_dummy.cpp)也有独立混音循环。结合本片弱引用/运行结果，立即quit不给回收推进机会是本次失败的解释；不能扩大为所有引擎泄漏的根因。[播放对象API](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html)和[标准关闭管理](https://docs.godotengine.org/en/stable/classes/class_scenetree.html)使用原有公开API，无自改引擎/模板。

## 合同和实现

- AudioManager.begin_shutdown是幂等、终端处置，不是暂停；停止自有播放器，清stream/生成资源/播放器索引，不手工free子节点。重新入树也不会重启，重开创建新管理器。
- 每次播放用WeakRef登记，包括被语音池替换、先停止的对象；按帧清已释放项。is_shutdown_complete只有进入收尾且所有被跟踪对象释放才true，弱引用不阻止回收。收尾后所有播放入口拒绝工作。
- Main关闭标准auto_accept_quit，响应WM关闭通知：冻结世界、幂等请求、继续帧回收，真实单调时钟上限2000ms。完成退出0；超时明确ERROR并退出1，不隐藏警告或盲等固定时间。
- R重开也先回收；重开途中关闭优先，在清档/reload之前截断重开。收尾期间开始/继续/暂停、主要阶段回调与存档写入拒绝。成功重开仍按旧规则清进度、回标题；普通关窗不额外清档。
- runner新增stdout/stderr异步捕获，避免管道堵塞；三路做forbidden检查，pass只从engine一路计数，防重复。没有修改正常错误门。

## 测试纠偏和失败保留

原日志在证据ZIP内，不覆盖失败为绿色：

- audio-lifecycle-red-v3是真实缺失生命周期红测，退出1；最终AudioLifecycleTest 651断言覆盖循环音频/40次替换/暂停回收/重复处置/再入树。
- audio-lifecycle-rejection-red最初把“终端拒绝”断言错放在关闭前，**无效红测**；修位置后的red-v2退出1，之后守卫绿。runner-channel-red首次源码定位误匹配Python段，也不作最终合同证据；收窄Godot段后的red-v2才是有效红测。
- MainCloseTest最初auto-accept红、late callback红；restart-seam-red只是夹具尚无reload观测边界，不冒称正常游戏reload故障。最终35断言覆盖标题/入场/战斗/暂停/结果、重复close、restart等待时close、重复restart、成功/失败drain。
- MainCloseTimeoutProbe是真正2000ms超时负夹具，close/restart各子进程实际退出1；Python隔离APPDATA要求三路只有预期timeout错误且无其他泄漏。此Probe不是正常pass套件，不放宽runner。
- full-gate-v1运行期间另跑过共享测试存档夹具，且源有后续变化，**不作最终隔离验收**；v2旧日志门也不作三路干净证明。
- 加严后的v3真正失败：Phase19 pass marker后stderr有4个ObjectDB，原夹具仅等待两帧。改为生产生命周期实际回收后单项25断言通过；v4顺序完整门才是最终71/33通过依据。
- 增量技能引用的额外definition-of-done文件本机缺失；采用项目的测试/实际包/独立审查/聚焦提交标准，没有因此跳过门。

## actual EXE：普通输入，不是脚本注入

新包`build/playtest/5分钟超载-audio-exit-v2`，EXE109019648字节SHA `b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0`，PCK3005464字节SHA `103141f55d694ee0d2e7c719dad9f71bd448a12cb3dc558e3e3f8c776e6b06ac`。

fresh副本import/export均真实退出0。复制1215项（含测试），190过滤生产输入相较v5只有Main/AudioManager变化，逐hash重核仍一致；原用户脏资源随副本保留，不是clean HEAD/cache等价。Phase19夹具后改动被preset排除，不改变190生产输入。第一次导出核对误用v5完整copy清单比较190生产集而失败，源副本保留；修成相同过滤口径后重新建目录，旧中间包保留，不覆盖假称成功。

| PID | 预先声明音频参数 | 实际观察和动作 | 退出 |
| ---: | --- | --- | --- |
| 30424 | Dummy | 标题，Alt+F4 | 0，三路无错误/漏 |
| 1924 | 默认，无driver覆盖 | 开始1/6，Space真实暂停HP86/00:04，Alt+F4 | 同上 |
| 3628 | 默认，无driver覆盖 | 正常战斗HP46/00:08，自然败局HP0/00:12；R回标题；Alt+F4 | 同上 |
| 19104 | Dummy | 开始；最后关窗前观察仍战斗HP32/00:09；Alt+F4 | 同上 |
| 19472 | 默认，无driver覆盖 | 自然败局HP0/00:09，结果页Alt+F4 | 同上 |

“默认”仅说明CLI没有改音频驱动，不冒称已听到声音/验证声卡输出。所有APPDATA只作用于子进程。没有编辑器--script冒充EXE、秘籍、改PCK或伪造胜利。15原始1282×752 JPEG只来自游戏窗口，逐hash核对；最后观察与动作有时间差，不称精确关窗瞬间内部状态。

## 归档、审查与后续

[证据ZIP](audio-exit-evidence-v1.zip)：81成员（80数据项+index），759286字节SHA `5c43030b491a90eac059e6ec8f8436136604a862b4c41da6c0485724cb4efb6c`。覆盖原日志/源码/导出记录/五PID三路日志/15窗口原图及派生交接JSON；逐成员bytes/hash重读通过。没有APPDATA、实际存档内容、二进制、凭据或桌面全图。归档保存当时原字节；Git checkout行尾可能不同，JSON应按字段核验，不称跨行尾字节相等。

独立审查最初2 Required（runner漏stderr、restart/timeout覆盖）均补齐，复审Critical0/Required0；审查者只读，未自行跑引擎。Optional存档spy/循环音频stop→restart补测仍是额外建议，不伪装已覆盖。

下一轮回到项目收尾总表，优先完成S2压力矩阵/六景运动可读性与本地整局交付剩余项。Bone Breaking候选393836与作者回忆沿用[来源记录](audio/overdrive-bone-breaking-source-v1.md)，仍needs_review，不要求用户反复回忆，也不批准素材权利。
