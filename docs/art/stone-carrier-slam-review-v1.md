# 岩根搬运者原生落锤审查 v1

2026-10-11；`5分钟超载`未提交工作，长期目标active。新增攻击发生在[全角色资源检查点](native-character-roster-review-v1.md)签署之后，不把M2过渡Boss需求当提前开工理由。作者自主style-approved，不是独立验收、真人手感、最终美术或六关完成。

## 新资源和真实行为

新`stone_carrier_paper_v2.tscn`及外置`stone_carrier_motion_v2.tres`。历史v1身体/五个原创非攻击动作保留，新作者`StoneCarrierAttackDraft.gd`继承项目自有几何/rest，不使用旧PNG、旧爪击动画或外部付费角色。17骨及全部绑定不变，新增三段：0.5s双臂抬起并落下的slam_warning、0.12s命中压身slam_attack、0.63s收势slam_recovery。命中姿态从attack第0秒起已落下；17关节可取消复位，不移动物理根/伤害事件。28px视觉范围余量及96px血条/头标余量仅覆盖抬臂，不放大24px碰撞。

实际Enemy只把BRUISER换v2和NativeStoneCarrierMotion；OVERSEER及六Boss仍保持原非攻击资源。播放器读取原attack_timer，优先显示已武装攻击而不是被密集受击姿态遮盖；真实战斗拥有唯一伤害和时钟，动画没有独立process/发弹/事件轨道。300HP、54伤害、59.4基础移速、46攻击范围+8实际判定、0.5蓄力/0.75恢复/1.4周期不改。本次先校对动作，未擅自加速大型战斗或换其伤害模型。

去除本族大面积地面蓄力扇，改小黑描边头顶感叹号；命中仅0.12s两根细圆线，由实际径向判定中心扩张至54px，无填充、烟雾、额外伤害。锁定抬臂方向防玩家横穿时来回翻面，范围仍准确表达圆形攻击。隐身/丢目标/出生冲量/死亡先清空已武装落锤，并给0.4s重启间隔，避免隐身后恢复旧伤害；其他敌族行为不变。

## 有证据的后置资源门

`NativeRigCheckpoint.gd`是作者工具，不是生产Actor/战斗热路径。新manifest引用`native-checkpoints/all_character_rigs_v1.json`；固定覆盖报告与作者审查文档SHA、23身体基线场景/manifest/动作库SHA逐个核对，唯一当前批准请求是stone_carrier_paper_v2→已审stone_carrier_paper_v1。旧基线保留，迁移后Actor源码发生合法变化不使历史齐备证明自毁；该证明不宣称未来五关已接入。

NativeArtValidator默认仍拒绝大型attack/warning，只有明确引用且角色/骨数/独立版本路径吻合的候选可通过；新增动作必须列入required_clips。没有全局true、没有删门或允许所有Boss任意补标签。源/目录许可与技术验证也不自动变成final。

## 失败及专项

- 新门原先缺文件明确失败；门初版被bool/字符串等输入触发类型错误，新增非法数值/授权基线反例再次失败，再加边界类型守卫。最终`rig-checkpoint-types-green-v1.log`38检查通过。旧NativeArtValidator36检查仍通过，大型资源未默认开放。
- 新资源缺文件RED退出1；作者烘焙v1未显式调用父类_init，缺骨架失败，补父构造后v2烘焙通过。随后新资源仍被旧延期契约拒绝，`stone-attack-contract-red-v2.log`明确失败；接入显式证明后资源102检查通过。
- 接入测试v1把Node2D内置hidden重定义，编译失败不计有效RED；改名后v2确实因实际BRUISER仍旧v1退出1。新实际接入18检查通过：短头标/锁面/单次伤害/受击不遮攻击/恢复/不变物理数值/无效delta/暂停/隐藏取消/出生取消/死亡。
- 补强死亡检查发现姿态切death但is_attacking仍武装，`stone-attack-death-red-v1.log`退出1；实际_die先取消后`stone-attack-StoneCarrierAttackIntegrationTest-v2.log`18检查通过，防地面圈残留一帧。
- 旧StoneCarrierIntegration20、历史v1资源89、当前全生产入口Roster500、迁移兼容EnemyStaticArt90检查通过；没有放宽骨数/碰撞/伤害断言。

## 画面证据和自审

[八动作三相位](previews/campaign/stone-carrier-slam-poses-v2.png)列顺序idle/walk/hit/entrance/抬臂/命中/收势/death，行0/45%/85%。[实际Enemy预警](previews/campaign/stone-carrier-slam-warning-v2.png)、[实际唯一54伤害后0.08s的落锤](previews/campaign/stone-carrier-slam-impact-v2.png)、[剥离身体后的真实地面效果](previews/campaign/stone-carrier-slam-effect-only-v2.png)。透明捕获未添加地板，不是自然Main/密集战斗或完整关卡。

- GPU v1虽然声称96姿态通过，但作者查看发现先播放不可逆death，后面三动作栏仍尸体，撤回攻击画面通过。加采样返回值检查后GPU v2明确失败，不改变生产死亡不可逆规则去救预览。
- 修正预览为death最后；真实冲击环独立剥离身体再统计，避免身体同色像素假阳性。GPU v3正确通过；死亡取消生产代码后再生成v4作为当前版本证据。旧v1/v2/v3输出保留，不覆盖失败报告。
- `stone-attack-gpu-v4.log`退出0明确PASS：[当前报告](previews/campaign/stone-carrier-slam-opacity-v2.json)96实际Enemy身体/shader姿态（八动作×三相位×两朝向×两受击闪），0半透明/0视口裁切，全部活体姿态在遮挡范围内；真实适配行走60帧59相邻变化，独立真实冲击圈298目标色像素，9生产/工具源SHA在完成捕获时一致。主代理亲自查看v3全部图和v4实际命中图，采用风格，不签人类手感。

五轴自审：碰撞/伤害仍由原逻辑唯一结算；新视觉组件只读战斗状态，门在作者侧，不在战斗循环中做文件hash；不新增依赖/安装/网络/凭证。Enemy有既有kind分派，本次只新增本族取消/小范围表现，不把新六关导演全部堆进该大文件。密集性能还需M6实际AI/物理/GPU验证，不把96身体采样当性能数据。

全量回归v1仅EnemyStaticArt硬编码历史v1路径失败，保留失败并更新明确v2路径，仍保留完整结构/数值断言。下一步裂根统御者新近战/喷射，再第一关藤冠守卫专属招式及第二关纵向闭环；五未来Boss资源不是五可玩关卡。不发布，不提交/推送中间里程碑。

## 最终工程门与独立包

- `stone-attack-full-v2.log`退出0、明确PASS：176 Godot套件190334断言、36 Python套件272测试，没有跳失败项。所有新脚本UID通过正常导入生成。
- 当前[升级后角色覆盖报告](previews/campaign/native-character-post-slam-coverage-v1.json)仍23当前身体/13actor，85场景/库/manifest/入口SHA在本阶段结束时一致；冻结的前置v1证明仍保留，不能把v1入口SHA当作v2当前生产源码。GPU v4报告的9源SHA亦再次逐个一致。
- `build/diagnostics/campaign-goal/stone-attack-pack-v1/game.pck`，独立目录无源码path，仅外部专项脚本加载包中实际运行类：实际落锤18、当前角色名册500检查通过；Main120帧退出0，无错误/泄漏。5,605,140字节，SHA256 `17279cdb9c86b4075f7445a74bad594d1c25816f633e9e0572e03d87ae0096b5`。源码新资源102检查不冒充作者校验器已包含在PCK。
- 标准`stone-attack-release-v1.log`退出0明确PASS，同大小5,605,140字节，作者脚本/文档/技术草稿排除、Main120帧通过。仅本地诊断包，不覆盖旧EXE，不公开发布；没有EXE整局、自然Main落锤、密集混战或人类体验通过声明。

裁决：M4.1a岩根搬运者原生落锤工程接入通过，仍style-approved；M4整体、其余大型/Boss攻击及六关目标未完成。整体任务未完，不提交/推送阶段工作，所有既有无关脏改动保持。
