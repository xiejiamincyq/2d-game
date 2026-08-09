# 角色与战斗美术恢复状态（2026-08-10）

依据 `docs/audits/2026-08-09-technical-visual-audit.md`，本次只纠正事实和审批状态，不生成或替换正式角色资源。

## 状态变更

| Asset | 原状态 | 新状态 | 原因 |
|---|---|---|---|
| `player_base` | style-approved | draft | 相机与新 rig 合同尚未验证 |
| `player_directional_atlas` | style-approved | draft | 屏幕平面旋转方案已否决 |
| `player_turnaround` | gameplay-approved | draft | 25.6°俯角、错误 Alpha、武器分层失败 |
| `player_weapon` | style-approved | draft | 侧视贴图不符合 45°投影和 socket 合同 |
| `enemy_dasher_a` | gameplay-approved | draft | 保留设计身份，但缺少运动/攻击动画和运行时证据 |
| `enemy_dasher_b` | gameplay-approved | draft | 保留设计身份，但缺少运动/攻击动画和运行时证据 |
| `enemy_scrapper` | style-approved | planned | 登记路径不存在 |
| `enemy_bruiser` | style-approved | planned | 登记路径不存在 |
| `hit_spark_basic` | style-approved | planned | 登记路径不存在 |

## 不变项

- 用户已批准的 A 战术图形插画作为项目总体设计方向继续保留。
- 用户明确选择保留的 Dasher A/B 身份继续保留，不等于当前静态运行时资源获得批准。
- 当前运行时代码暂不切换或删除资源，避免新方案选定前出现断图；旧方案只承担临时兼容。

## 下一审批门

先提交严格 45°相机下的三套玩家技术预览：16 向预渲染、24 向预渲染、实时 2.5D。用户选择前不批量生产动作帧。
