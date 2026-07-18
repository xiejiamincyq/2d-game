# 规格：暂停商店闭环

## 目标

让玩家在手动暂停时消费本局金币购买升级。商店每个波次提供三项稳定报价，暂停/恢复不能刷新；购买立即生效但不关闭暂停界面。

## 系统合同

`UpgradeSystem` 是报价与购买的单一事实源：

```gdscript
signal shop_changed(state: Dictionary)
func prepare_shop_for_wave(wave: int) -> bool
func get_shop_state() -> Dictionary
func purchase_shop_offer(request: Dictionary) -> bool
```

公开状态结构：

```gdscript
{
    "wave": 2,
    "coins": 54,
    "offers": [{
        "id": "damage",
        "label": "超频弹芯",
        "description": "主武器伤害 +25%",
        "family": "projectile",
        "kind": "support",
        "cost": 33,
        "sold": false,
        "capped": false,
        "affordable": true,
        "_shop_transaction": 2,
    }],
}
```

购买请求只使用 `id` 与 `_shop_transaction` 定位内部报价。调用者传回的 `cost`、`sold`、`affordable` 等字段不参与结算。

## 报价规则

- 每个有效波次首次准备时，从未封顶升级中抽取三项。
- 同一波重复准备返回 `false`，报价顺序、费用与事务号保持不变。
- 新波次费用为 `round(base_cost * (1 + 0.18 * (wave - 1)))`，最低为 1。
- 已购买报价标记售罄；余额不足、伪造事务、重复购买或临时封顶均返回 `false`，不改变金币与属性。
- 商店购买复用升级效果与封顶规则，增加 `upgrade_counts`，但不增加代表免费波次升级次数的 `level`。

## UI 合同

- 暂停页显示当前波次、金币、三项报价和继续按钮。
- 报价展示名称、家族、说明、费用与售罄/封顶/余额不足状态。
- 可购买项可用鼠标、数字键 `1–3`、键盘和手柄焦点操作。
- 购买成功后仍处于 `PAUSED`；按钮立即变为“已购买”，余额同步更新。
- 960×540、1280×720、1920×1080、2560×1080 下内容不超出视口且中文可读。

## 状态机边界

- `Main` 只在 `RunState.PAUSED` 接受商店购买请求。
- 暂停/恢复仍由现有 `pause_requested` 与 `_transition_to` 单一管理。
- 第一波开始时准备报价；波次升级完成并显式推进下一波后准备新报价。
- 商店购买不触发免费升级队列，不改变波次推进门。

## 测试

- `UpgradeTest`：报价稳定、费用缩放、伪造/重复/余额不足、购买效果与等级隔离。
- `UITest`：文本、禁用态、焦点、数字键入口与四种分辨率。
- `SmokeTest`：暂停购买后保持暂停、恢复正常、同波再次暂停报价不变。
- 完整测试：`powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1`。
