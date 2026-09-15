# 投掷落点填充分层修复

日期：2026-09-15。保持已批准 C 加粗轮廓与 B 美术方向，不新增风格，不发布。

## 根因与变更

LobbedProjectile 原来在同一 CanvasItem 中绘制弹体、0.08 alpha 范围填充和边界，随 Projectiles 容器一起位于 z=22，覆盖 z=21 的玩家轮廓。多个范围填充叠加后显著降低轮廓对比度。

每个投掷弹新增一个随父节点清理的 LandingFill 绘制节点，相对 z=-2（当前世界有效 z=20）。填充保持原色、透明度和 splash_radius；中心每物理帧更新为固定落点。弹体及边界仍在 z=22。未改伤害、飞行时间、实际范围、攻击预警颜色或边界宽度。

## 证据与验证

- 新增 ProjectileLandingVisualTest，先在旧版因缺少独立填充层而失败，修复后 8 条断言通过：层级、初始落点、移动后落点、飞行中不伤害、落地伤害、半径内外边界、随父节点销毁。
- 全量 Godot 资源导入及 38 套件通过，当前输出 98,371 条断言；Python 74 项通过。
- `player-outline-landing-before-v1.png` / `player-outline-landing-v1.png`：相同角色、敌群、12 个重合落点、固定飞行进度的四向原尺寸对照。before 通过把填充层调回 z=22 重现旧层级，不是另一个完整旧版本运行。实际查看确认轮廓恢复浅色对比度，边界及空中弹体保留。
- `mint-farm-stress-landing-v1.png` 和 `mint-farm-benchmark-landing-v1.json`：真实 AI 压力场景中，玩家轮廓可见且组件已触发。P95 帧间隔 8.853ms，最大 12.43ms；仅单机约 5.71 秒短测，不据此宣称长期性能或整体视觉验收通过。

仍需后续检查：血条拥挤、多个危险边界重合，以及完整局移动。真实弹体/危险边界仍可能短暂遮住部分轮廓，这是保留危险信息优先级，不是整体可读性问题已清零。

## 复现

```powershell
godot --audio-driver Dummy --path . --script res://scripts/art/RenderPlayerOutlineRuntime.gd --quit-after 180 -- landing-before
godot --audio-driver Dummy --path . --script res://scripts/art/RenderPlayerOutlineRuntime.gd --quit-after 180 -- landing
godot --audio-driver Dummy --path . --script res://scripts/art/BenchmarkMintFarm.gd --quit-after 2400 -- landing outline
```

用本机 Godot 4.7 路径代替 `godot`；同时检查无脚本、着色器和资源错误。
