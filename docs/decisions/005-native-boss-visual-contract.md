# ADR-005：首关原生 Boss 的视觉接口与过渡机制

状态：Accepted（阶段设计；不是六关完工）

日期：2026-10-10

## 背景与约束

用户选择原生 Godot 骨骼并要求全部新动画；全角色骨骼资源完成前禁止制作高血量敌人/Boss 新攻击动作。首关已经可玩，旧 Overseer 的战斗时钟、伤害、死亡解锁和磁盘保护不可在替换身体时重写。现有镜头直接访问 Sprite2D，而新的身体是 Node2D/Skeleton2D/Polygon2D，不能赋给旧的类型化 boss_visual。

## 决策

新增 NurseryVineBoss，复用 OverseerBoss 的战斗生命周期，仅替换视觉、非攻击采样和纯视觉尸体。NurseryEncounterDirector 覆盖 WaveDirector 的 `_create_boss_actor() -> Node` 工厂；父类负责同一 setup、导航、信号、实例登记和死亡结算。旧波次工厂仍产生旧 Overseer，不让旧游戏入口悄悄换招式。

Boss 内部统一接口：

- `get_visual_node() -> Node2D`：当前活体视觉节点，未建立/死亡脱离后可能为空；调用者先验证活体。
- `get_visual_rect() -> Rect2`：在上述节点本地坐标中的保守身体范围；不是世界坐标、不是 hitbox。原生版本包含 Facing 镜像及经 GPU 审查的动作余量；旧版返回 Sprite2D.get_rect。
- `get_display_name() -> String`：展示名；不作为关卡/Boss ID 或存档键。

BossCameraFraming 使用接口再乘节点 global_transform 或 global_transform_with_canvas，避免双重应用根或镜像变换。PlayerOcclusionOutline 已使用同名约定，现可读取原生 Boss。没有新依赖、网络运行时或另一个攻击时钟。

藤冠守卫的 1.4s 登场保留原导演免伤与一次完成信号，但物理根 scale=1、rotation=0、alpha=1；真正 Bone2D 驱动起身/藤冠/垂藤。五个动画仅 idle/walk/hit/entrance/death，挂点暂不出弹、不发伤害。旧攻击画面和阶段仍明确标记“攻击机制过渡”。

## 未采用的方案

- 将 native Node2D 填进 Sprite2D 字段：违反类型及 get_rect 依赖。
- 镜头按具体 Boss 类型分支：后续六种角色会重复耦合实现细节。
- 复制整个 WaveDirector 出生/死亡流程：容易丢失实例/死亡/存档保护。
- 现在制作藤蔓横扫等新招式：违反用户明确的骨骼齐备门。

## 代价、验证与后续

阶段内仍有旧攻击视觉及旧波次 Boss；未把整图程序摆动当作新骨骼完成。专门验证原生工厂、镜像范围、真正膝部动作、碰撞根稳定、登场免伤、真实受伤/一次死亡、暂停与尸体清理；旧 Sprite 接口及旧 Boss 测试仍保留。GPU 要求身体实像在屏幕内，HUD/方向指示器和上一帧 both_fit 不算证明。

原始用户存档/旧可玩 EXE 不改。其余五关独立 Boss/敌族/地图及新攻击继续按长期清单推进；全角色骨骼门尚未打开。[本轮记录](../art/vine-guard-review-v1.md)。

## 2026-10-10 后续：旧波次独立 Boss 原生化

以上保留首关迁移时点。M3.3h第二小步让默认OverseerBoss也使用原创裂根统御者23骨，boss_visual改为Node2D，并新增不同名boss_motion；NurseryVineBoss的native_visual/native_motion保持独立，不发生字段覆盖或双受击。统一接口现在两个实际Boss均返回Facing镜像body_rect，不再依赖Sprite.get_rect。默认Boss按新皮肤原生scale=1及垂直中心锚点绘制，不继承旧贴图1.25放大；56碰撞/10800HP不改，四分辨率实际HUD/镜头回归通过。

旧波次工厂仍使用原独立导演，登场免伤、阶段、增援与唯一结算不变；五非攻击动作由骨骼完成，旧攻击机制仍过渡。尸体结算暂停时冻结仍待后续完整死亡呈现验收，不把独立生命周期测试冒充结算动画通过。此后续不是大型攻击开工或六关就绪授权，详见[实际接入、失败与包验证](../art/native-legacy-boss-review-v1.md)。
