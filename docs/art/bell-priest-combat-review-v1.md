# 钟骨司祭 E4b：实际骨骼战斗与视觉审查

2026-10-11；`5分钟超载`，整体 goal active。**E4b实际战斗阶段完成。** 原创实际 Actor、唯一导演与三招、连续 GPU/地图 HUD、取消重入、独立同PCK及release通过；UID修复后的最终全量v2实际退出0：277 Godot259296断言、36 Python272测试。正式 READY_CHAPTERS 仍 [1,2,3,4]，第五关正式入口/两路线正常胜利/保存解锁6归 E5，不能用本记录代替。

## 实际角色、判定与所有权

`EchoBellPriestBoss` 使用独立原生26骨v2/14片段，实际圆半径56、根 scale 1、Health10800；Health70%/35%驱动阶段，Motion只读取唯一攻击导演的动作/阶段/时间。继续已授权原创墨线纸偶、哑光旧铜/暖纸、短头顶感叹号；没有新位图、提取付费资源、第三方运行库或全屏特效。v1、冻结名册、旧可玩候选保持；仅使用此前新作的原生资源，不把旧PNG晃动当骨骼。

钟槌实际140px轴/12px胶囊/36伤害，双坠各真实挂点锁定旧目标、900px/s/180px往返/整对30一次尝试，冠钟三个节拍各两枚有限音钉、440px/s/18每奏一次尝试。准备时间分别0.24/0.22/0.24秒；余下时序、薄墙/世界完整身体边界和普通物理条件见[实战进展](../bell-priest-combat-progress-v1.md)。原有四个普通输入专项覆盖第一阶段三招和第三阶段加宽冠钟，48延迟躲避/48站立命中对照，玩家仍235速度/16.9圆身体/100血量，没有灌无敌、加速、缩身体或施放后传送。它们不是第五关完整通关或真人试玩。

清理重入先保留真实语义失败 `bell-priest-cleanup-reentry-red-v1.log`：远程 newborn 直接取消后仍被追加、隐藏旧弹体的同步回调能重新启动钟槌、切阶段时仍能重启。仅在专属导演加入清理锁、设置过渡状态先于清理，并在真实 add_child 回调后复核 newborn 有效/未排队删除，保留绝对2坠/6音钉上限。233项生命周期专项通过；新增覆盖出生直接取消、visibility_changed 中重新施法、真实Health切阶段中的重新施法，没有删除旧死亡/暂停/离场/隐身断言，也没有改公共碰撞或玩家数值。

## 当前 GPU 与已看过的图

真实 gl_compatibility 渲染，非 headless 假图。Actor GPU v5退出0、唯一 `TEST PASS: RenderBellPriestCombat 518`：36关键姿态/左右/闪白、180实际ACTIVE连续样本、六个0.75镜头样本。只为独立alpha测量隐藏玩家/地面提示/弹体，不冒称这些画面有完整游戏HUD；actual Actor/导演始终真实。所有身体样本partial alpha 0、视口边缘0、声明范围外0；缩小只改Camera2D，实际身体/碰撞仍不变。

连续30帧的29对相邻像素，左右钟槌各28对、双坠各20对、冠钟各28对发生真实变化；真实骨骼Marker跨度约33.75/70.06/10.28px。与此同时施放时锁定世界起点/方向不变：关节动作可动，伤害几何不追踪移动挂点。

Actor v2失败由alpha夹具冻结弹体导致它们不能自然到期、真实数量上限拒绝下一招；修为独立采样间明确取消，不松开上限。v3又揭示预览以请求秒数冒称真实冠钟时间：导演为了避免卡顿补发会在节拍截断delta；修为读取实际 action_elapsed 的有界取样，不改运行时钟或放宽状态断言。v4身体矩阵通过512但未包含相邻像素变化门；最终v5另加真正像素变化/Marker运动，518通过。所有失败文件保留，不能冒称是已修复的游戏运行缺陷。

地图 GPU v2退出0、唯一 `TEST PASS: RenderBellPriestBattlefield 127`：真实 EchoMap/玩家/Boss/四挂点/既有 Health-bound BossHealthBar，三招各warning/active/cancel/death，共12帧；冠钟实际低Health第三阶段。头顶短感叹号像素存在且攻击后消失，真实阶段和血量一致，取消清空有限弹体，实际致死后HUD隐藏。远程先运行八个真实物理帧再取图，不把重叠出生节点数当作可见弹体。v1说明文字暗、受控第三阶段冻结受击闪白的预览问题保留，v2恢复真实物理让闪白自然结束；没有改身体alpha。

本轮实际看过全部21张最终PNG：Actor三张左右姿态表/六张小尺度，地图十二张。原创身体、钟舌落击/双臂链坠/冠钟倾转与取消回收可辨，短提示和克制投射物不覆盖身体；这里只验这些受控状态，不声称持续混战或整关可玩已通过。

交付[三招Actor与小尺度](previews/campaign/bell-priest-combat-v1/actor/report.json)、[地图/HUD/取消/死亡](previews/campaign/bell-priest-combat-v1/battlefield/report.json)分别冻结20/42实际源SHA；九PNG+JSON十文件、十二PNG+JSON十三文件逐SHA复制一致。源报告保留自己的真实build路径、检查数和受控范围，未篡改为正常通关证明。

## 全量、独立包和后续门

最终全量v1实际退出1：277个Godot套件全部通过、35个Python套件通过，但导入之后新写的 `EchoBossEncounterTest.gd` 缺少自动UID，UID套件失败；真实输出封存于 `bell-priest-combat-final-full-v1-tool-receipt.log`。引擎正常导入生成UID，原UID规则三测试通过，不手工编造UID。该次仍是失败的整体验收，不把旧进展版277/258891的数字冒称当前最终结果；还需最终全量新终态。

独立包 `bell-priest-combat-complete-pack-v1.log` 实际终态退出0：49规范专项/29615断言、Main120；四个Bell普通物理夹具沿用规范runner的12000帧上界，第三阶段子夹具相对引用同目录的精确母夹具，制作/测试目录继续排除，没有--path工作区回退。外部原规范315资源核验亦退出0，真实26骨/权重/rest/14片段/挂点及取消复位可加载，作者manifest/Bake不可访问；同包6814400字节、SHA256 `a00729072f52fd026a239dc42880d78d1970ad7ffe76e103e52215b6f5e1aed4`，前后不变且小于30MiB。51份包外规范GD/支持夹具逐SHA一致，52日志无ERROR/TEST FAIL/资源或RID泄漏。

`bell-priest-combat-release-v1.log` 实际退出0、RELEASE CHECK PASS，Windows PCK6814400字节、独立Main120。只是本地包启动门，没有新试玩EXE或公开发布。当前20/42 GPU源SHA仍一致，冻结名册review/coverage、旧A5 EXE/PCK及Bell v1场景/动作六SHA与旧证明一致。最终全量v2真实日志 `bell-priest-combat-final-full-v2.log`，实际退出0、唯一TEST RUN PASS，277 Godot259296断言、36 Python272测试，313套件正向收据；无ERROR/TEST FAIL/资源或RID泄漏，39实际源SHA跨整轮不变。日志SHA256 `304bfeb511a546083fcbae7b2e0bf5de5e06af67443f39e78e5f9fc48a8ae61d`。先前v2运行中快照和v1失败收据均保留，不回写为通过。

阶段完成门：实际战斗/普通单招物理、原生GPU连续动作与HUD、独立包与资源隔离、最终全量/元数据均已通过。仅勾E4b，不晋级全套素材final，不声明第五关或六关完成；下一步按已有语义RED接实际Echo遭遇Boss。

Gmail阶段完成通知已发送一次，实际message id `1a129cd8f0e237dc`；此前E4a/E3等通知未重发。

下一E5真实首领接线测试已经产生语义RED：`echo-boss-owner-red-v1.log`退出1，明确真实钟祭尚未绑定第五遭遇导演；不是解析失败。测试还要求完整两必经遭遇/补给路线、实际Boss类型/地形/HUD消费者之前的所有权、拒绝伪死、真正死亡仅发chapter5、有限危险清理与活Boss离场失败。该测试尚未绿色或登记全量；不将它当第五关就绪。

五轴自审：专属小组件承担几何/有限时钟与清理锁，不把特例塞Main/公共碰撞；重用原生Motion、既有短头标/HUD和规范投射物扫掠。循环/查询/弹体有界，像素逐点扫描只在离线制作脚本；不把此检查当密集性能门。没有新增外部来源/密钥/安装、未动真实保存或旧候选，不晋级素材final。全局目标、最终六关流程/长期难度/许可/性能仍未完成，当前不提交或推送中间节点、不公开发布。
