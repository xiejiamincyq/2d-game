# 全角色骨骼资源检查点 v1

2026-10-11；`5分钟超载`，未提交/未推送，长期目标active。作者自主自审，不冒充独立验收或真人试玩。

## 裁决及范围

**通过全角色骨骼资源齐备门（M3.R/Checkpoint），允许进入M4逐招制作大型攻击。** 当前23独立身体已齐备；目录另含历史Cinder v1，不重复计角色。四向玩家是一个身体契约、四独立视图。此门只确认原生骨架/皮肤/基础动作/挂点和现有生产入口覆盖，不是全部最终动画、六关可玩或性能验收。

七基础EnemyKind、十二区域role实际创建；WaveDirector自然创建与延迟门户增援、孢团死亡后两实际子体、两实际Boss、Player创建的两无人机均检查生产场景，不只读目录。五未来章节Boss仅审资源和原生播放适配；第一关就绪列表仍仅[1]。

当前NativeArtValidator仍拒绝大型attack/warning。进入M4须新增显式、关联证据且有反例的分阶段契约，新资源使用新版本，不能用全局true或删延期检查开放全部攻击。

## 身体清单

| 身体 | 骨数 | 生产覆盖/边界 |
|---|---:|---|
| 根须追逐者 | 12 | SCRAPPER、root_pursuer、真实召唤 |
| 孢子射手 | 14 | SPITTER、spore_spitter |
| 余烬疾行者v2 | 15 | DASHER、slag_charger、真实召唤 |
| 盐针射手 | 16 | MARKSMAN、salt_needle |
| 投囊者 | 16 | LOBBER |
| 岩根搬运者 | 17 | BRUISER、五非攻击动作 |
| 裂根统御者 | 23 | OVERSEER、实际旧波次独立Boss、五非攻击动作 |
| 火花散射手 | 16 | spark_gunner |
| 绕侧蟹 | 20 | flanking_crab |
| 分裂孢团 | 16 | splitting_mote、实际0.62比例子体 |
| 投囊布设者 | 20 | capsule_planter |
| 回声哨卫 | 20 | echo_sentinel |
| 迂回影 | 18 | circling_shade |
| 裂隙精英 | 20 | rift_elite |
| 空间切线者 | 19 | space_cutter |
| 藤冠守卫 | 22 | 第一关实际Boss、五非攻击动作 |
| 炉心督工 | 23 | 第二关计划Boss资源、五非攻击动作 |
| 潮壳巨兽 | 25 | 第三关计划Boss资源、五非攻击动作 |
| 藏孢书记 | 27 | 第四关计划Boss资源、五非攻击动作 |
| 钟骨司祭 | 26 | 第五关计划Boss资源、五非攻击动作 |
| 裂隙观测者 | 30 | 第六关计划Boss资源、五非攻击动作 |
| 巡界员 | 每向13 | 实际Player、前后左右四库、七动作 |
| 巡界无人机 | 10 | Player拥有实例、五动作 |

专项检查外库、完整原生绑定、非纹理皮肤、每必需动作至少两关节变化、播放不移动物理根、现有健康血条契约。大型/六Boss仅idle/walk/hit/entrance/death。身体均由项目原创作者几何构造；此前逐族依赖/来源审查保留，生产身体无付费复制、外部位图或新增外部运行库。CC0技术样板不混入生产名册。

## 当前可复核证据

- `character-roster-v3.log`源494检查PASS、退出0。v1类型推断编译失败不计有效RED；v2夹具误期望即时增援，修正为检查两门户并调用真实到期逻辑，生产代码未改快。
- 既有`drone-pack-v1/game.pck`独立目录、无源码path运行，外部`character-roster-v3.log`同样494检查PASS。不是新导出或新EXE；5,527,952字节，之前release/Main门保留，不重复用启动门冒充完整游戏。外部测试加载包内实际对象，不宣称作者脚本在包中。
- `character-coverage-v1.log`通过23当前身体/13生产actor。[覆盖报告](previews/campaign/native-character-coverage-v1.json) 23场景/23manifest/26动作库/13actor共85 SHA256在签署时逐项一致。
- `character-roster-gpu-v1.log`52实际尺度身体（idle/walk各26格），0半透明、0边界裁切。[GPU报告](previews/campaign/native-character-opacity-v1.json) 50源SHA逐项一致。
- 主代理亲自查看[待机](previews/campaign/native-character-idle-v1.png)和[行走](previews/campaign/native-character-walk-v1.png)：奶油纸块/墨线统一，敌族轮廓及功能色区别；玩家青绿与铜色无人机同阵营。PNG无烘焙标签，报告标明五未来Boss仅资源。实际Actor身体/材质/比例保留，剥离父级血条/阴影并居中，不是自然Main、混战或UI验收。格顺序前21NPC→玩家前后左右→无人机，每行六格。
- `character-roster-full-v1.log`失败：两新作者脚本在初次导入之后新增，缺UID。保留失败，正常Godot导入生成UID；专项3测试通过。`character-roster-full-v2.log`退出0：173 Godot套件190161断言、36 Python套件272测试，没有跳过失败项/手写UID。

本阶段仅新增覆盖测试及两个作者审查工具；战斗控制器/身体资源没有改动。自审不是外部独立批准。

## 下一步和未完

先制作岩根搬运者新抬臂/落锤/收势，真实0.5s蓄力/0.75s恢复及唯一54伤害驱动，动画不得控制伤害事件，校对小感叹号/准确范围/克制效果。随后裂根统御者、藤冠守卫和五未来Boss逐招。

第二至六关地图/遭遇导演/真实Boss控制器、风险奖励/重玩仍待做；资源与工厂齐备不代表M3.2最终动画或M5完成。无人机真实退出死亡、尸体结算暂停、孢子口部出弹、旧PNG依赖瘦身、Boss镜头黑边、终态HUD一帧滞后保留待办。全新VFX/环境/UI、正常输入六关/跨进程循环、混合AI/物理/GPU性能、最终美术及真人手感未验收。不发布，不提交/推送中间里程碑。
