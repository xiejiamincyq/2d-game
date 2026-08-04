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
| `player_base` | actor | 玩家机体主体 | 1024×1024 | 64×64 | `res://assets/art/actors/player/player_base.png` | style-approved |
| `player_directional_atlas` | actor | 玩家射击朝向 72 帧图集，每 5° 一帧 | 1024×1024 母图 | 64×64/帧 | `res://assets/art/actors/player/player_directional_atlas.png` | style-approved |
| `player_weapon` | actor | 独立旋转的主武器 | 1024×1024 | 64×64 | `res://assets/art/actors/player/player_weapon.png` | style-approved |
| `enemy_scrapper` | enemy | 标准追击敌人 | 1024×1024 | 64×64 | `res://assets/art/actors/enemies/enemy_scrapper.png` | style-approved |
| `enemy_dasher` | enemy | 高速疾冲敌人 | 1024×1024 | 64×64 | `res://assets/art/actors/enemies/enemy_dasher.png` | planned |
| `enemy_spitter` | enemy | 酸液远程敌人 | 1024×1024 | 64×64 | `res://assets/art/actors/enemies/enemy_spitter.png` | planned |
| `enemy_bruiser` | enemy | 大型重装敌人 | 1024×1024 | 96×96 | `res://assets/art/actors/enemies/enemy_bruiser.png` | style-approved |
| `drone_scrap` | actor | 玩家环绕无人机 | 1024×1024 | 32×32 | `res://assets/art/actors/drones/drone_scrap.png` | planned |
| `projectile_player` | effect | 玩家橙色弹丸 | 1024×1024 | 16×16 | `res://assets/art/effects/projectiles/projectile_player.png` | planned |
| `projectile_spitter` | effect | Spitter 酸液弹 | 1024×1024 | 20×20 | `res://assets/art/effects/projectiles/projectile_spitter.png` | planned |
| `pickup_experience` | pickup | 经验晶片 | 512×512 | 24×24 | `res://assets/art/pickups/pickup_experience.png` | planned |
| `pickup_shield` | pickup | 护盾拾取物 | 512×512 | 28×28 | `res://assets/art/pickups/pickup_shield.png` | planned |
| `hit_spark_basic` | effect | 基础命中火花 | 1024×1024 | 48×48 | `res://assets/art/effects/combat/hit_spark_basic.png` | style-approved |

## 首次风格门

- 固定内容：玩家、Scrapper、Bruiser、基础命中火花。
- 固定布局：左上玩家、右上 Scrapper、左下 Bruiser、右下命中火花。
- 固定镜头：俯视三分之四视角。
- 固定色彩职责：友方青、敌方洋红、武器和命中橙；本轮不使用酸绿。
- 预览方向：A 战术图形插画、B 废土手绘工业、C 微缩 PBR 模型。
- 用户选择前，`player_base` 和预览集不得进入 `style-approved`。

## 方向帧与敌人朝向合同

- 玩家完整覆盖 360°，按每 5° 一帧计算为 72 帧；帧 0 面向右方，后续帧按顺时针排列。
- 玩家方向帧必须从同一批准母图确定性生成，不允许逐帧重画造成身份、装甲、色板或光照漂移。
- 玩家独立主武器继续按实际射击角度连续旋转，玩家机体选择最接近的 5° 帧。
- 普通敌人和 Bruiser 暂时只制作一张面向右方的透明母图；当玩家位于敌人左侧时运行时水平翻转，使敌人始终朝向玩家。
