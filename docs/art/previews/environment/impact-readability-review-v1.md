# 命中特效叠画修复 v1

日期：2026-09-13。范围：已批准 B 风格内的可读性修复，不生成或改写美术源图，不改战斗规则，不发布。

## 原因与修复

原先所有 spark 都绘制完整命中贴图，包括每次爆炸产生的 8 条射线。全局 96 条记录上限无法限制同一位置的亮块叠加。

- 普通命中发射时，检查距离 48 像素以内的现存贴图火花；已有 3 张时，新火花只画短线，不再画完整贴图。
- 爆炸的 8 条射线全部画短线；保留原有环、速度、寿命、记录数和全局容量。
- 不改变单次孤立命中、伤害、碰撞、AI、血条、危险弹体和攻击预警。

预算发生在发射时，不是逐像素遮挡保证；运动中的贴图仍可能汇聚。只扫描有界的最多 96 条记录，不引入节点或依赖。

## 验证与证据

新增测试先在旧逻辑下失败。第一版直接丢弃超额火花，导致 StateTest 与 PerformanceTest 的反馈数量约定失败；已修正为保留短线记录，原有两项测试不做放宽。

最终验证：Godot 资源导入通过；36 个测试套件、98,347 条断言通过；Python 74 项通过。覆盖局部贴图预算、远处独立命中、寿命释放、爆炸 8 条射线与范围环保留，以及爆炸不消耗普通命中贴图预算。

`RenderImpactReadability.gd` 使用实际 Player、FloorGrid、CombatVfx，固定 0.03 秒效果年龄，三列分别为单次命中、命中加爆炸、20 次同点命中加爆炸。禁用自动处理，避免首帧耗时污染；首次未固定年龄的截图作废，已由正确采集覆盖。

- `impact-readability-before-v1.png`：对同一批记录强制恢复旧的“每条火花都画完整贴图”规则，属于旧绘制规则的重现，不是旧版完整游戏截图。
- `impact-readability-after-v1.png`：当前正式绘制规则。孤立命中外观不变，爆炸和密集命中的亮块覆盖明显减小。
- `mint-farm-stress-readability-v1.png` 与配套 `mint-farm-benchmark-readability-v1.json`：真实 AI 压力场景，旧基线未覆盖。

压力采样：RTX 5060 Laptop GPU，1280×720，240 帧预热、1200 帧采样，平均帧间隔 4.763 ms，P95 8.542 ms，最大 12.441 ms；62–80 个敌人，弹体峰值 149。只是一台机器约 5.72 秒的短测，不是持续帧率承诺。相较旧报告不能据此宣称性能提升；帧驱动刺激与实际时间不同，敌群位置也不是严格逐帧对应。

## 复现

在此工作树使用 Godot 4.7（将 `godot` 替换为本机程序路径）：

```powershell
godot --audio-driver Dummy --path . --script res://scripts/art/RenderImpactReadability.gd --quit-after 120 -- before
godot --audio-driver Dummy --path . --script res://scripts/art/RenderImpactReadability.gd --quit-after 120 -- after
godot --audio-driver Dummy --path . --script res://scripts/art/BenchmarkMintFarm.gd --quit-after 2400 -- readability
```

## 验收边界与下一步

本轮命中特效局部问题修复通过；整体玩家可读性仍未通过。真实密集场景中，大体型敌人和信息标记仍遮挡玩家，单次命中也会短暂覆盖局部身体。

下一步检查角色间局部遮挡与玩家定位提示，并整理血条/状态标记层级；保留障碍物前后关系，不能把整个玩家粗暴全局置顶，也不能隐藏真实危险来制造“清爽”假象。最终仍需真实移动与持续战斗验收。
