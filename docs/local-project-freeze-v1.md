# 本地技术冻结索引 v1

日期：2026-10-07。分支：`5分钟超载`。状态：**本地技术候选完成；不发布，外部验收待定。** 本索引对照[原完成合同](../tasks/supervised-completion-plan.md)，取代旧报告中已被后续证据解决的“下一步”，不改写历史实测或失败。

生产版本为 `d0995e8`；六景验收记录基线为 `54597cd6028610c91d73a7e796498668a812d430`。其后本片只收口文档，不改变游戏、资源、导出包、许可状态或测试实现。网页监督已取消，常规决策由Codex完成。

## 直接试玩

打开本机 `build/playtest/5分钟超载-current-v8/`，双击 `five-minute-overdrive.exe`。同目录PCK必须保留；可复制整个目录，不需要Godot编辑器。此目录不随Git克隆下载，不是公开发行包。

| 文件 | 字节 | SHA256 |
| --- | ---: | --- |
| five-minute-overdrive.exe | 109019648 | `b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0` |
| five-minute-overdrive.pck | 3006344 | `07181c736a115e7ec1e610a7b527c9aed3c97ba3cd158b511f72784d99bd4981` |

WASD移动、鼠标瞄准、左键射击、右键冲刺、Space暂停、1–6选卡、标题C继续、结算R重开。纯2D Q版、清爽玩具/薄荷农场、随机碰撞地图和加粗轮廓方向不变。旧45°/120向3D资源仅作历史，不再是制作合同。

## S1—S5 技术结论及继承边界

| 阶段 | 技术结论与证据 | 不包含的结论 |
| --- | --- | --- |
| S1 碰撞/驾驶 | 冲刺实际地形扫掠、隐身步行挡墙与恢复R/U分账已修复；定向红绿及真实输入证据见[阶段清单](../tasks/supervised-completion-todo.md)、[恢复修复](art/previews/environment/stealth-recovery-ru-review-v1.md)。随机探索/换向/脱困驾驶用于自然实跑，不再固定朝障碍持续走。 | 自动驾驶不是人工手感，也不是给正式玩家开启自动移动；不保证任意输入/地图永不卡住。 |
| S2 运动/脱困 | [3+18后期自然矩阵](late-natural-matrix-v1.md)和[36压力](pressure-n01-v1.md)分列，保留路程/净位移/受阻/失败原值。结合现行定向回归、自然整局，在已测范围接受地形与恢复修复。 | 旧压力35死亡/1预算结束不改写为平衡通过；后续敌弹半径曾实改，旧HP、伤亡和低进展数字不是当前版本重测。没有重跑18/36矩阵。 |
| S3 视觉 | [综合六景前后](paired-six-scenes-review-v1.md)：原a3824d1真实代码到当前、同资源/同fixture的180组条件一致关键帧，360彩色与360透明参考，四向、地形渐隐和连续受击；实际看图及独立复核无Required。[当前自然六景/首收集](ground-warning-natural-review-v1.md)另有242原图、7段连续片段和自然输入胜利/R，两类证据分列合并完成技术视觉范围。 | 不是自然同条件前后录像；不是逐帧手绘敌人动画、全距离Boss全身在屏幕、人工视觉/声音签收。计数、alpha或层级本身不等于可读性。 |
| S4 流程/地图/存档 | [三固定种子自然整局](current-motion-review-v1.md)均胜利/R，27687战斗步；[自然死亡及跨OS商店边界恢复](natural-run-flow-validation-v1.md)分列；[20实际地图](arena-runtime-matrix-v1.md)验证出生/碰撞/必要路线。到当前5个绘制/闪白文件改变不改这些地图/保存机制，有限继承。另有当前10907步自然胜利/R，六条正式存档前后不变。 | 不是20局自然通关或所有可行走点穷举。源码诊断与普通EXE验证分开；不拿旧受伤数字证明当前平衡。 |
| S5 回归/性能/本机包 | 当前190项生产输入与[受检v8/fresh副本](local-playtest-handoff-v8.md)逐hash一致。完整门74 Godot/173603断言、34 Python/250测试实际退出0继承；S3新增19测试另验退出0。[本机无读回基线](performance/native-current-baseline-v1.md)和普通EXE启动/自然失败/R/Space暂停/正常退出，加[普通EXE初始边界跨进程C恢复](local-playtest-continue-v8-v2.md)，构成有限本地交接。 | post-draw回调不是显示FPS、GPU耗时或最低硬件验收；普通EXE完整胜利/商店边界续存未测，完整流程由另列源码自然证据承担。不重跑未变74门。 |

原合同要求的局流程、已知阻断修复、技术视觉、说明/来源清单与本地交接已在上述范围闭合。独立完成合同审查结论：Critical 0、生产/测试Required 0；其唯一收口要求是本索引的验证和提交。完成数字技术候选不代签原合同第4项的外部验收，也不承诺商业发行就绪。

## 来源、原有脏资源与待验项

- [现行来源台账](art/reviews/runtime-source-reconciliation-v2.md)及[机器快照](art/reviews/runtime-source-snapshot-v2.json)记录12张运行位图；对应manifest、运行文件及声明源文件仍匹配。10项style-approved、2项环境draft，12项许可pending；全59份manifest仍57pending/2not-applicable/0approved。程序化摆动/缩放/翻转不冒称新增逐帧动画。
- v8包含既存未提交资源（包括环境障碍图与音频import设置），**不是干净HEAD克隆可重建的包**。原20项脏文件与另外2项较早性能证据保留、不纳入本片提交。没有新增未知来源素材或将现有pending提升为approved/final。
- [Bone Breaking来源记录](audio/overdrive-bone-breaking-source-v1.md)保留Pixabay平台、候选作品393836与作者DRAGON-STUDIO线索。用户不确定是否为原作品；本地裁剪MP3的精确对应/下载许可链仍unknown，不因候选页面或同作者而批准。没有下载或替换音频。
- `human_pending`：真人手感与视觉签收、声音听感、最低硬件、资源/第三方输入许可仍待验。公开发行未授权；不发布、不付费、不联系作者，不因这些外部项无限添加玩法。

## 本片核验与保留

最终只读核验：本机 `build/diagnostics/local-delivery/verify_final_freeze_v1.py` 实际退出0；190生产/54自然/15性能绑定无差异，EXE/PCK尺寸及hash一致；原137归档成员与补充829成员CRC/原字节一致，720原PNG/hash及180组条件通过；12位图35条来源记录（31不同路径）及59manifest状态未漂移；五入口文档108个本地链接有效。`guard_user_files.py after` 实际退出0，20保护路径差异=[]；文档状态4测试实际退出0。没有重新渲染或运行历史矩阵。Git差异及最终提交/远端SHA另由实际执行记录确认，不在索引中预造未来提交号。

大原始图/视频及18/36矩阵分卷留本机ignored；Git保留报告、完整hash索引和选图证据包，**克隆仓库不等于取得全部原始录像或EXE**。旧smoke/full-v1、严格门失败、工具失败及非零退出保留；新通过项只取对应新run，不删除或拼接失败画面。后续若生产/资源改变须重审受影响绑定；本索引不授权新功能、发行或许可自动通过。
