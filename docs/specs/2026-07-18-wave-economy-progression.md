# 规格：波次升级与金币经济

## 目标

删除按击杀经验阈值升级的旧机制。清空每个仍有后续战斗内容的波次后，玩家免费进行一次三选一流派升级；敌人掉落金币，拾取后进入本局余额，后续可在暂停商店消费。

## 技术栈与命令

- 引擎：Godot 4.7，GDScript。
- 完整测试：`powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1`。
- 运行：Godot 4.7 使用 `--path` 指向当前工作树绝对路径。

## 项目结构

- `scripts/systems/UpgradeSystem.gd`：本局金币、免费波次升级与升级事务。
- `scripts/systems/WaveDirector.gd`：波次清空、等待升级与显式推进。
- `scripts/pickups/CoinPickup.gd`：金币吸附和单次拾取。
- `scripts/Main.gd`：系统编排与状态转换。
- `scripts/ui/HUD.gd`、`scripts/ui/GameUI.gd`：金币和流派等级显示。
- `scripts/tests/`：单元、集成、UI、性能与烟雾测试。

## 代码风格

保持现有带类型 GDScript、早返回和信号驱动编排：

```gdscript
func spend_coins(amount: int) -> bool:
    if amount <= 0 or amount > coins:
        return false
    coins -= amount
    progression_changed.emit(coins, level)
    return true
```

## 测试策略

- 小型逻辑测试：金币加减、波次奖励去重、升级事务。
- 集成测试：波次清空暂停、升级完成后推进、击杀到金币拾取。
- UI 测试：中文“金币”和“流派等级”可见，旧经验进度不再出现。
- 回归测试：完整测试脚本禁止脚本错误、泄漏与缺失通过标记。

## 边界

- 始终：先写失败测试；一次击杀/拾取/波次只结算一次；提交前完整测试。
- 本阶段不做：暂停商店购买 UI、最终价格平衡、存档迁移、传送门生成。
- 不允许：保留一条隐藏 XP 升级路径；靠暂停切换刷新报价；恢复运行时掉落节点。

## 成功标准

- 非终局波清空后游戏暂停并显示一次升级选择，选择后下一波才开始。
- 敌人死亡生成金币而不是经验，拾取一次后余额精确增加一次。
- HUD 显示金币与流派等级；仓库运行时代码无 `xp_value`、`ExperienceShard`、`add_experience`。
- 完整测试通过，变更形成聚焦提交并推送。

## 已决策事项

- 终局波直接进入胜利，避免弹出无后续用途的升级。
- 金币价值首阶段沿用旧经验掉落数值及波次缩放，价格在暂停商店阶段基于实测收入校准。
- 第一阶段继续使用 `UpgradeSystem` 作为单一成长状态源；只有职责复杂度实际增长后再评估拆分。
