# 原生巡界无人机审查 v1

2026-10-11；`5分钟超载` 未提交工作；长期目标 active。

## 原创资源与接入

新增 `ranger_drone_paper_v1.tscn`、外置 `ranger_drone_motion_v1.tres`。10真实关节/10完整皮肤绑定：主体、头/镜头、双翼/两翼尖、尾片、枪/喷口。奶油纸壳、青绿翼片与镜头、铜支架小型机械轮廓，与玩家同阵营；作者几何全新设计，仅共用不透明描边/权重工具，无外部图片、无抄描付费角色。

五新动作为idle / walk（飞行）/ shoot（持续激光姿态）/ entrance（展翼）/ death（收翼坠落）。所有轨道只控制真实关节；资源中的终止死亡保留，但当前真实移除无人机由Player立即清理，不宣称已经接入退出动画。

实际 `Player::_sync_drone_visuals` 创建的 `DroneVisual` 改为挂载新骨骼资源，不再画旧圆/矩形。Player在激光目标和伤害计算后，按真实beam.visible喂给纯视觉采样器；无人机没有独立process/伤害/计时器。新增companion目录role，与ordinary/large/boss分开，不更改大型攻击延期门。

轨道旧读墙钟改读既有 `Player.visual_elapsed`。48px半径、均匀角距及1000/520 rad/s角速度保留，暂停后不跳相位；原激光伤害28.8、转向上限、宽度、索敌/燃烧计算和beam实际起点不变。新喷口是可编辑挂点，此阶段没有擅自改变射线命中起点。射击资源0.24s只是关节的视觉循环，不冒充新的战斗触发间隔。

## 测试与失败记录

- 资源RED v1为测试类型推断编译失败，不计有效RED；补显式Transform2D后 `drone-resource-red-v2.log` 正确因缺原生资源退出1。烘焙v1另有作者String类型推断失败，v2成功，没有覆盖已批准资源。
- 生产接入 `drone-integration-red-v1.log` 旧实际Player没有骨骼接口，退出1；`drone-integration-green-v1.log` 13检查通过（实际两无人机、展翼、冻结轨道/间距、开火/丢目标、真实伤害、无独立时钟、拒绝非有限delta、清理）。
- 新友军目录 `drone-catalog-red-v1.log` 被旧role拒绝，退出1；添加显式companion后9检查通过，包括错误路径/数量/角色/缺动作/透明/无证据final拒绝。
- 资源 `drone-resource-green-v2.log` 273检查通过：10骨/全顶点绑定透明、外库、五动作至少两骨运动、权威手动冻结、取消复位/终止死亡。
- 既有 `DroneVisualLifecycleTest` 7检查通过；边界保留持久beam/reticle、移除清理仍成立。
- `drone-full-v1.log`：172 Godot套件189670断言、36 Python套件272测试，全量退出0。包括上述三新增套件；没有跳过失败项。

## 画面验收

[五动作三相位预览](previews/campaign/native-drone-poses-v1.png)，列顺序idle/飞行/射击/展翼/死亡；行相位0/45%/85%。[实际Player/三个无人机/真实激光/真实Enemy夹具](previews/campaign/native-drone-production-v1.png)。不是自然Main游玩、不是六关就绪或密集物理性能证明。

- GPU v1参数中连字符不符合安全identifier，退出1，无生成资源；补充明确错误提示并使用新标识符。
- GPU v2主体30姿态通过，但自主查看发现背景z=0盖住真实绝对z=-1激光；旧“beam.visible”检查未证明攻击像素。v2保留，撤回其激光视觉通过结论，不重写旧report假装正确。
- 修正预览背景至z=-10并加入真实beam色像素正检查。权威 `drone_gpu_v3/report.json` / `drone-gpu-v3.log` 退出0与明确PASS：30身体姿态（两朝向×五动作×三相位），0半透明/0视口裁切；60飞行帧59相邻变化，实际2253beam色像素。主代理亲自查看两张图，自主采用style-approved，不签final/真人手感。
- [保存报告](previews/campaign/native-drone-opacity-v1.json) 的8个源SHA256在本阶段完成时逐个核对一致。

## 独立包和边界

`build/diagnostics/campaign-goal/drone-pack-v1/game.pck` 独立目录、无源码path运行：资源273、实际接入13、原生命周期7检查均明确PASS；Main120帧退出0，无错误/泄漏。PCK 5,527,952字节，SHA256 `12ee944c450bbc3b8010d28159ccc656e25cd475cd194c7f75faf08dead6520c`。标准 `drone-release-v1.log` 门通过，同大小、作者脚本/文档排除；仅本地诊断包，不覆盖旧EXE、不公开发布。

五轴自审：视觉层不控制伤害，新增热路径只遍历Player已经拥有的少量无人机并手动采样，资源共享、实例关节独立；没有安装第三方工具/运行库/网络依赖或秘密；未清理旧PNG/历史样板。没有用新增友军role绕过大型攻击门。整局混合AI/物理/渲染性能、最终美术和人类手感仍未验收。

无人机遗漏已补；下一步逐项审七基础EnemyKind、十二区域role、分裂/召唤生产入口、实际Boss/计划Boss资源以及玩家/伴随物的完整齐备清单，之后才考虑Checkpoint。第2至6关地图/导演/实际Boss尚未因此完成，大型新攻击此阶段仍未制作。用户要求整体长期任务完成后才提交/推送，当前不提交中间里程碑。
