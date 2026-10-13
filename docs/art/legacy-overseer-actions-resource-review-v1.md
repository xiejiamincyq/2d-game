# 独立监工动作资源阶段：已验证，尚未接入实际攻击

2026-10-12。[实施契约](legacy-overseer-actions-contract-v1.md)。新场景 `root_overseer_paper_v1` 保留本目标原创、已覆盖的23骨纸偶身体和五种基础动作，另制五攻击各 warning/attack/recovery 与 phase_transition，共21片段。资源可在Godot编辑，非逐帧位图；没有下载/安装外部工具或复制付费资源。

实际 `OverseerBoss` 仍指向原 v1 场景/旧 NativeBossMotion，本片只完成资源。下一必须做真实完成/取消观察与专用视觉适配器、实际Actor测试/GPU；尚未全动画接入、独立最终PCK或整个长期目标完成。manifest保持draft，不改冻结旧名册/基础资源。

## 验证

- `LegacyOverseerActionsResourceTest` 真实缺资源 RED（退出1）→新资源 GREEN555（退出0/唯一PASS/无错误或泄漏）。验证拓扑、21片段、严格检查点、可编辑外部库、至少三关节动作、骨骼属性轨道、取消复位与死后禁止再攻。
- 第一轮GPU未通过：横扫/砸地蓄力的少量像素超出已有视觉保留范围。保留[失败日志](previews/campaign/legacy-overseer-actions-resource-v1/f4-legacy-overseer-resource-gpu-v1.log)，未扩大物理碰撞或削弱检查；缩小这两种蓄力幅度后重烘焙。
- 第二轮GPU实际退出0：252关键姿态（21×3时刻×左右×无闪/0.35闪）、16新动作各30连续采样共480；每片段29次相邻像素变化，实际基础walk60帧59变化。252关键采样中的活体部分alpha/边缘裁剪/超出镜像视觉范围均为0；480连续采样只检查像素变化，没有逐帧边界检查，不宣称所有时刻都不越界。死亡尾段允许原有范围偏移，不把它计为活体取景通过。[报告](previews/campaign/legacy-overseer-actions-resource-v1/report.json)和六张分组图均已实际查看。
- 图中的横扫/砸地是身体动作资源，不是当前实际攻击的实时出手证明；`NativeBossMotion` walk由作者夹具驱动，仍不是新适配器。
- 正常导入退出0；RigCheckpoint44、NativeArtValidator36、BossCameraFraming1862、EchoChapter146专项实际退出0/唯一PASS/无错误泄漏。UID策略3项通过，新两脚本侧文件由正常导入生成；新资源测试已注册到全量runner，未为这个切片再跑全量。
- 七项GPU记录源SHA与当前相同，18份交付复制逐项SHA一致，[复制清单](previews/campaign/legacy-overseer-actions-resource-v1/copy-manifest.json)。冻结基础场景SHA仍为 `6c48a483e32445741aa7916d2159b9ffe64db161730f2c68d724ab5ad15f64ac`，基础库 `331c8b3d37f892107550ed032a4af6541d7c973ab72f696a39fae4e084bf2cfd`，原五基础片段不重写。

## 当前基线失败与取景夹具修复

`f4-current-full-v1`会话82501实际结束退出1：339 Godot套通过，只有BossIndicatorOcclusionTest失败（三条runner违规是同一套失败的退出/缺PASS/错误标记）；37 Python套282项通过。它不是“全量通过”，[原日志](previews/campaign/f4-indicator-finale-v1/f4-current-full-v1.log)保留。

旧取景夹具在INTRO直接 `_prepare_boss`，没有完成真实两次遭遇奖励，新 `prepare_chapter_finale` 正确拒绝。最初只补 claim_finale 仍失败，日志保留；正确修复改为真实生成两个遭遇、受控击杀、真实奖励UI/供给路线/整备领取关闭，再点击迎战。不改游戏源、成长状态字段或Boss门条件。受控击杀不是普通游玩，随后等待120实际physics帧，让脱离碰撞的死亡视觉自然结束，避免夹具死尸当作活怪画面。

最新headless2574和GPU2596实际退出0/唯一PASS/无错误泄漏。GPU九张960/1280/1920真实图片已逐张查看，方向牌未盖Boss身体；960/1280部分控制位置仍是身体部分可见与方向提示，非“所有Boss全体都完整入镜”。15份证据复制SHA一致，[取景报告](previews/campaign/f4-indicator-finale-v1/report.json)。只签夹具和方向牌几何，非整项目/全部HUD/正常通关/真人试玩。

最终全量、当前本地候选与新同源六关链继续保留；等专用适配器、六PNG退役、三实际pending位图原创替代完成后集中执行。没有中间提交/推送、邮件或公开发布。

独立只读审查未发现这两个增量的Critical/Required，确认失败与通过、资源与实际Actor范围均有区分。取景报告列出的是局部12项依赖，不是完整闭包（本次使用的TestSupport与实际Director还不在局部清单）；最终全源银行必须覆盖它们。该边界和连续边界采样增强留给下一实际Actor验证，不以局部SHA替代最终同源证明。
