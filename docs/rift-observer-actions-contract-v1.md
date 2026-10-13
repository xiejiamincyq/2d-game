# R4观测者：新原生动作库与真实Boss的边界

当前R4a已按契约实际烘焙并验明：[资源审查](art/rift-observer-actions-resource-review-v1.md)。规范17/17/44/1388/33、GPU673/168姿态/各30连续帧、七UID，独立PCK三规范夹具1036断言/Main120/release actualexit0；四PNG已看/五交付SHA相同。实测修复新v2视觉框25px，旧v1不变。只资源切片，不是R4整Boss战或第六Ready；以下准备期未执行/冻结段落为历史，下一R4b真实窄束。

当前R3已真实终态exit0（session99506/chunk ce79ec）：292 Godot301306/36 Python272，独立包64/71605与315资源/Main120/release通过；124源/六冻结项、34GPU源和10交付核对。一次R3邮件1a12a6d560f360a5。解除R3冻结，开始移动两规范R4测试并实际缺资源/授权RED；下方草稿未执行与冻结为准备期历史。

已在ignored build准备RiftObserverAttackResourceTest-draft-v1.gd，未执行、未导入UID、未放入runner、不算RED/GREEN；R3终态后才Move到规范位置实际测试。草稿约束虹膜合/张、双肘探针回收、交错环片及物理根不动，不把完成规格或未执行断言算资源产出。

同一等待期另备RiftObserverAttackGateTest-draft-v1.gd，独立资源授权检查而非6关胜利；未来实际缺observer新request RED后只加一项白名单。当前未执行，不更改生产Gate、manifest或旧覆盖银行，所有R3冻结源保持。

2026-10-11，用户授权自主美术，整体goal active。R3源124正在串行独立包/资源/release/full，当前仅准备下一契约，不改冻结GD，不运行第二Godot，不计R4 RED/GREEN或实际资源产出。R4a先独立资源动作，R4b–e才真实伤害/Actor；资源烘焙不是Boss战通过。

## 来源和已有骨架

当前实际核对原创v1：30 Bone2D，Torso/三组Leg–Shin–Foot、Keel/Counterweight、双ScopeArm–Elbow–Probe、Beacon、六Segment的RingHub、Lens/IrisL/IrisR/Pupil，五个新原生非攻击动作与四Marker。保留源v1场景SHA256 08fe69c6543d1e691256b800cc3b5a8560e84fa751d02d40852456099be6cbe8、v1库0525621d5092253b121f524e74982267c77227af6ef908a3bc2b303e286ac4ba；不是沿用改造前贴图和差动作。

优先核对免费参考：Kenney [Scribble Dungeons](https://kenney.nl/assets/scribble-dungeons)官方为2D、64px、CC0；[Space Kit](https://kenney.nl/assets/space-kit)官方为3D/CC0，只作为可核对许可的通用设备资源候选，不导入、不改变2D方向。[官方使用说明](https://kenney.nl/support)区分资产CC0与保留的Kenney标志。本轮只读网页文本，无下载/购买/安装/资源复制；尚未查看这些包的完整逐项图片，不宣称已审查所有造型或采用其具体图案。新动作关键帧/解剖和资源保持项目原创，付费作品不得提取/描摹。

## R4a具体动作方向

另建rift_observer_paper_v2.tscn、外置rift_observer_motion_v2.tres与独立manifest/checkpoint。新增beam/probes/refract各warning/attack/recovery共九片段，连同五个已原创非攻击基础片段共十四；基线全骨rig/skin/rest和原生基础动画不覆盖，旧名册/全角色审查与旧包保持。

- beam：三足屈膝固定基座，镜片轻回收/左右虹膜合拢、瞳孔聚焦，活动开光圈与镜片回弹，配重反向摆缓冲；不能把idle身体贴一根线冒充攻击。Torso最多小位移/小角度，物理Character根不动。视觉片段候选0.30/0.12/0.45秒，实际攻击时钟最终单独验明，不从动画轨道发伤害。
- probes：左右ScopeArm、各Elbow与Probe各关节分开。准备收臂锁位、活动先左后右探针伸向两个受限落点、回收与三足稳定；不是钟祭悬链/往返钟锤换皮，也不是双臂整块旋转。视觉片段候选0.32/0.56/0.52秒；左右真实SensorOrigin须随关节位移，各自世界镜像/墙边出生安全另外实测。
- refract：六Segment成两组交错微张开，保持中间负形间隙和固定RingHub，不整圈持续360旋转；Beacon、Lens/虹膜与配重相互响应，分节活动前后有可见收束。视觉片段候选0.30/0.60/0.60秒，至少三次分批峰值、有限恢复，回到rest而非继续旋转。

所有warning→attack→recovery同一骨轨道集合，端点连续且最后回rest。只Skeleton骨position/rotation/scale TYPE_VALUE轨道，禁止物理根、Facing整体旋转、modulate/透明度、方法事件/伤害/动画自带第二clock；需要限值而非无穷放大。取消每骨rest，死亡不能cancel复活。画面框由实际连续GPU最远点+有限余量测量；不能只放大声明框来掩盖裁切，物理半径不随视觉框变化。

实际骨挂点四个保持：Pupil/AimOrigin、左/右Probe/SensorOrigin、Beacon/PhaseOrigin。不是新建静止Node偏移假装在动画关节上。每个动作必须有对应解剖的局部独立运动、连续像素变化与实际挂点位置证据。

## 制作前语义RED与工程门

1. R3终态通过后添加规范RiftObserverAttackResourceTest，先缺v2场景/库/manifest语义RED。新checkpoint只授权observer v2→原创observer v1，Gate白名单和拒绝测试同步TDD扩展，不能修改旧coverage/review hashes或放开任意路径。旧大体rig资源齐备门仍有效。
2. 小组BakeRiftObserverActions+九动作参数、独立v2资源、manifest/checkpoint：新资源ResourceSaver正常烘焙，已有输出拒绝覆盖、导入生成UID；资源测试覆盖14片段/30骨/全不透明权重、基线键相同、每段至少八独立骨变化、真实镜片/虹膜/三足、双肘探针和交错环片、连续端点/rest、四Marker和根身份。
3. 薄NativeRiftObserverMotion只读唯一combat action_stage/elapsed，入场/步行/受击/动作/取消/死亡按当前生产adapter契约。先测试假Driver的纯适配器，不把假Driver动作写入当真实Boss；未来Actor另验入口/phase/攻击时钟。
4. 实际GPU双镜像、基础/九片段三时点、hit shader、各活动30连续帧及小尺度同屏；0半透明主体/0视口边缘裁切，非死亡在声明框，动画变化至少20/29邻帧，相关挂点跨度>8px。最少view实看完整姿态/连续序列，不以摘要/状态代替像素。
5. 专项+UID+当前独立PCK资源/适配器同源加载，阶段R4e全部实战完成才full/R4邮件；R4a只是资源切片，不发送整阶段完成邮件，不开放第六。

## R4b–e留给实际机制规格的关键限制

虹膜窄短束锁定而不追踪、双探针两个有限落点、环片有间隙的分批短碎片。Boss战关闭地图机关；实际半径候选56需沿用R1通行结果，若变动必须重测地图。三个作用几何由唯一有限时钟提供给视觉/判定，薄墙和出生安全真实物理成立；普通235/16.9玩家0.15秒反应、30/60/120Hz躲避与站立扣血对照，长帧安全取消不补发多轮。不会通过改PlayerHP/速度/无敌、瞬移或者假Boss击杀“过关”。

HP/伤害/落点/射线/碎片批次最终数值尚未锁定，不凭资源时长签可躲避或平衡；三招分别先针对性真实geometry RED/物理与生命周期验证，再装配Actor阶段/取景/血条/短头标/死亡，之后R5才接正式第六进度和保存。长期目标F1–F4仍是独立必须完成门。
