# R4c：双探针锁点钳击，实施前契约

## 目标与授权

沿R4原始规格，原创观测者双臂各释放一枚短程探针，固定两个错位落点，区别于钟祭180px往返悬链。用户已授权自主美术和长期实施，不再等待风格审批；不是允许购买/安装或提前签整关。沿当前30骨纸墨原生v2，不重烘资源、不导入PNG。旧art guide的13px/贴图/斜俯相机不适用于本次更高优先级原生2D目标，真实Player保持235px/s、16.9px、HP100。

## 规则与内部接口

唯一RiftObserverAttackDirector掌管warning0.32 / active0.56 / recovery0.52。warning只有短头标，按warning开始的实际目标位置锁定两个落点：目标±locked_direction.orthogonal()*18px，方向不再追踪。active中的左0.1008秒/右0.2576秒对应原生各臂峰值附近；每枚只在该次真实帧采样probes_attack后读取对应SensorOrigin出生，不缓存warning骨坐标。每次绝对最多两枚，两个落点各自最多360px路径；薄墙/边界阻止不安全的整条路径，不临时追踪或改到另一个落点。

新RiftObserverProbe是RefCounted，一次单向直线0.12秒飞行、0.08秒落点停留，然后消失，不返航、不追随Owner、不另开timer/process。半径6px的圆体、真实基础9×3=27伤害，两枚共享同一attempted字典；先置尝试再调用实际Player.take_damage，即使无敌拒绝或Health回调重入也不补扣。显示使用同一position/radius/locked_origin/landing，克制墨边纸质小菱形、珊瑚芯和短尾迹，不画长警告射线或全屏特效。

接口arm(actor: CharacterBody2D,target: CharacterBody2D,origin: Vector2,landing: Vector2,attempt: Dictionary)->bool；resolve_hit(before: float,after: float,previous_player: Vector2,current_player: Vector2)->void；draw_visual(canvas: Node2D)->void；cancel()->void。age只是导演提供的采样时间，不累加第二时钟。arm拒绝无效坐标、零/超长路径、非法attempt、未入场/死亡/隐身/暂停/不在树、越界或实际1|QUERY_LAYER物理形状障碍；32接触饱和拒绝，普通未标记动态角色不是墙。

resolve检查上下文、单调合法时间、相对两帧圆扫掠；超过寿命的最后运动段裁剪Player位移到真正合法比例，末次合法接触帧保留实体像素，下一tick无伤害取消。不允许warning或出生前位移、寿命后尾段命中；外部delta>1/15由导演取消并保留安全间隔，primitive非法跨度也安全取消。Owner/目标/容器退出、死亡、换阶段、隐身、暂停/恢复均由唯一导演即时取消两枚与头标。取消幂等，不能通过死亡/取消回调重新武装。

## 文件与顺序

- c1（≤2 GD）：规范RiftObserverProbeTest先缺primitive语义RED，再实际Actor/Player/Health/薄墙/相对扫掠/一次尝试/末帧边界GREEN。RefCounted不提前注册第六，也不复制祭司弹体。
- c2（≤3 GD）：RiftObserverProbeAttackTest先真实probes被拒绝RED，再扩展现有唯一Director及beam clock的已实现动作白名单断言。真实左右出生/先可见后伤害/定点/有限两枚/取消重入、两次stage边界、无残留，与既有beam回归。
- c3（≤2 GD）：实际自然physics的RiftObserverProbeDodgeTest，30/60/120Hz、六方向、至少0.15秒反应；18次横移HP100、18站立HP73、正常碰撞不禁用。随后真实地图1280 GPU，左右warning/两次birth/运动/末端/取消，全图实际查看与当前源SHA/正常UID/当前独立PCK。c1/c2通过不签c3。

高风险是两枚跨帧快移、birth/寿命裁剪和真实挂点可见性，先实际物理后集成，全部Godot串行，不跑第二引擎。只已实现动作可启动，refract仍拒绝；自动三招轮换/完整Health三phase/整Boss/R5/F1–F4待后续，不扩大当前验收。

## 技术、命令与验收

出生审查补充（先实际RED再改实现）：共享OriginSafety原有返回Boss中心的兼容行为保留给旧调用；双探针必须显式严格挂点模式。若真实SensorOrigin被默认层/QUERY_LAYER薄墙或边界挡住，返回无效坐标并消耗本次该臂释放、不生成也不重试，合法另一臂仍可独立释放。新增规范OriginBoundaryTest覆盖双镜像clear/1/2/world，真实出生当帧取骨坐标，不能拿下一帧坐标误判出生错误。新增这个边界测试是审查补漏，不把原本16夹具包当修复后的当前包。

飞行→停留跨帧必须在0.12秒拆分相对运动；两段共享原始Player帧时间插值。独立BoundaryTest两个反例先实际失败，再101+37通过。近距离斜向双探针对照保留18+18，原来较远斜向仍保留6+6自然输入，断言左实际路径>360合法拒绝且右命中/可避，不增加射程或删失败例。GPU发现实体被Boss遮住，使用只读ProbeVisual Node2D在现有弹体z22绘制，血条z23/头标z24仍在上，beam层−1不变，无脚本/clock。依据[Godot CanvasItem绘制说明](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)，直接draw信号可绘制，不能延迟连接。

Godot4.7、typed GDScript、tab缩进、snake_case、有限值边界guard，沿生产组件查询而非复制导航。示例：

```gdscript
if not _context_valid() or not _terrain_clear():
	cancel()
	return
attempt.attempted = true # Shared pair ledger before actual Health callbacks.
target.take_damage(DAMAGE,&"rift_observer_probe")
```

规范测试scripts/tests，生产scripts/components，作者GPU scripts/art，交付docs/art/previews/campaign，日志ignored build/diagnostics/campaign-goal。工作树固定5分钟超载，不碰根目录master或真实保存。

```powershell
$engine='C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
& $engine --headless --path . --audio-driver Dummy --max-fps 120 --script res://scripts/tests/RiftObserverProbeTest.gd --quit-after 3000
& $engine --headless --path . --audio-driver Dummy --max-fps 120 --script res://scripts/tests/RiftObserverProbeDodgeTest.gd --quit-after 12000
```

每个已执行命令必须真实terminal exit0、唯一正数TEST PASS，无SCRIPT ERROR/ERROR/TEST FAIL/资源对象或RID泄漏；失败日志保留。相关包只有相同SHA的外部规范夹具，不能放开作者/test源入运行包。缺少技能definition-of-done参考文件时沿上述项目实际证据，不安装或弱化验收。R4e整Boss闭合才全量与一次Gmail；本切片不邮件、不中间commit/push/public release。

Always：先RED、正常Player、真实物理、唯一时钟、查看实际GPU、保留旧源/旧候选/保存；Ask first：新工具/费用/权限/发布；Never：复制收费造型、改Player统计过测试、瞬移伪称普通通关、改保存假解锁、动画发伤害或第二攻击clock。验收通过只证明R4c，不证明整个长期目标。
