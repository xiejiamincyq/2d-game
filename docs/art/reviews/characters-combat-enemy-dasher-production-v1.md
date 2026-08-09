# ART-3C：Dasher A/B 正式资源 v1

## 结果

- 用户选择：同时保留 A 和 B；C 不进入正式制作。
- A 路径：`res://assets/art/actors/enemies/enemy_dasher_a.png`。
- B 路径：`res://assets/art/actors/enemies/enemy_dasher_b.png`。
- 两张母图均为 1024×1024 RGBA；运行时目标均为 64×64。
- 两张均固定朝右；当玩家位于敌人左侧时由运行时水平翻转。
- 本轮没有修改 Dasher 的碰撞、速度、生命、伤害或 AI。

## 生成与透明化

- 生成方式：内置 `imagegen`，以已批准预览和项目 style lock 为参考。
- 透明方式：生成绿色键控源图后，使用标准 `remove_chroma_key.py` 柔和蒙版与去色处理。
- 透明主体统一裁切到 1024×1024 画布，并保留约 7% 外边距。
- 授权状态仍为 `pending`，因此不得标记为 `final`。

## 64×64 实际尺寸检查

![Dasher A/B runtime comparison](../previews/characters-combat/enemy-dasher-production-runtime-comparison-v1.png)

- A：保留紧凑人形、楔形头盔和长冲刺腿，64×64 下仍可辨认。
- B：保留低伏底盘、双后置推进器和刀刃腿，64×64 下与人形敌人区分明显。

## 水平翻转检查

![Dasher A/B flip check](../previews/characters-combat/enemy-dasher-production-flip-check-v1.png)

翻转后 A、B 均保持完整轮廓，没有文字、非对称武器或方向性特效造成语义错误。

## 像素验证

| 资源 | 模式与尺寸 | 非透明边界 | 四角 Alpha | 键控绿残留 |
|---|---|---|---|---|
| A | RGBA 1024×1024 | `(72, 78)–(952, 945)` | 全部为 0 | 2 / 336984，可忽略且目视不可见 |
| B | RGBA 1024×1024 | `(72, 102)–(952, 921)` | 全部为 0 | 0 / 301949 |

## 当前审查状态

两张资源已通过选型、风格一致性、透明边缘、64×64 轮廓、水平翻转检查和 Godot 4.7 无界面导入，记录为 `style-approved`。尚未接入敌人渲染脚本，也未完成战场场景中的枢轴、碰撞对齐、受击闪白和实战可读性检查，因此不标记为 `gameplay-approved` 或 `final`。
