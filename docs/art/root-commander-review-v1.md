# 裂根统御者：OVERSEER 敌族原生骨骼接入

本页保留M3.3h第一小步快照；随后旧波次独立Boss也已迁移，[第二小步及尺寸/镜头修复](native-legacy-boss-review-v1.md)是当前后续状态。以下“独立Boss仍贴图/随后处理”仅指本页记录时点。

2026-10-10，5分钟超载，未提交阶段工作。M3.3h第一小步：原创23骨及五非攻击动作接实际EnemyKind.OVERSEER。旧波次独立OverseerBoss仍为贴图，随后处理；不签全角色齐备或新大型攻击。

## 原创资源与实际接入

灰蓝披挂、盐白弯角/面甲、木质手杖/侧种囊与少量陶红内核。全坐标和动作键原创，不使用旧OVERSEER PNG，不抽取/描摹第三方作品，不借用六Boss角色几何/动作；共享的只是patch、关节/关键帧与烘焙技术工具。无新下载、第三方安装、付费服务或凭证操作。

23根真实Bone2D：Torso、SeedPack、双Mantle、双Leg→Shin→Foot、双Arm→Forearm→Hand、右Hand/Staff、Core、Head/Hood/Mask/双Horn。每骨全不透明绑定；手杖挂在手骨链上，步态只相对轻摆±3°，不是围着人物转。RootCommanderDraft/Shapes烘焙可编辑root_commander_paper_v1.tscn与外置root_commander_motion_v1.tres；生产不带作者脚本。

全新idle/walk/hit/entrance/death：角、内核、侧囊呼吸，独立膝足与披挂/手杖惯性，受击面甲/囊回弹，骨架起身，失衡侧倒。没有攻击/预警或变名攻击片段、事件/方法轨道；CommandOrigin/ReinforcementOrigin/StaffOrigin仅未来挂点，不是此次技能发弹起点。实际Enemy使用NativeLargeMotion，只读取现有战斗状态与出生/受击时钟；沿用旧地面预警/攻击画面，明确仍过渡。

实际OVERSEER为新骨骼、无static_visual；保持1800基础HP、40px碰撞半径、72近战伤害、46.2速度、64攻击范围。原12发径向散射每发30伤害/310速度/3秒寿命、66%与33%增援18/24各一次不变，不把动画当伤害时钟。健康OVERSEER仍显示完整血条，82px头冠高度余量只是血条布局；碰撞箱未增大。

## 验证、失败和范围

- 原生资源/实际Enemy集成两测试先RED退出1，分别因资源缺失/仍旧贴图；烘焙与接入后资源112、实际源/隔离PCK集成37检查通过。覆盖皮肤权重/五非攻击动作/三个挂点、rest与死亡终止、出生/独立膝足/手杖限幅、碰撞根、健康与受伤血条、近战唯一命中、12发散射参数、两次增援阈值幂等、暂停及死亡脱离清理。不是自然Main输入或真人试玩。
- 镜像回归新增后RED：不对称手杖已左右翻转，但Enemy.get_visual_rect仍返回右向范围。修正为Facing.transform * body_rect后GREEN；不改物理碰撞。通用大型GPU审查工具随后改为消费生产get_visual_rect接口；v1的宽余量使未镜像工具框仍通过，不把其当镜像接口证明，采用v2验收。
- commander_preview_v2：真实Enemy创建/共享shader主体60姿态，0半透明/0画面边缘裁切，所有非死亡左右姿态在生产视觉框内；15完整姿态及真实受击血条图已查看。实际Enemy播放适配器60帧步态59次相邻像素变化，捕获源/依赖hash已记录；死亡不要求位于生前遮挡框，但视口全身完整。HUD/受击辅助效果不计主体alpha，不能用该工具宣称正常输入通关。
- PCK 4,882,048字节，SHA256 7c7c45d6530ec621157d8506764effdcda92f8d63d88627766d31bc0b3ab28a5。独立包内Enemy/场景/库实际加载，外部集成37检查通过；作者/测试内容排除、30MB预算及Main120帧启动通过。NativeArtCatalog14份声明通过（含疾行者v1/v2，不等于14敌族）；旧试玩EXE未覆盖、不公开发布。
- commander-full-v1.log退出0：134 Godot套件187804断言、36 Python套件272测试通过；资产台账VALID、git diff --check通过。全量之后只补写审查文档，没有后续运行实现修改。

## 自审与下一步

只签自主style-approved，不签最终gameplay-approved/final。单网格外置库，不每帧重构皮肤；动画不写物理根/伤害/碰撞。旧PNG/preload与历史工具保留，不声称运行包已清除全部旧素材。源契约、GPU与实际包集成各自有范围，不互相替代真人体验或长期完整六关。

下一步旧波次独立OverseerBoss入口（包括稳定骨骼登场、真实视觉范围/镜头与死亡生命周期），再区域普通变种及玩家目录契约。七基础EnemyKind都有新原生视觉，但区域差异化、完整六关地图/敌族/专属Boss机制及环境/效果尚未完成。全角色骨骼齐备门关闭，不制作大型新攻击。长期goal active，整个任务未完成，不提交/推送中间里程碑；无关文件、旧包及存档保留。
