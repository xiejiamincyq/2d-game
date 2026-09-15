# 敌人头顶标记整理 v1

日期：2026-09-15。范围：已批准 B 风格内的信息减负，保留 C 加粗轮廓，不发布。

## 规则

- Overseer 保留存活期间的常驻真实血条，维持高优先级目标提示。
- Bruiser 仅在存活且受伤时显示真实血条；血条尺寸、颜色和比例计算不变。
- 普通立绘敌人移除不随血量或攻击状态变化的彩色占位条。无立绘时保留原占位标识作为回退。
- 不修改近战蓄力、远程瞄准线、落点范围、Boss 独立血条、伤害、移动或 AI。

## 验证

新增可见性测试先在旧版因缺少规则方法失败，修复后 EnemyStaticArtTest 共 108 条断言通过；覆盖满血、受伤、恢复满血、死亡及立绘装饰条关闭。全量 Godot 38 套件、98,412 条断言通过；Python 74 项通过。

`enemy-markers-before-v1.png` 在修改 Enemy.gd 前采集；`enemy-markers-after-v1.png` 在修改后采集。两者使用同一渲染脚本、七类敌人、满血/半血两行原尺寸对照。脚本的 before 参数仅控制文件名，不能恢复旧版规则。

真实 AI 压力证据：`mint-farm-stress-markers-v1.png` 与 `mint-farm-benchmark-markers-v1.json`，已查看。P95 帧间隔 8.733ms，仅单机短测，不证明持续性能提升，也不代替玩家实际移动试玩。

本次解决重复装饰条和不必要的满血 Bruiser 血条；受伤大怪或多个 Overseer 的血条仍可能重叠，未实现自动避让。后续优先进行真实移动辨识度验证，不继续无限叠加静态截图作为最终验收。

## 复现当前效果

```powershell
godot --audio-driver Dummy --path . --script res://scripts/art/RenderEnemyMarkerReview.gd --quit-after 180 -- after
godot --audio-driver Dummy --path . --script res://scripts/art/BenchmarkMintFarm.gd --quit-after 2400 -- markers outline
```

`godot` 替换为本机 Godot 4.7 程序，检查实际渲染无错误。
