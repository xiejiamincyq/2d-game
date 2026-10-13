# R4b：观测者锁定窄束机制切片规格

R4b2实施前细化：使用真实RiftObserverBoss和唯一RiftObserverAttackDirector验证，不另建测试专用模拟时钟。为获得真实Owner/Health/原生挂点与普通physics，本轮提前建立未注册入口的Actor框架；并不提前验收R4e。只beam可启动，probes/refract明确拒绝，全部完成后才接第六工厂/Ready。方向在warning开始按目标锁定，origin在进入active时先采样beam_attack0再读取真实AimOrigin锁定，之后不追踪；warning无地面长预警，只有Actor短头标。此细化取代下面“R4e才建立Actor”的制作顺序，不改变最终完整Boss验收。

唯一时钟0.30/0.12/0.45，每次advance最多一个stage转换，余量不追赶连发；active相对段按实际本帧与合法active的重叠比例裁剪。delta>1/15在攻击中安全取消并保留至少1.1秒间隔，不补伤害；非有限/负delta不推进。暂停即时取消、恢复保留安全间隔，目标死亡/离场、Owner死亡、projectile容器离场、控制器释放均清掉authority。入口/Health三phase仍沿当前Overseer公共契约，但未完成的两招不能因为进入phase2/3就获得假权限。规范时钟测试包含取消/重入/可视窗口端点，另做真正普通输入30/60/120Hz、0.15秒反应横移与站立对照。

用户已授权长期目标内自主方向。假设保持2D纸墨原生30骨、玩家235px/s和16.9px半径、不改变真实存档/主入口，第六关仍不Ready。新机制只加入观测者路径；不修改已验证BellPriestStrike或其它关攻击。按既有R4a→b→c→d→e→R5依赖串行；规格/接口由本工作区决策，不使用网页监督。

## 目标与边界

让虹膜准备后发射短、窄、固定方向的光束，区别于祭司140px钟槌。不是持续追踪激光或全屏扫射。候选长度360px、胶囊半径8px、基础伤害12×已授权3倍=36，一轮最多一次尝试（包含无敌拒绝）。候选唯一战斗时钟warning0.30/active0.12/recovery0.45，实际Boss导演接入后再验证；几何RefCounted不能另有timer/自主process。

primitive本轮只有锁定几何、实际物理阻挡、世界空间相对玩家扫掠与受击/取消边界；没有实际BossActor/导演/击杀/解锁。后续真实导演先以唯一clock采样原生动作，再从真实AimOrigin锁定origin/direction；动作微回弹不改变已锁定束或跟随目标转向。Actor.active期间不因该动画移动物理根。

## 内部接口

新scripts/components/RiftObserverBeam.gd（RefCounted），arm(owner: CharacterBody2D,target: CharacterBody2D,at: Vector2,direction: Vector2)->bool；锁定origin/tip，默认世界坐标。owner共享health/death_resolved/entrance_resolved/world_bounds契约，target为真实Player/get_body_radius/is_stealthed/take_damage契约，不引入外部依赖。

arm先cancel，拒绝非有限/零方向、非法owner/target、未入场、死亡/隐身/暂停、越世界边界、真实地形命中或查询饱和。CapsuleShape2D半径8/高度376，与显示相同；mask1|TerrainSweep.QUERY_LAYER，仅排除owner和target，自由活动动态角色不冒充墙，任何StaticBody/QUERY_LAYER障碍阻止整束而非穿透。实际terrain查询在arm及每次resolve重验，后来插入薄墙也不能伤害。

resolve_hit(previous_player: Vector2,current_player: Vector2)->void只在导演active合法调用。对锁定胶囊用圆体与两帧运动段距离/交点扫掠；非有限输入取消，合法命中先置attempted，再调用真实take_damage36、source rift_observer_beam（死亡回调可能重入）。不重试无敌拒绝；无命中不提前消费本轮。cancel幂等清掉owner/target/authority，arm的新轮才恢复一次尝试。Owner离树/队列删除/真实health0/目标死亡或隐身/暂停后resolve取消；未来Director负责即时信号cancel，不把逐调用检查冒称已实现所有者信号清理。

draw_visual(canvas: Node2D,active: bool)只读同一origin/tip/RADIUS，不发伤害。warning只有细轮廓，实际Actor另画短头标；active墨色外缘+克制珊瑚芯。未armed不画，不用巨大遮挡场地高亮，不另算追踪射线。

## 文件、测试与依赖

- R4b1最多三GD/规格：规范RiftObserverBeamTest先缺文件语义RED，再primitive+真实Player/Health/墙测试GREEN。覆盖锁定/镜像/水平竖直斜角/贴边圆体/高速跨帧/初始与后来薄墙/动态角色不阻挡/查询饱和/全部取消、无敌不重试、death回调重入。受控几何测试不是普通运动通关。
- R4b2最多三文件：规范正常玩家30/60/120Hz反应0.15秒横移对照，完整合法active重叠时间（裁剪两帧相对段至真正active，不扫warning位移）；先真实失败再单clock集成。玩家HP100、235/16.9不变；站立确实受伤，过早/过晚/暂停/长帧不补发。没有导演前不得冒称该项通过。
- R4b3：接真实骨挂点/普通尺度GPU、墙边出生/绘制与判定一致、UID/相关包。之后双探针和折射，再R4e真实Boss完整阶段及全量。R4a包是历史资源证据，新增primitive后不能称其覆盖新机制。

每2–3切片针对性检查，R4e整Boss阶段才全面回归和一次邮件。完整目标未达成不commit/push/public release。不停下来重复等待人审艺术选择；依用户已授权自主实施。装工具、额外费用、权限等仍必须另问。

## 执行与验收

R4b3实施前补充：在真实Actor、四个骨挂点和左右镜像上验证中心至挂点的默认层与QUERY_LAYER薄墙、挂点圆体、世界边界。若共享NativeProjectileOriginSafety遗漏QUERY_LAYER，先复现语义失败，再把该层加入共享查询；不得另造仅观测者使用的假出生点检查。GPU使用真实第六地图、原生Actor/Player和BossHealthBar，受控推进唯一导演时钟而非自然整场通关；检查warning仅短头标、active首次/末次可见帧与同源几何、recovery/暂停消失、镜像与物理根不动。普通躲避证据仍来自自然physics测试，二者分开。新增生产行为后重新验独立包，不拿旧包覆盖新改动。

Godot4.7 GDScript tab缩进/有限值Guard/入口bool失败返回/幂等cancel，沿当前RefCounted实际物理查询风格。例：

```gdscript
if not _context_valid() or not _terrain_clear():
    cancel()
    return
attempted = true # Before user Health / death / reentrant callbacks.
target.take_damage(DAMAGE,&"rift_observer_beam")
```

工作树C:/Users/21604/Documents/2D game/.worktrees/5分钟超载。命令（PowerShell）：

```powershell
& 'C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe' --headless --path . --audio-driver Dummy --max-fps 120 --script res://scripts/tests/RiftObserverBeamTest.gd --quit-after 3000
```

通过必须实际终态exit0、唯一正数TEST PASS，无SCRIPT ERROR/ERROR/TEST FAIL/对象或RID泄漏；导入正常生成UID。Always保留RED日志与旧v1/旧审查/真实保存；Ask first新工具/费用/权限扩展；Never改玩家数值蒙混、伪造击杀/存档、动画发伤害、并行Godot、发布或推送中间工作。GPU/机制、独立PCK、整Boss、六关通关与真人手感分开验收。
