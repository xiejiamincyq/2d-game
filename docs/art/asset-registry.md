# 美术资产台账

## 审查状态

- `planned`：已登记，尚未建立生成 manifest。
- `preview`：已有风格预览 manifest，等待用户选择。
- `draft`：已按选定风格制作草稿。
- `style-approved`：风格已锁定。
- `gameplay-approved`：Godot 实际尺寸验收通过。
- `final`：玩法与授权审查均完成。

## 当前角色与战斗运行资源（2D Q版）

本节与下方环境表是当前位图清单。以 `Player.gd`、`Enemy.gd`、`OverseerBoss.gd`、`CombatVfx.gd` 的运行引用为依据；10份对应 chibi production manifest 保留原有 `style-approved`，本次仅补登记，不提升为 `gameplay-approved` 或 `final`。完整来源边界见[现行来源复核](reviews/runtime-source-reconciliation-v2.md)。

| Asset ID | 类别 | 用途 | 源尺寸 | 运行时目标 | 目标路径 | 状态 |
|---|---|---|---:|---:|---|---|
| `player_chibi_b_cardinal` | actor | 前/后/左/右身体，2×2图集 | 1536×1024 | 256×256图集；128×128/格 | `res://assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png` | style-approved |
| `player_weapon_chibi_b` | actor | 四向枪械，身体挂点固定分层 | 1536×1024 | 256×256图集；128×128/格 | `res://assets/art/actors/player/player_chibi_b_weapon_cardinal_atlas_v1.png` | style-approved |
| `enemy_scrapper_chibi_b` | enemy | 标准追击敌人 | 1254×1254 | 128×128单帧 | `res://assets/art/actors/enemies/enemy_scrapper_chibi_b_v1.png` | style-approved |
| `enemy_dasher_chibi_b` | enemy | 冲锋怪；不使用旧A/B动作图集 | 2048×1024 | 128×128单帧 | `res://assets/art/actors/enemies/enemy_dasher_chibi_b_v1.png` | style-approved |
| `enemy_spitter_chibi_b` | enemy | 酸液远程敌人 | 2048×1024 | 128×128单帧 | `res://assets/art/actors/enemies/enemy_spitter_chibi_b_v1.png` | style-approved |
| `enemy_bruiser_chibi_b` | enemy | 大型近战敌人 | 1402×1122 | 128×128单帧 | `res://assets/art/actors/enemies/enemy_bruiser_chibi_b_v1.png` | style-approved |
| `enemy_marksman_chibi_b` | enemy | 狙击手 | 2048×1024 | 128×128单帧 | `res://assets/art/actors/enemies/enemy_marksman_chibi_b_v1.png` | style-approved |
| `enemy_lobber_chibi_b` | enemy | 投弹手 | 2048×1024 | 128×128单帧 | `res://assets/art/actors/enemies/enemy_lobber_chibi_b_v1.png` | style-approved |
| `enemy_overseer_chibi_b` | enemy | Enemy的Overseer纹理及独立最终Boss共用 | 2048×1024 | 128×128单帧 | `res://assets/art/actors/enemies/enemy_overseer_chibi_b_v1.png` | style-approved |
| `combat_hit` | effect | 命中反馈贴图 | 1254×1254 | 128×128贴图 | `res://assets/art/effects/combat_hit_chibi_b_v1.png` | style-approved |

源尺寸是 manifest 的生成/处理声明；实际PNG尺寸与屏幕绘制尺寸是不同概念。玩家身体每格绘制84×84，侧向武器72×72、前后武器58×58；敌人与Boss按脚本缩放。敌人是单张贴图加程序化运动/攻击反馈，不是新增手绘逐帧动画。其来源与像素再处理未因登记而重新验收。

## 历史角色与战斗批次（非当前运行清单）

以下状态只保留旧 manifest 的审查记录，不代表当前角色批准范围。`planned` 是旧位图计划，不能据此认定程序化弹丸、拾取物或无人机功能尚未实现。

| Asset ID | 类别 | 用途 | 源尺寸 | 运行时目标 | 目标路径 | 状态 |
|---|---|---|---:|---:|---|---|
| `player_base` | actor | 玩家机体设计母版；待严格 45°相机重制 | 1024×1024 | 64×64 | `res://assets/art/actors/player/player_base.png` | draft |
| `player_directional_atlas` | actor | 已否决的屏幕平面旋转 72 帧图集，仅作历史对照 | 1024×1024 母图 | 64×64/帧 | `res://assets/art/actors/player/player_directional_atlas.png` | draft |
| `player_turnaround` | actor | 已否决的 120 帧投影混合转身，等待严格 45°方案替换 | 1024×1024/关键视角 | 64×64/帧 | `res://assets/art/actors/player/player_turnaround_atlas.png` | draft |
| `player_weapon` | actor | 玩家武器设计母版；待同相机方向帧与 socket 重制 | 1024×1024 | 64×64 | `res://assets/art/actors/player/player_weapon.png` | draft |
| `enemy_scrapper` | enemy | 标准追击敌人单帧母版 | 1254×1254 | 128×128 | `res://assets/art/actors/enemies/enemy_scrapper.png` | gameplay-approved |
| `enemy_dasher_a` | enemy | Dasher A 身份母版；生产运行时使用动作图集 | 1024×1024 | 64×64 | `res://assets/art/actors/enemies/enemy_dasher_a.png` | draft |
| `enemy_dasher_b` | enemy | Dasher B 身份母版；生产运行时使用动作图集 | 1024×1024 | 64×64 | `res://assets/art/actors/enemies/enemy_dasher_b.png` | draft |
| `enemy_spitter` | enemy | 酸液远程敌人单帧母版 | 1254×1254 | 128×128 | `res://assets/art/actors/enemies/enemy_spitter.png` | gameplay-approved |
| `enemy_bruiser` | enemy | 大型重装敌人单帧母版 | 1254×1254 | 128×128 | `res://assets/art/actors/enemies/enemy_bruiser.png` | gameplay-approved |
| `enemy_marksman` | enemy | 狙击手单帧母版 | 1536×1024 | 128×128 | `res://assets/art/actors/enemies/enemy_marksman.png` | gameplay-approved |
| `enemy_lobber` | enemy | 投弹手单帧母版 | 1254×1254 | 128×128 | `res://assets/art/actors/enemies/enemy_lobber.png` | gameplay-approved |
| `enemy_overseer` | enemy | Overseer 单帧母版 | 1254×1254 | 128×128 | `res://assets/art/actors/enemies/enemy_overseer.png` | gameplay-approved |
| `drone_scrap` | actor | 玩家环绕无人机 | 1024×1024 | 32×32 | `res://assets/art/actors/drones/drone_scrap.png` | planned |
| `projectile_player` | effect | 玩家橙色弹丸 | 1024×1024 | 16×16 | `res://assets/art/effects/projectiles/projectile_player.png` | planned |
| `projectile_spitter` | effect | Spitter 酸液弹 | 1024×1024 | 20×20 | `res://assets/art/effects/projectiles/projectile_spitter.png` | planned |
| `pickup_experience` | pickup | 经验晶片 | 512×512 | 24×24 | `res://assets/art/pickups/pickup_experience.png` | planned |
| `pickup_shield` | pickup | 护盾拾取物 | 512×512 | 28×28 | `res://assets/art/pickups/pickup_shield.png` | planned |
| `hit_spark_basic` | effect | 基础命中火花 | 1024×1024 | 48×48 | `res://assets/art/effects/combat/hit_spark_basic.png` | planned |

## 当前环境运行资源

### B 薄荷实验农场（2D Q版）

| Asset ID | 类别 | 用途 | 源尺寸 | 运行时目标 | 目标路径 | 状态 |
|---|---|---|---:|---:|---|---|
| `mint_farm_floor_b_v1` | environment | B 薄荷灰平铺地面 | 1254×1254 | 512×512/重复单元 | `res://assets/art/environment/mint_farm_floor_b_v1.png` | draft |
| `mint_farm_props_b_v1` | environment | 四类障碍共享图集，保留碰撞足迹 | 原始2172×724；无缩放重排1088×1088 | 宽120–220/保持比例 | `res://assets/art/environment/mint_farm_props_b_packed_v1.png` | draft |

环境已进入随机地图运行时；验收与剩余问题见 `docs/art/previews/environment/mint-farm-review-v1.md`。本节仍保持 `draft`；源记录和授权状态未提升。

12张现行位图均为 `license_review_state: pending`；不因运行接入、风格批准、技术测试或台账校验而标为 `final`。台账验证器不穷举运行依赖，环境 manifest 不在其 production 文件名扫描范围；回归测试另对这12份 manifest 检查登记路径/状态一致性。

## 历史生产资源与转身合同（已被2D Q版替代）

下列为 2026-08 阶段记录，不是当前生产配置或继续制作要求：

- 玩家：`player_m2_ready_120yaw.png`、`player_m2_move_120yaw.png`、`player_m2_fire_120yaw.png`。
- Dasher：`enemy_dasher_a_actions_runtime_v1.png`、`enemy_dasher_b_actions_runtime_v1.png`。
- 非 Dasher：上表六张 `gameplay-approved` 单帧母版。
- 完整玩法与性能结论见 `docs/art/reviews/five-minute-overdrive-art-audit-2026-08-18.md`。
- 所有生成素材的 `license_review_state` 仍为 `pending`；在来源和使用权审查完成前不得标为 `final`。

- 旧的单图屏幕旋转和投影混合72/120帧方案已经撤销，仅作历史对照，不属于当前玩法；是否在包内须查实际包清单，不能由未引用推断。
- 当时 M2 方案以真实3D世界偏航烘焙120向、每3°一帧，与旧屏幕旋转路径不同；后来同样撤销。
- 当时镜头为严格45°俯视正交相机，本体与枪械来自同一rig/相机/深度缓冲；这不是现行2D四向挂点方案。
- 当时 Dasher A/B 使用移动、预备、突击、恢复动作图集；当前替换为上表Q版单帧加程序化表现。
- 三个 `player_m2_*_120yaw.png` 源文件仍保留，已精确排除导出；实际包验证见[包精简报告](../m2-package-review-v1.md)。其他旧贴图是否仍在包内不能从“未被玩法引用”推断，本次不删除或扩大排除项。
