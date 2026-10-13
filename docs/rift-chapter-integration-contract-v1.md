# R5正式第六关：现有事务上的薄接入

实施状态已更新：[真实Boss工厂/薄协调/Definition6/Ready6受控验证通过](rift-chapter-progress-review-v1.md)，普通两路线GPU正在运行，联合最终门未闭合。下方“下一切片”及“当前代码事实”是接入前规格基线，不再是当前实现；事务不扩写、真实保存/无7、两路线/恢复与F1–F4接受条件仍有效。

状态：下一实施切片契约。2026-10-12顺序修订：R4e full v2已确证中断，165套无最终汇总，不算通过。当前GPU/专项及独立PCK/release实际通过后可开始R5窄接入；R4与R5**共同等待R5终态的一轮全量与最终当前源PCK**，此前两者均不阶段签收或发完成邮件。没有减少/跳过全量测试范围，不改仍运行的冻结代码，不在受控事务通过前开放第六菜单。

## 当前代码事实与边界

`ChapterRunDefinitions`只有1–5；`ChapterSceneRegistry.READY_CHAPTERS`只有1–5。`RiftEncounterDirector`已有两必经、补给/风险、真实裂痕Owner与有限债务，Boss仍返回不可用/null。R4e验证的真实`RiftObserverBoss`尚未归属正式关卡。

`ChapterRun`直接启动检查definition/永久解锁，未检查菜单Ready；因此可以先在隔离存档测试真实第六协调，再开放菜单，不添加测试后门。菜单仍同时检查永久进度与Ready。共用`ChapterEncounterDirector`已经只接受当前Boss真实Health归零、death_resolved及随后离场；`ChapterRun.save_clear`先保存candidate、成功后替换永久进度。复用这些既有安全事务，不另造第六专用保存器、模拟通关或复制协调引擎。

## 有序小组

1. 实际Boss归属：先规范测试要求`_create_boss_actor()`为真实观测者而非旧Actor，保留合法地图半径56/唯一Health/唯一Director、入场免伤、旧模式API拒绝、活体假信号不造胜利。再启用RiftEncounterDirector的明确Boss工厂和正确三招标签。原R3两套“尚未制作”断言改为同等或更强的真实类型、状态门和未胜利断言；原日志保留，不删测试或允许任意Boss。
2. 正式协调：新`RiftChapter`只覆盖chapter6与`bind_rift_field`，薄Node2D场景；Definitions新增正确地图/director/四区满载/短束探针折射说明。独立`RiftChapterTest`先资源不存在RED，再测试真实UI/状态/构筑/地图/保存。此时菜单仍未Ready，不改Main。
3. 受控事务通过后，Ready加入6，`RiftChapterLaunchTest`证明Main实际第六入口、返回、音量/存档路径保持、活怪返回不记进度。再用普通引擎输入走补给与风险两路线，真实击败所有债务及Boss、保存6、新进程恢复全通，最后同源GPU/full/PCK/release。

## 必须接受的第六事务

- 自己PID命名且原本不存在的测试存档；空档直接启动第六必须拒绝且不写档。隔离初始化1–5只能证明本关先决事务，不得称完整六关链。
- 实际章节使用同一`ChapterRun`，种子521/733分别绑定真实地图/裂痕；两族有原生骨骼与血条。两必经场各两裂痕、风险四处，暂停/奖励/Boss战时不留下危险；通过实际奖励按钮选择构筑，不伪造领取状态。
- Boss由真实BOSS_READY才可启动，使用当前30骨/14片段的Observer和真实三招，不允许旧Overseer替身。入场、血条和短头标正确。
- 活体`died.emit`、错误章节`save_clear(5/7)`、未击败离场、玩家死亡、重复回调均不写全通；不得通过只把director.state置为CLEARED证明结算。
- 正式Health致死且Boss随后离场才走保存胜利路径，不用手写CLEARED状态。尸体播放清理单独验收，不能误称当前保存等待了整段死亡动画。保存被自己创建的空`.tmp`目录阻断时，原档SHA不变、progress未clear6且UI可重试；移除仅该空目录再实际按钮重试，读回1–6且campaign_complete=true、is_unlocked(7)=false。显示“六关探索已完成”，不显示第7关。
- 重复/错误结算不重写存档；重玩仅换种子保永久进度；重玩死亡及返回帐篷不删除全通记录。实际返回Main同存档路径，而非只创建一个Progress内存对象。

## 证据分层与最终欠项

受控Health致死用于保存/重入规范，不是普通输入胜利。普通路线必须实际移动/瞄准/射击、无改速/无敌/瞬移/直接damage作弊；跨进程恢复必须真实新进程加载该次产物。所有Godot串行，严格actualexit0/唯一正PASS/无ERROR和泄漏，保留RED；当前源与外部规范PCK逐SHA一致，作者/tests/doc不入PCK，正常UID导入。

R5完成后仍需F1正式开始/继续入口、F2新档真实1→6链（不能预写1–5）、F3多种子构筑压力与重玩趣味、F4六关密集视觉/文本/性能/许可/候选交付。R4e捕获发现缩镜地图外灰背景，F4必须实测并修复，不能用双方入镜元数据代替。全目标完成才聚焦提交/推送；不发布，不改用户真实存档，不安装/购买外部资源。

F4新增源核对：`NativeScrapperMotion.release_death`把尸体设为PAUSABLE，而`ChapterRun.save_clear`立即显示暂停的胜利界面；这可能让正式通关画面中的Boss死亡片段停在初帧。独立Runtime在不暂停的自然死亡验证不能覆盖它。保留全角色手动暂停冻结要求，正式胜利呈现必须另做实际GPU复现后小步修复，不在R5保存接线时凭假设改通用动画时钟。
