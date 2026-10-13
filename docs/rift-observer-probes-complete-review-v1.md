# R4c 双探针切片通过；完整观测者与第六关仍未完成

当前分支5分钟超载、基线HEAD713dde5f。原创30骨Observer v2、实际Actor与唯一Director允许beam/probes；refract仍拒绝，自动攻击暂仍beam，三招轮换留R4e。第六Ready仍1–5，默认开始按钮仍旧试玩；R5与F1–F4没有因本切片通过而完成。

## 已实现行为

按[实施前契约](rift-observer-probes-contract-v1.md)，warning0.32/active0.56/recovery0.52；预警只有短头顶感叹号，warning开始锁定目标两侧18px落点。左0.1008/右0.2576附近，由唯一clock先采样实际原生动作、再取当帧各SensorOrigin出生。量化到实际30/60/120Hz帧，不倒补出生前伤害。每次最多两个释放槽，真实路径最多360px，半径6、单向飞行0.12/停留0.08，无返航/追踪/额外timer。两枚共享一次实际伤害尝试，9×3=27，先置账本再调用真实Health，清掉无敌也不补扣。

薄墙、世界边界、动态QUERY_LAYER与32接触饱和拒绝；普通未标记动态角色不是墙。暂停/隐身/换phase/死亡/Owner及目标容器离场取消沿唯一导演，清空两枚/头标，不追补长帧。不把受控geometry或GPU Player重新定位当自然躲避/整场胜利。

## 失败证据与修复

- 真正缺Probe资源与实际Director拒绝probes，分别语义RED后实现。c1初版有一个“不同时间相交”测试期望错误：保留其不命中对照，另加真正同时相交；不改玩家/生产几何凑结果。
- 零elapsed出生样本曾扣血：实际RED后改为只读不伤害，101项GREEN。独立测试审查随后给出飞行→停留跨帧两反例，实际RED（f9a088）确认漏判与误判；按0.12秒拆分真实相对轨迹，Player在原始帧时长中插值，37项GREEN（b8e8ae）。未把整帧弦线当实际运动。
- 集成测试首版误调用Health.take_damage，SCRIPT ERROR虽然引擎退出0仍判失败；只修测试为实际Actor.take_damage，最终有唯一正数PASS和无错才签收。
- 自然输入首版要求远斜向也必须两枚生成，真实左路径369/377px超360，正确拒绝而非漏生成。原两例保留为6+6自然超距控制，并增加近斜向18+18双探针对照；不加射程、不删失败样例、不放宽玩家统计。
- GPU v1实际失败（f9c816）：左实体穿过Boss时被本体遮住。新ProbeVisual只读Node2D使用现有弹体层z22，保持血条23/头标24与beam层−1，不带脚本/process/physics/第二clock。直接draw信号可绘制，依据[Godot CanvasItem官方说明](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)。新GPU通过且逐张查看，不靠放大特效遮掩。
- 出生进一步审查发现旧OriginSafety会退回Boss中心。规范测试先分辨“下一帧骨坐标”错误，再当帧真实RED v3（766e89）确认左右clear通过、1/2层薄墙及world六例失败。Actor只增加显式require_socket模式；Probe严格出生，受阻返回无效坐标并消费该臂槽，不补发/换中心，另一臂仍合法。64项GREEN（d0b820），旧共享helper及beam兼容行为不变。早期16夹具包保留为修复前历史，未冒充当前包。

## 当前专项与自然输入

当前101 primitive、37独立分段、64严格出生、766实际Director、33既有beam clock、58共享OriginSafety均实际exit0。真实Actor/Player/Health、左右出生当帧、定点、最多两槽、无提前伤害/无重复、恢复清理、长帧、暂停、隐身、换phase、伤害回调取消及实际Owner死亡均有专项。beam86及钟祭三招12/17/17、旧原生Boss50、取景1862在最新包回归，未称这些是全量最新回归。

自然physics普通输入覆盖30/60/120Hz、六个近距方向，至少0.15秒反应：18双探针横移HP100、18站立HP73；另外保留远斜向6躲避/6站立，左严格超距拒绝、右仍可躲/命中。玩家235px/s、16.9px、HP100、无盾/冲刺/隐身/禁碰撞，不在攻击中瞬移。严格出生修复前工作区6480项/2160真实相邻移动（b91b46）；修复后最新包再次6479项通过。自然调度计数不同分别记录，不相加伪称一次验证。

## 实际GPU与交付

真正NVIDIA/OpenGL、seed521第六地图、实际Observer/Player/BossHealthBar、1280×720左右镜像。唯一clock受控采样短头标、当帧左右出生与小脚印、单向外射、0.20秒末次合法落点仍可见、实际暂停后像素/判定清空、根身份与HUD安全区；额外实际站立Health73且第二枚不重复。为了露出落点像素的受控Player移动明确标注，不代替自然输入证据。

最终v3153项/10截图actualexit0（31df28）；十图全部实际查看。46源SHA保持，11交付文件逐SHA一致，见[左探针](art/previews/campaign/rift-observer-probes-v1/left-outbound-1.png)、[右探针](art/previews/campaign/rift-observer-probes-v1/right-outbound-1.png)、[末次落点](art/previews/campaign/rift-observer-probes-v1/right-last-1.png)、[实际报告](art/previews/campaign/rift-observer-probes-v1/report.json)。报告SHA256 871e30bb64c80c55967434ef627ba850a4a1f73b49556547bb1ff9d906c4be79。七新增源UID正常导入actualexit0；最终文档更新后的14项UID/包策略/历史状态检查及81源/11交付/当前PCK末次SHA再次通过（3319e6）。

## 最新独立运行包

严格出生修复后的v2包：17规范夹具/13453项、Main120、81证据源保持，整个命令真实actualexit0（d06b9b）。18规范夹具/支持文件同SHA，19日志无错误/泄漏；包不含test/作者/源图/docs，无放开排除规则。PCK 7094396字节，SHA256 de537a4a48c56b4d0b9c0f6627cb08f2ea68cbd94c8b9b41f5c93737fa5155d3，低于30MiB。当前证据快照：ignored build/diagnostics/campaign-goal/rift-observer-probes-complete-v1.json；旧失败与两个较早包均保留。

## 五轴审查与后续

正确性：先测试再实现，真实Health/几何和实际GPU/同源包互证，零帧、分段、遮挡及中心替身均已真实复现修复。可读性/架构：Probe约百行RefCounted，时序在Observer Director、两枚推进单helper、无公共Boss复制行为或新增依赖；三招完成前保持未实现动作拒绝门。安全：有限坐标/时间/真实层查询、有界两枚/32接触，未读取凭据/外部源内容执行、真实保存不碰。性能：每轮最多两对象/路径查询、短尾迹/四点菱形；未据此宣称密集性能通过。批准的是R4c切片，不是合并/发布或完整长期目标。

下一[R4d实施前契约](rift-observer-refract-contract-v1.md)环片有间隙的分批折射，尚无d0代码或RED；再R4e整场三招与Health阶段/移动/生命周期/取景、全量及一次阶段Gmail。R5真实第六Boss/save6/不产生7，F1正式开始、F2从新独立档连续六关、F3构筑重玩与风险收益、F4全文字/密集性能/许可/最新本机候选仍未完成。没有新安装/购买/参考资产复制、覆盖旧候选或真实保存，没有本切片邮件/commit/push/公开发布；Goal仍active。
