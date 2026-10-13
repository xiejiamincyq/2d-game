# 玩家四向原生目录契约审查 v1

2026-10-11；`5分钟超载` 未提交工作；长期目标 active。

## 决策与范围

玩家原生身体和四套七动作库未重制或修改，本阶段仅让已经实际接入的四向玩家进入统一 NativeCatalog。自主复核既有四向预览，沿用既定奶油/青绿纸偶方向；只登记 style-approved，不提升 final 或真人手感批准。

采用显式 `role=player / layout=cardinal_4` 子契约，保留四个独立方向、每向13骨和12身体皮肤绑定、手骨下独立刚性枪身。不能为了套用单 Facing NPC schema，把四向变成整体镜像或把枪纳入全身漂移。四个外置 AnimationLibrary 必须与声明逐一一致。既有NPC输入/错误返回契约不变，加权皮肤/rest检查抽为共享 NativeSkinGeometryValidator。玩家子契约还检查枪体基色/逐顶点透明、骨挂点与四向差异、所有轨道只写原生关节位置/转角/缩放。

接口设计技能影响：增加明确布局分派，而非改动运行时播放器或隐式猜测单骨架；没有新游戏逻辑或战斗参数。文档与分批验证不代表许可提前提交中间工作。

## 失败与实际验证

- `build/diagnostics/campaign-goal/player-catalog-red-v1.log`：旧统一校验不能接收四向契约，缺玩家几何入口；有效RED。
- `player-catalog-guards-red-v1.log`：裸Node输入和四向枪体逐顶点alpha缺少拒绝；有效RED。修复后 `player-catalog-NativePlayerCatalogTest-green-v2.log` 58检查通过；NPC `player-catalog-NativeArtValidatorTest-green-v2.log` 原36检查通过。
- 一次工具补丁上下文格式错误发生在包装器写入前，不计作有效RED；共享文件保留，修正补丁后继续验证，不重置工作区。
- 全量 `player-catalog-full-v1.log`：169 Godot套件189383断言、36 Python套件272测试通过。
- 独立已存在的 `cutter-pack-v1/game.pck` 中，实际Player集成 `player-catalog-integration-v1.log` 699检查通过。资源专项v1误用 FileAccess，误报导出重映射场景不存在，退出1保留。仅改测试为 ResourceLoader.exists；同一独立包v2及源码专项均3430检查通过，没有跳过资源动作检查。
- 该既有PCK SHA256为 `fe2767bcaa08af981632815012d43a51c4746e9a639064b4cc4c45cdc298978f`。这是当前验证旧包运行资源，不是假称新导出；目录/作者validator不进入运行包。玩家动作与身体未改，不重新包装相同alpha矩阵。
- `player-catalog-approved-v1.log`：23个目录声明通过（22个NPC声明包含历史Cinder v1/v2，另1个玩家）；不能说23种敌人或全部角色齐备。

上述全量在资源存在性测试修正之前；其后只运行受影响源码/独立包资源专项与状态变化的目录检查，不把顺序混写成一次全量包含所有后续文档变更。

## 全角色门仍关闭：确实缺无人机

实际生产 `Player.gd::_sync_drone_visuals` 创建 `DroneVisual.gd`。该脚本仍 `_draw()` 圆/矩形，不含新Skeleton2D或动作资源。玩家与敌人目录齐备不能掩盖友军伴随角色，因此下一步补原创环绕无人机骨骼、待机/飞行/射击/入场/退出动作并接真实Player管理生命周期，再审完整生产角色清单。

第2至6关地图/导演/实际Boss仍未因此完成；大型新攻击继续延期。未公开发布，未提交或推送中间里程碑。
