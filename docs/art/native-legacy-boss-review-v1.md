# 旧波次独立 Boss：原生身体与稳定锚点

2026-10-10，分支5分钟超载，M3.3h第二小步，未提交阶段工作。实际OverseerBoss已接入原创23骨裂根统御者资源，不再绘制旧PNG。不是第七个区域Boss，也没有把旧攻击导演改名算作六关专属招式。

## 实际实现

共享新制作的root_commander_paper_v1.tscn与外置五非攻击动作库：idle/walk/hit/entrance/death。没有新增攻击动作、独立攻击时钟或伤害事件轨道。NativeBossMotion只读取导演登场进度、实际速度与受击时钟；旧TentacleAttack/BossAttackDirector及伤害、阶段、增援、战斗结束顺序仍过渡保留。

物理根从setup开始保持scale=1、rotation=0、alpha=1；真正肢体链完成登场，保留1.4秒免伤、PROCESS_ALWAYS以及一次登场完成信号。新主体不继承旧Sprite的1.25放大：原生视觉scale=1，垂直锚点按body_rect中心对齐，横向锚点保留0供自然镜像；不是缩小碰撞。基础HP10800、速度63.8、碰撞半径56、原战斗导演参数均未改。

统一get_visual_node/get_visual_rect接口返回活体原生节点及其本地镜像身体范围，镜头再应用视觉节点全球变换，含视觉锚点但不重复缩放。ShaderMaterial挂在Facing/Skin；实际受击驱动骨骼recoil。死亡重置闪色、脱离纯视觉尸体并保留全球变换，攻击关闭/死亡信号/结算仍唯一。NurseryVineBoss的独立22骨、免伤、受击及死亡继承路径复核通过；两套字段不重名，也不双重触发受击。

旧PNG/preload与历史证据保留，不声称包内已清除旧资源。诊断工具的Sprite2D依赖迁移到统一接口：BossCameraFramingTest、VerifyBossFraming、VerifyNaturalRunRendered及配对/主体诊断。自然捕获的sprite_rect历史字段继续代表保守身体框，不是透明像素分割。

## 失败与修复

- 新实际集成测试先RED：旧独立Boss仍是Sprite，首关继承体已原生；迁移后48检查GREEN。此夹具显式调用时钟/伤害，不是普通输入通关。
- 第一轮全量legacy-boss-full-v1退出1：首关历史旧Sprite断言、自然捕获get_rect依赖，以及960×540构图实际HUD遮挡。后一项是新身体沿用1.25倍缩放后范围过大，不以放宽断言或再降低镜头0.80下限掩盖。
- 新视觉锚点/尺寸回归再次RED，调整原生视觉尺寸/垂直锚点后49检查GREEN。BossCameraFramingTest 1862检查通过四种分辨率、方向/边界/实际HUD、shake、暂停、移除、参考视口与导航隔离；同类遮挡构图在960×540已能同时放下两者，碰撞根不变。
- legacy_boss_preview_v1/v2保留；v1只证明当时主体不透明，不证明小窗口镜头。最终采用v2（新锚点）而非覆盖旧结果。

## 验证范围

- legacy_boss_preview_v2：实际OverseerBoss创建/真实shader的60姿态，0主体半透明/0画面边缘裁切，所有非死亡左右姿态在生产镜像范围内；15完整姿态已查看。实际NativeBossMotion连续60帧、59次相邻像素变化。另包含实际首关自然登场后的藤冠守卫全身/UI截图；该章节预览跳过遭遇，不能冒称普通输入或完整通关。
- legacy_native_v2：旧Main真实工厂/镜头/UI夹具，四分辨率12静态截图及240连续受控镜头帧已生成；960×540边界截图已查看。冻结/脚本移动组件，不是实时性能或自然输入；远距不可能构图保留方向提示。世界边缘/旧薄荷环境仍待整体视觉升级。
- flash-native-v1：修订后的主体诊断使用真实物理Boss与脚本目标、固定帧时序；211次实际伤害接受、四张受击/恢复图和节点清理通过。不是Main、警告墙钟、真人手感或完整Boss战。
- 新测试NativeLegacyBossIntegrationTest：源工程与实际隔离PCK各49检查通过，含原生骨数/五非攻击片段、锚点、免伤/导演、真实膝部步态、镜像身体框、实际受击、暂停、一次死亡和尸体保全/清理；VineGuardIntegrationTest43与NaturalRunRenderedTest29检查通过。
- legacy-boss-full-v2.log退出0：135 Godot套件187863断言、36 Python套件272测试。全量结束后仅补写审查/台账/计划文档，没有继续修改运行实现。
- PCK 4,881,184字节，SHA256 693915afbff9cbc57f1bc1c77127c4df093f04370ba23a558709484e3b11153d。独立目录仅从包加载生产Boss/场景/动作库；49检查及Main120帧启动通过。标准release门通过作者/测试排除、30MB预算与120帧无错误/泄漏；未覆盖旧试玩EXE、未发布。NativeCatalog14声明与资产台账检查通过。

## 自审与未完事项

只沿用原资源的自主style-approved，不提升gameplay-approved/final。七基础EnemyKind、玩家、首关Boss及旧波次独立Boss都已经原生；六计划区域Boss均有独立非攻击资源，但第二至六关没有实际战斗/地图接入。区域普通敌族及玩家NativeCatalog结构仍未齐备，全角色门继续关闭，不制作大型新攻击。

尸体结束阶段会随关卡/波次结算暂停而冻结，当前独立生命周期夹具只证明未暂停时能清理；不能把它当结算页完整死亡播放验收。六关不同地图、区域普通怪、Boss专属机制、全部新效果/UI/环境动画、正常输入解锁链与密集性能仍要推进。

长期goal active；下一步区域普通变种与玩家目录契约。按最新AGENTS，整个任务未完成前不提交/推送中间里程碑；无关脏文件、旧包及存档保留。本文不作为人类体验或六关完工证明。
