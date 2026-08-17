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
| `enemy_scrapper` | enemy | 标准追击敌人 | 1024×1024 | 64×64 | `res://assets/art/actors/enemies/enemy_scrapper.png` | planned |
| `enemy_dasher_a` | enemy | 保留 A 设计身份；待 45°投影与运动动画重制 | 1024×1024 | 64×64 | `res://assets/art/actors/enemies/enemy_dasher_a.png` | draft |
| `enemy_dasher_b` | enemy | 保留 B 设计身份；待 45°投影与运动动画重制 | 1024×1024 | 64×64 | `res://assets/art/actors/enemies/enemy_dasher_b.png` | draft |
| `enemy_spitter` | enemy | 酸液远程敌人 | 1024×1024 | 64×64 | `res://assets/art/actors/enemies/enemy_spitter.png` | planned |
| `enemy_bruiser` | enemy | 大型重装敌人 | 1024×1024 | 96×96 | `res://assets/art/actors/enemies/enemy_bruiser.png` | planned |
| `drone_scrap` | actor | 玩家环绕无人机 | 1024×1024 | 32×32 | `res://assets/art/actors/drones/drone_scrap.png` | planned |
| `projectile_player` | effect | 玩家橙色弹丸 | 1024×1024 | 16×16 | `res://assets/art/effects/projectiles/projectile_player.png` | planned |
| `projectile_spitter` | effect | Spitter 酸液弹 | 1024×1024 | 20×20 | `res://assets/art/effects/projectiles/projectile_spitter.png` | planned |
| `pickup_experience` | pickup | 经验晶片 | 512×512 | 24×24 | `res://assets/art/pickups/pickup_experience.png` | planned |
| `pickup_shield` | pickup | 护盾拾取物 | 512×512 | 28×28 | `res://assets/art/pickups/pickup_shield.png` | planned |
| `hit_spark_basic` | effect | 基础命中火花 | 1024×1024 | 48×48 | `res://assets/art/effects/combat/hit_spark_basic.png` | planned |

## 首次风格门

- 固定内容：玩家、Scrapper、Bruiser、基础命中火花。
- 固定布局：左上玩家、右上 Scrapper、左下 Bruiser、右下命中火花。
- 固定镜头：俯视三分之四视角。
- 固定色彩职责：友方青、敌方洋红、武器和命中橙；本轮不使用酸绿。
- 预览方向：A 战术图形插画、B 废土手绘工业、C 微缩 PBR 模型。
- 用户选择前，`player_base` 和预览集不得进入 `style-approved`。

## 恢复中的多视角与敌人朝向合同

- 2026-08-10 撤销“每 3° 一帧、共 120 帧”和“侧视枪械连续二维旋转”合同；它们不能继续作为生产验收标准。
- 镜头固定为严格 45°俯视正交相机；角色始终直立，只绕世界竖轴改变朝向，帧 0 面向右方。
- 玩家本体与枪械分层，但必须来自同一 rig、相机和方向合同，并为每个方向提供手部与枪口 socket、前后遮挡关系。
- 新方向数在 16 向、24 向和实时 2.5D 三套技术预览中选择；用户选择前不批量生产正式帧。
- 现有两套方向图集不得覆盖或删除，在替代方案接入前仅作为运行时临时兼容资源和历史对照，不得升高审批状态。
- 普通敌人和 Bruiser 可暂时使用一套面向右方的动作并水平翻转，但至少需要移动循环、攻击前摇、受击和死亡反馈。
