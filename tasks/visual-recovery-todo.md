# 技术与视觉恢复清单

详细根因见 `docs/audits/2026-08-09-technical-visual-audit.md`，实施边界见 `tasks/visual-recovery-plan.md`。

> 状态说明（2026-08-30）：本清单保留恢复过程；生产验收以 `docs/art/reviews/five-minute-overdrive-art-audit-2026-08-18.md` 为准。玩家最终采用新 M2 真实偏航 120 向图集，不是本清单否决的旧屏幕平面旋转图集。未拆分视觉控制器仍是架构债，但不否定已通过的当前玩法美术。

## Phase 0：止损

- [x] V0.1 降级错误审批状态并校正缺失资产
- [x] V0.2 清理 source/runtime/archive 边界与工作区噪声
  - [x] 明确 source、runtime、preview、review 与临时目录职责
  - [x] 忽略 `.import`、`__pycache__` 和 `tmp/` 本地生成物
  - [x] 跟踪 18 个应提交的 Godot `.uid`；保留用户已有的 `.superpowers/sdd` 与 `CLAUDE.md` 不动
  - [x] 新玩家方案接入后移除旧 72/120 帧运行时加载
- [x] Checkpoint A：用户确认状态和目录合同

## Phase 1：视觉合同与预览

- [x] V1.1 建立唯一 45°正交相机和 pivot 合同
- [x] V1.2 提供 16 向、24 向、实时 2.5D 三套技术预览
- [x] V1.3 建立 Alpha、socket、层级和画布验证器
- [x] Checkpoint B：用户选择 M2 真实偏航烘焙方案

## Phase 2：玩家

- [ ] V2.1 从 `Player.gd` 拆出视觉控制器
- [ ] V2.2 完成一个方向的 idle/run/fire/dash/hit 垂直切片
- [ ] V2.3 扩展到选定方向数和全部 socket/层级元数据
- [ ] Checkpoint C：用户批准实际战斗中的玩家表现

## Phase 3：敌人

- [ ] V3.1 建立共享敌人视觉状态机和 profile
- [x] V3.2 为 Dasher A/B 提供移动节奏预览并完成动画
- [x] V3.3 为六类非 Dasher 敌人接入当前批准的单帧母版和水平翻转
- [x] Checkpoint D：Dasher 动作与非 Dasher 当前单帧范围通过

## Phase 4：战场、VFX、HUD

- [x] V4.1 完成一块战斗样板地块
- [x] V4.2 完成首批核心战斗 VFX
- [x] V4.3 重排并压缩战斗 HUD
- [x] Checkpoint E：完整战斗样板通过运行时验收

## Phase 5：质量门

- [x] V5.1 建立运行时视觉回归
- [x] V5.2 建立真实帧时间与资源性能门
- [x] V5.3 恢复严格审批与分批生产流程
- [x] Checkpoint F：批量美术生产完成当前范围

## 全局完成条件

- [x] 玩家始终为严格 45°俯视，不再出现屏幕平面“水平旋转”错觉
- [x] 身体与枪械在源模型中分层，并以共享相机、rig 和遮挡关系烘焙
- [x] 玩家主体内部不透明，方向切换无 Alpha 闪烁
- [x] 玩家当前范围具备 READY、MOVE、FIRE 动作和独立冲刺/受击反馈
- [x] Dasher A/B 具备运动与攻击动作，其他敌人满足当前批准的单帧范围
- [x] 生产角色均使用正式贴图，不再使用程序化矩形占位
- [x] HUD、战场、VFX 和角色形成清晰视觉层级
- [x] 自动测试、运行时截图、性能记录和当前美术审批同时通过
