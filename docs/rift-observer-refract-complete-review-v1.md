# R4d 分节折射通过；完整Boss与第六关仍未完成

2026-10-11，分支5分钟超载、HEAD713dde5f。按[实施前契约](rift-observer-refract-contract-v1.md)依序完成d0–d3；没有把结构提取和新伤害混在一个未验大补丁里。实际Actor现在可手动启动beam/probes/refract，自动循环暂仍beam，R4e继续。Ready仍1–5，默认开始仍旧试玩；R5/F1–F4保留。无中间提交/推送/切片邮件/公开发布。

## 实际机制

warning0.30/active0.60/recovery0.60，短头顶感叹号。唯一Director在warning开始锁定当前真实Beacon方向与有限路径长度；不追踪。三批0.108/0.288/0.468秒附近量化到实际帧，每批三个，固定角组[-0.32,-0.16,+0.16]、[-0.16,+0.16,+0.32]、[-0.32,0,+0.32]，不是全圈或持续旋转。前两批中线有真实空隙，第三批反制站立；不宣称所有距离的间隙都可容纳玩家。

实际当前骨挂点严格出生，墙/边界不改用Boss中心，受阻也消费槽，不事后补发。最多九个RefCounted槽，由Observer局部Volley管理三批策略；通用Boss/Health/存档没有新攻击策略。Fragment复用[d0窄有限圆内核](rift-observer-circle-flight-review-v1.md)，不复制Probe/祭司弹体，不另开Node/timer/process/physics。半径4、最长360、飞行0.09、无驻留、8×3=24伤害；固定profile在arm时double标量快照。九枚共享一次attempt，先写账本再真实Health，免疫拒绝也不重试。30Hz末批最晚0.50出生、0.59结束，不越过active。

真实相对圆扫掠/寿命裁剪/最后合法可见帧/下一tick取消，1|QUERY_LAYER全路径薄墙与32饱和门沿共享内核。Director只在开始、推进、绘制、取消窄分派；暂停/隐藏/长帧/实际Health阶段/死亡和伤害回调重入取消全部实体。只读弹体Canvas仍z22，血条23/头标24，beam层−1未改；物理根ONE、不旋转，角色主体不透明。

## 失败与修复

- d0第一测试是解析错误，不计语义RED；修正测试的实例调用后，缺内核资源exit1才提取。d0实际8受控与两招普通physics回归通过，审查单列。
- Fragment资源缺失实际exit1（5e2394），才实现固定叶组件；113项GREEN（5512d1）。真实圆半径、六向/时间相交与异时不相交、无驻留/尾帧、九共享/免疫、薄墙、非法输入、暂停、隐身、重入都有实际Owner/Player/Health。
- 实际Director拒绝refract语义RED（12be25），才添加Volley与窄路由；660项GREEN（7c151f）。三physics率双镜像/九真出生/锁定/无追踪/三批收尾、两批中线gap、第三24伤害、受阻不替身或补发、四类取消/真实阶段/死亡/回调重入。
- 两个旧测试仍断言“refract未实现”，真实exit1保留（655919内两引擎exit1，外层收集器exit0不算测试通过）。仅更新为已实现refract可启动并取消，unknown仍拒绝，不删除原Beam/Probe断言。最终ProbeAttack767、BeamClock34及其余十专项全通过（5bc26c）。
- GPU v1虽729项/十图通过，实际逐图发现内填色被2px线描边挤掉，碎片看起来像亮线。补1x可见纸色检查后GPU v2实际exit1（b55b2b），不是把旧自动通过当视觉合格。改为R4内填纸三角、R5内有限墨外三角和小珊瑚芯，不改判定/射程/伤害；v3每片实际10–14纸像素/12–19墨像素，5199项GREEN。墨色计数改为0.02严格色距，避免把近色地板算成描边。
- 首次包调用误写了不存在的旧Boss夹具名称，在预检止步、尚未生成PCK；保留driver-v1失败日志。读取上轮真实规范夹具名单后修正调用，不改排除规则或测试。最终v2包真实exit0。

## 普通物理与当前GPU

30/60/120Hz×六方向：普通输入在预警至少0.15秒后开始横移，18次HP100，18站立HP76。工作区7168项/1716真实相邻位移actualexit0（f11880）；Player100/235/16.9、无盾/冲刺/隐身/瞬移/禁碰撞。当前包同规范再次7167项；调度计数不同分别记录，不拼成一次。原两招正常输入也在当前包重新验证。

真实NVIDIA RTX5060 Laptop/OpenGL，第六地图seed521、30骨实际Actor/Player/BossHealthBar，1280×720双镜像。GPU v3 actualexit0（4dcb68），5199项/十图全部实际查看；49源SHA保持、11交付文件相同。短头标、每批小三角、无驻留最后合法帧、实际暂停像素和判定清除；额外实际站立gap及HP76/不重复。受控Player移动只为露出精确像素，不冒称自然躲避、整场胜利或真人验收。

[第一批](art/previews/campaign/rift-observer-refract-v1/batch1-1.png)、[第二批](art/previews/campaign/rift-observer-refract-v1/batch2-1.png)、[第三批末帧](art/previews/campaign/rift-observer-refract-v1/batch3-1.png)、[暂停清除](art/previews/campaign/rift-observer-refract-v1/cancelled-1.png)、[报告](art/previews/campaign/rift-observer-refract-v1/report.json)。报告SHA256 9e25aa7c279fb7e608604308647813121cee7b30fa1661f37678fef8130ed064。八新GD/UID正常导入，UID与打包策略10测试实际exit0；docs图片自动生成的十.import属ignored本地导入状态，不计交付、不提交。

## 当前同源独立包

终态21规范夹具/21415项、Main120、88证据源保持actualexit0（7aca75）：原生资源359/名册644/Motion33、Beam86/Clock34/正常2835/Origin58、旧Boss12/17/17/50与取景1862、Probe101/分段37/出生64/实际767/正常6479，以及新20/113/660/7167。22规范/支持文件同SHA、23日志无错误或对象/RID/资源泄漏。包外夹具使用--main-pack而非--path，作者/tests/docs仍排除，没有放开旧资源禁入规则。

PCK7099956字节，SHA256 dbfba0533a63339f9157a05becbbce75f1dd2b958ec097f47ee05359b4043dba，低于30MiB。证据`build/diagnostics/campaign-goal/rift-observer-refract-pack-v2/`，完整当前source/delivery/UID银行和实际终态收据`rift-observer-refract-complete-v1.json`。旧R4b/c包与GPU仍保留为历史，不能称当前同源。

五轴自审：时间/扫掠/真实出生由唯一clock，策略局部且有界；内核减少重复、叶组件仅profile/画法；有限输入与32查询饱和拒绝，无新依赖/外部I/O/秘密；只在出生分配最多九胶囊，热帧有界九槽，无第二clock。可签R4d切片，不能签全量最新回归、完整自动Boss、Ready6/真实保存6、六关连续链、构筑平衡、密集性能或整目标。按现有计划继续R4e自动三招/完整生命周期与连续GPU/full，再R5/F1–F4；阶段邮件留R4e，完整目标完成后才提交推送。
