# R4d 分节折射：实施前契约

本契约的d0–d3现已按[实际切片审查](rift-observer-refract-complete-review-v1.md)闭合。以下是实施前记录；其“refract拒绝/待做”已历史。当前三招手动可启动，自动循环仍beam，R4e/第六Ready/完整目标仍未完成。

R4c按[真实审查](rift-observer-probes-complete-review-v1.md)闭合，其旧同源包在d0改源后已历史。原创30骨v2六环片交错张开所解释的有限碎片，不是钟祭整环三向弹、雷网或无限旋转。用户自主美术授权有效，不安装/购买/抄收费资源；当前refract仍拒绝、Ready仍1–5。d0已按[保持行为的独立提取审查](rift-observer-circle-flight-review-v1.md)验证，以下d1–3仍是实施前候选计划，不是已验玩法。

## 候选机制与内部接口

唯一Observer Director控制warning0.30 / active0.60 / recovery0.60。预警只有短头标，开始时锁定当前Beacon/PhaseOrigin到目标的方向，不追踪。三批释放对应原生峰值0.18/0.48/0.78，即active0.108/0.288/0.468；实际帧先采样姿态，再严格从当前真实挂点出生。受薄墙/边界阻止不改Boss中心，不补帧。30Hz末批最迟量化0.50。

每批最多三枚、整轮最多九枚，候选角组[-0.32,-0.16,+0.16]、[-0.16,+0.16,+0.32]、[-0.32,0,+0.32]弧度，非均匀整圈。前两批中线留负形空隙，末批有一枚锁定中线，站立必须真实受伤；间隙本身需要真实geometry控制，不能只在说明中写“有间隙”。

候选半径4px/最大路径360px/单向飞行0.09秒/无驻留/基础8×3=24伤害；末批0.50+0.09=0.59须在active0.60内结束。所有九枚共享一轮attempt字典，先置尝试再真实Health调用，去掉无敌也不重复。薄墨边小纸三角须在真实圆体+有限1px描边内，不长射线/全屏光。只读弹体z22仍低于血条23/头标24，不改变角色本体透明度或物理根。

arm(actual Actor,actual Player,true origin,locked end,attempt)->bool；resolve_hit(before age,after age,previous Player,current Player)；draw_visual(canvas)；cancel。飞行内核不另开timer/process/physics，elapsed及合法Player段只由Director供应。有限坐标/时间、实际1|QUERY_LAYER薄墙/动态标记/32饱和、零时间与出生无提前伤害、相对圆扫掠/寿命尾段裁剪、最后合法像素/下一tick无伤害取消、Owner/目标/容器/暂停/隐身/phase/death/reentry都沿已验证门。

数字只是候选，不是已验平衡。普通Player始终235px/s、16.9px、HP100、正常碰撞，无盾/冲刺/隐身/瞬移。若0.15秒反应自然躲避或站立对照不成立，保留失败、定位原因，仅有依据地改本招候选规则并重测，不能改Player或删失败例过关。

## 结构与顺序

避免复制百行Probe或祭司弹体；先独立保持行为的窄提取，再新增伤害。有限圆飞行公共逻辑留Observer组件，不向公共Boss/存档模块泄漏分批策略。

- d0：缺Observer专属有限圆飞行内核资源语义RED；提取已验证上下文/路径/查询/时间/相对扫掠/共享attempt。Probe原6/360/0.12+0.08/27与画法保持；固定动作配置不得在armed时随便变。最多3GD一增量，Probe101/分段37/出生64/实际766、普通输入与beam回归后才d1。本步不放开refract。
- d1：新Fragment固定候选配置/小三角显示，规范缺资源RED；实际圆体/0.09寿命/无驻留/薄墙/九枚共享尝试/重入/取消GREEN。复用有限内核，无自己的physics。最多3GD。
- d2：真实Director拒绝refract RED，再唯一导演三批/九槽/间隙、出生当帧、锁定、无补发、取消。只在开始/推进/绘制/取消小分派路由，不在Beam/Probe路径散加条件。白名单测试分两个小增量更新，只放开已实现动作；各≤3GD。
- d3：30/60/120Hz六方向、0.15秒普通输入18躲避/18站立受24伤害与额外间隙控制；实际第六地图1280双镜像每批小脚印/末帧/暂停逐图查看，正常UID、当前源SHA/最新独立PCK、已有两招回归。Dodge/GPU≤2GD，其后runner/包证据单独。不把受控GPU称自然整场胜利。

Godot严格串行。d0改变旧Probe源后，当前R4c的81源银行只是历史，不能称其仍是“当前同源”。结构提取和新攻击不在一个未验证大补丁内混做；异常先停线排错再跨依赖。

## 工程、命令与验收

生产scripts/components、规范scripts/tests、作者scripts/art、交付docs/art/previews/campaign、ignored build/diagnostics/campaign-goal证据；Godot4.7/typed GDScript/tab/snake_case。使用已有引擎/查询/Health/原生资源，不新增工具。UID正常导入，作者/test/docs排除不放开；独立包只复制同SHA规范夹具到包外。

```powershell
$engine='C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
& $engine --headless --path . --audio-driver Dummy --max-fps 120 --script res://scripts/tests/RiftObserverProbeTest.gd --quit-after 3000
# Future fixtures are named before creation; not executed yet.
```

验收必须actual terminal exit0/唯一正数PASS/无SCRIPT ERROR、ERROR、TEST FAIL、对象/RID/资源泄漏；GPU真设备且实际逐图查看。Always先RED/保持Probe/正常Player/真实挂点显示判定同源；Ask first新工具/费用/权限/公开发布；Never真实保存假解锁、抄收费造型、全根旋转、动画发伤害或第二clock。R4e才三招自动轮换、完整Health阶段/移动/取景/生命周期/连续GPU、全量和一次阶段Gmail；R5/F1–F4继续独立，不中间commit/push或Goal complete。
