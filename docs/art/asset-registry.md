# 美术资产台账

## 审查状态

- `planned`：已登记，尚未建立生成 manifest。
- `preview`：已有风格预览 manifest，等待用户选择。
- `draft`：已按选定风格制作草稿。
- `style-approved`：风格已锁定。
- `gameplay-approved`：Godot 实际尺寸验收通过。
- `final`：玩法与授权审查均完成。

## 角色与战斗批次

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

## 当前生产运行资源

- 玩家：`player_m2_ready_120yaw.png`、`player_m2_move_120yaw.png`、`player_m2_fire_120yaw.png`。
- Dasher：`enemy_dasher_a_actions_runtime_v1.png`、`enemy_dasher_b_actions_runtime_v1.png`。
- 非 Dasher：上表六张 `gameplay-approved` 单帧母版。
- 完整玩法与性能结论见 `docs/art/reviews/five-minute-overdrive-art-audit-2026-08-18.md`。
- 所有生成素材的 `license_review_state` 仍为 `pending`；在来源和使用权审查完成前不得标为 `final`。

## 已锁定的多视角与敌人朝向合同

- 旧的单图屏幕旋转和投影混合 72/120 帧方案已经撤销，仅作历史对照，不进入正式包。
- 当前 M2 方案重新以真实 3D 世界偏航烘焙 120 个方向，每 3°一帧；它与旧屏幕旋转方案不是同一技术路径。
- 镜头固定为严格 45°俯视正交相机；角色始终直立，只绕世界竖轴改变朝向，帧 0 面向右方。
- 玩家本体与枪械在源模型中保持独立对象，但运行图集来自同一 rig、相机和深度缓冲，禁止重新引入屏幕空间独立枪械旋转。
- Dasher A/B 使用三帧移动和预备、突击、恢复动作，并根据玩家位置水平翻转。
- 其他六类敌人当前批准范围为一张面向右方的正式母版并水平翻转；新增移动或攻击动画属于后续扩展。
