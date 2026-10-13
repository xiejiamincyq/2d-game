# 第六关接入：联合阶段已验收

最新实际终态见[联合阶段验收](rift-chapter-joint-acceptance-v1.md)：all实际0/315 Godot/324648、36 Python/274，当前独立包及两普通路线/恢复闭合，阶段邮件已发。随后[F1正式入口](campaign-primary-entry-review-v1.md)专项/GPU/当前新包通过。F2–F4和整个goal仍未完成；下文是第六开发期间的历史记录，不能把旧运行态当当前状态。

2026-10-12，分支`5分钟超载`。当前正式薄协调、定义与菜单Ready6已实现；这不是整目标完成或普通通关证据。R4/R5联合最终验收、F1–F4、最终提交与推送仍待做。不触碰真实存档，不公开发布，不发提前完成邮件。

## 已实际验证

- 真正的`RiftObserverBoss`进入第六遭遇工厂，原混合敌人/机关策略保持。工厂缺失先语义RED；Policy341、Encounter310、Runtime3000实际退出0。活Boss伪造死亡信号不清关，活Boss移除实际FAILED；30骨、10800HP、56判定圆与合法出生均检查。一次夹具调用不存在的Boss getter失败，修正为实际`body_radius`属性后再验证，失败日志保留。
- `RiftChapter`仅覆盖章节编号与区域绑定，复用真实`ChapterRun`。缺场景先RED；事务测试143实际退出0：空档不能跳关、两必经/风险路线/奖励、真实Health归零、保存拒绝旧档SHA不变、实际重试、仅记录6/全通/无7、重玩与返回不丢进度。此前1–5是隔离夹具前置，不是连续六关正常通关。
- Registry Ready1–6。菜单缺入口先RED；Launch23、第五Launch19、公共Launch12、第五Chapter144实际退出0。真实菜单点击进入薄协调、返回保留音频与进度，未击败6不能写6，也没有第7入口。
- 普通游玩证明器原末关规则错误地要求解锁7。新增规范先RED，再按实际ChapterCatalog末关验证全通且无7。Completion37、SharedChapterRun12、CampaignMenuIntegration14、CampaignMenu153实际退出0；这是证明器修正，不是生产存档故障。
- 正常导入产生实际UID。普通输入证明器`VerifyRiftChapterFlow`实际Main/UI、普通移动/射击/冲刺、真实地形/机关/骨骼三招，两路线独立证据档；飞行威胁读实际位置，Boss新预警至少等150ms再反应，不改玩家数值、伤害、奖励或战斗状态。

## 已完成的普通路线证据

补给路线`rift_flow_supply_v1`实际NVIDIA/OpenGL退出0，13995检查、6884实际移动、1483发、6903引擎指针检查、29真实击杀（实际28债务+Boss），seed1781057999；三招和真实1/2/3阶段均出现，Boss10800→实际死亡，终态CLEARED/保存六关完成/无7。HP100是该普通输入驾驶策略的结果，不能据此签平衡或真人体验。19张PNG（含960/1280/1920入口）全部实际查看，58源与19图逐SHA核对无漂移；未发现入口动作溢出或此前Runtime夹具灰边，但不覆盖整个六区视觉接受。胜利弹窗中Boss尸体初姿仍可见，尚未单独验证自然推进。

新进程`VerifyRiftCampaignRestore`实际退出0/76检查，实际Main只读加载该证据存档：1–6已通关、全通且无7、六区重玩可达，原保存SHA不变。前五仍为夹具前置，不是新档连续链；恢复UI信号检查也不冒称另一次普通通关。

风险路线`rift_flow_risk_v1`实际NVIDIA/OpenGL退出0/16817检查，seed2798910851，8231真实移动、1780发、8308引擎指针、49真实击杀（48债务+Boss）；四区额外遭遇→领取真实奖励→三招/三个真实血量阶段→真实死亡→保存全通/无7。受到24伤害后普通拾取回复20，最终HP96，未伪造回血。新进程恢复76检查实际退出0、原保存SHA不变。24张PNG全部实际查看；与补给共43图/4报告，已逐SHA复制到`docs/art/previews/campaign/rift-chapter-flow-v1/`，两路线58个当前源无漂移。

实际风险截图新增F4视觉缺口：`frame_003.png`底边约80px黑色无地面；生产Camera虽设置地图限制，这个真实渲染缺口仍发生，不能再用“仅旧Runtime夹具”解释。`frame_019.png`实际Boss超出画面、有方向牌，是否符合最终取景须联合距离/拾取目标核对。两路线胜利图只是死亡初姿，不证明胜利暂停下的自然倒塌。功能通关通过不等于最终视觉/手感通过；保留原图，不隐藏缺口。

独立包工具已先RED规范，再支持R5相对父夹具完整闭包（包括Runtime的EchoMovement）、各套真实帧预算与两普通路线/新进程恢复前置银行。Release/UID/runner Python14实际通过，PowerShell解析无错误；外部规范仍同SHA原文件、无工作区`--path`，作者/tests仍排除，包≤30MiB。接下来实际当前R5独立包，不以政策检查代替真实包执行。

当前独立`rift-chapter-final-pack-v1`会话86343已实际退出0：30规范夹具/28273断言，Main120，200证据源保持，7,102,328字节，SHA`107dbd9adfe347d538dba9455eaf264ff6ce940ee87dc789e306f6fff78fa701`。R5真实工厂341/事务310/普通混战2902/薄章流143/菜单23全部在相同PCK外实际执行；37个同SHA规范文件包含七个相对父依赖、32清洁日志，作者/tests不在包内、无工作区`--path`。正常release实际退出0、相同字节预算、Main120。精确收据为`rift-chapter-joint-packet-gates-v1.json`；不能把这些写成完整回归或整游戏完成。

`rift-chapter-joint-source-freeze-v1.json`冻结263当前路径与六旧资源，包和release之后核对零漂移。联合完整all会话8407实际运行，日志`rift-chapter-joint-full-v1.log`；没有最终汇总/退出码，不勾R4/R5或发阶段邮件。串行核对同一进程，期间不改冻结代码或再开Godot；旧GUI41396不动。当前HEAD713dde5f、staged0，大量既有工作保留，无提交或推送。

F4黑边源原因已经只读定位：`BossCameraFraming.step_framing`为保留玩家全身和避开HUD，放宽地图camera limits并进行安全区域校正；`RiftFloor`只绘制`world_bounds`内BASE。因此正式风险图的空白边缘不能靠原始ChapterRun limits否认。后续以实际GPU边缘重现/RED为前置，补视觉边缘衬底并保留地形边界与玩家/Boss可视空间，不靠夹紧镜头牺牲已有HUD取景；当前尚未实施或签修复。尸体暂停亦待专项自然等待核实。

## R4e包门的准确范围

此前独立`rift-observer-automatic-pack-v1`实际退出0：25规范夹具/24555断言、Main120、7,100,260字节，SHA`93b51dd55885086e288dfcd9560ab99245cdc0e38bdaa5de9f888ef81c4a9261`；release实际退出0。103证据源/26规范文件/六冻结资源/四UID/27交付/27清洁日志见`build/diagnostics/campaign-goal/rift-observer-automatic-packet-gates-v1.json`。这是R5改动之前的快照，不冒称当前R5或最终整游戏包。

旧full v2会话28159已不存在，进程核对没有其runner/Godot，165套PASS但无最终汇总与收回退出码；保留为中断未完成，不当全量通过。按执行序修订，R4/R5共同等待R5完成后一次当前源全量/PCK/release，覆盖范围不减少。

## 下一门与完整长期目标

1. 两条普通输入路线真实击败6/保存全通/无7；当前GPU截图逐一复核、银行SHA不变、新进程恢复。不能以受控致命伤害事务替代。
2. 当前源全量、独立PCK与正常release、实际UID/原资源冻结/许可与清洁日志联合闭合后再签R4/R5，发一次真实Gmail阶段邮件。
3. F1正式默认入口（目前默认仍旧demo）、F2新档普通1→6连续链、F3多种子/构筑/风险收益平衡、F4菜单/六区/HUD/密集性能/来源与最终同源本地候选；整个目标实际完成才聚焦提交/推送。

源审查另发现：共享死亡视觉PAUSABLE，而胜利弹窗会暂停场景，可能冻结正式Boss倒塌动画。当前只是代码风险；独立Runtime自然倒塌不证明正式胜利行为，须在本次自然GPU复现后再修，保留手动暂停语义。旧Runtime灰边仅出现在未设Camera地图限制的夹具，正式关卡有地图限制，也须实际画面核对。
