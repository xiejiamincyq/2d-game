# 音频退出生命周期片：所测范围已验证

2026-10-07补充：下文是开始时的冻结事实和原计划，不改写历史失败。已按序实施，最终71 Godot170771断言+33 Python238测试三路门退出0，5个实际EXE短测全部干净退出0；190生产输入及20原脏文件核对，独立复审Critical0/Required0。完整范围/旧无效测试/真实失败保留见[验收报告](../docs/audio-exit-review-v1.md)和[交接v6](../docs/local-playtest-handoff-v6.md)。整局与S2—S5整体仍待验。

现行HEAD `e2308650de51f59d5741f95e700755bac707c0c0`，仍在5分钟超载，不发布。上片HUD显示修复已验证/推送，音效候选393836/作者线索只登记，不改媒体或许可状态。

## 已冻结事实

- 实际v4首进程以及v5开场关闭均真实退出0，但console/stderr有2个ObjectDB泄漏，干净退出失败。旧两次verbose短probe未复现不能覆盖失败。
- 本机 `build/diagnostics/exe-window/window-20261007-v1/entrance_exit_probe.gd` 在编辑器引擎正常Main入场12帧退出：headless对照未泄漏，native对照明确4例：AudioStreamWAV×2 /AudioStreamPlaybackWAV×2。这是定位用编辑器夹具，不是实际EXE新的通过记录。
- 新 `scripts/tests/AudioLifecycleTest.gd` 尚未进入runner/提交：实际生成start/BGM/laser三个播放，并检验退出后播放器/资源引用释放。原实现真实red退出1。初版测试因失败后没有free已detach fixture而另外制造69例orphan；修测试清理后的red-v2仍失败且6个音频对象，原日志全部保留。
- 一次实验只增加AudioManager `_exit_tree` stop+stream=null+clear：25状态断言有pass marker，但仍6个ObjectDB泄漏，严格退出门失败，不能称green。该生产实验已撤回自己的12行，完整源保存本机 `AudioManager-stop-clear-experiment.gd`，未覆盖用户文件。red测试仍作为未完成工作保留，不独立推送。
- [Godot4.7 AudioServer实现](https://raw.githubusercontent.com/godotengine/godot/4.7/servers/audio/audio_server.cpp)：stop_playback_stream标记FADE_OUT_TO_DELETION，音频线程混音后才能进入待删除状态，再由主线程清理。finish先停止驱动。与[Dummy线程实现](https://raw.githubusercontent.com/godotengine/godot/4.7/servers/audio/audio_driver_dummy.cpp)共同说明stop不是同步完成回收。由此推断立即退出太晚提供清理时隙；仍须实际验证，不能仅源码推断签收本项目根因。

## 下一片顺序

1. 先以现有原始native失败及修过fixture清理的red测试为基线，不反复为了绿色重跑。补“停止后弱引用仍存活/最终释放”的状态证据；测试不得以固定跳过warning、关掉音乐/驱动声音或放宽全门取巧。
2. 在AudioManager自身实现明确且幂等的shutdown：收集播放对象的WeakRef，停止全部自有播放器、释放stream/生成资源引用，不永久删除音频、不改正常声音，不手工free由Node拥有的孩子。明确退出/重新入树合同，避免无意破坏未来调用。
3. 验证并设计Main正常Windows关闭入口的有界异步收尾：先停止音频，让真实混音/主线程继续回收，再退出。复用Godot标准关闭通知，不碰系统安全设置；单次/重复关闭必须幂等，暂停/入场/战斗/结果/标题都能退出。等待依据是弱引用释放而非盲目延迟；设置短的明确上限，超时真实报失败，不默默压警告。先写相关红测再实现，防止关闭期间重新开始/重开/继续的竞争。
4. 重新跑相应单测及全门，三路日志同查；fresh副本重导出新目录，不能沿用旧PCK假称更新。实际EXE普通窗口覆盖上述关键退出状态和R重开，UID/源hash/二进制/PID/真正退出码/正式六存档/20原脏文件核对；编辑器probe不冒充EXE。
5. 独立代码/封包审查，准确交接与失败记录，完成的聚焦变化commit/push当前origin/5分钟超载并Gmail发给me。不勾S2—S5整体、整局/声音听感/最低硬件/素材许可。

此计划不是已完成实现、已通过关闭门或新外部批准。现有首次失败警告始终保留。继续自主执行，无网页监督。
