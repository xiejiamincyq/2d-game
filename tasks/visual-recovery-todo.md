# 技术与视觉恢复清单

详细根因见 `docs/audits/2026-08-09-technical-visual-audit.md`，实施边界见 `tasks/visual-recovery-plan.md`。

## Phase 0：止损

- [x] V0.1 降级错误审批状态并校正缺失资产
- [ ] V0.2 清理 source/runtime/archive 边界与工作区噪声
  - [x] 明确 source、runtime、preview、review 与临时目录职责
  - [x] 忽略 `.import`、`__pycache__` 和 `tmp/` 本地生成物
  - [ ] 跟踪应提交的 Godot `.uid`，清点剩余本地证据文件
  - [ ] 新玩家方案接入后移除旧 72/120 帧运行时加载
- [ ] Checkpoint A：用户确认状态和目录合同

## Phase 1：视觉合同与预览

- [ ] V1.1 建立唯一 45°正交相机和 pivot 合同
- [ ] V1.2 提供 16 向、24 向、实时 2.5D 三套技术预览
- [ ] V1.3 建立 Alpha、socket、层级和画布验证器
- [ ] Checkpoint B：用户选择技术方案

## Phase 2：玩家

- [ ] V2.1 从 `Player.gd` 拆出视觉控制器
- [ ] V2.2 完成一个方向的 idle/run/fire/dash/hit 垂直切片
- [ ] V2.3 扩展到选定方向数和全部 socket/层级元数据
- [ ] Checkpoint C：用户批准实际战斗中的玩家表现

## Phase 3：敌人

- [ ] V3.1 建立共享敌人视觉状态机和 profile
- [ ] V3.2 为 Dasher A/B 提供移动节奏预览并完成动画
- [ ] V3.3 分别预览并完成 Scrapper、Spitter、Bruiser
- [ ] Checkpoint D：四类敌人运动和攻击反馈通过

## Phase 4：战场、VFX、HUD

- [ ] V4.1 完成一块战斗样板地块
- [ ] V4.2 完成首批核心战斗 VFX
- [ ] V4.3 重排并压缩战斗 HUD
- [ ] Checkpoint E：用户批准完整战斗样板

## Phase 5：质量门

- [ ] V5.1 建立运行时视觉回归
- [ ] V5.2 建立真实帧时间与资源性能门
- [ ] V5.3 恢复严格审批与分批生产流程
- [ ] Checkpoint F：恢复批量美术生产

## 全局完成条件

- [ ] 玩家始终为严格 45°俯视，不再出现屏幕平面“水平旋转”错觉
- [ ] 身体与枪械分层，但共享相机、rig、socket 和遮挡关系
- [ ] 玩家主体内部不透明，方向切换无 Alpha 闪烁
- [ ] 玩家至少具备 idle、run、fire、dash、hit 动画
- [ ] Dasher A/B 及其他三类敌人均具备运动和攻击反馈
- [ ] 生产场景不再混用角色贴图与程序化矩形占位
- [ ] HUD、战场、VFX 和角色形成清晰视觉层级
- [ ] 自动测试、运行时截图/视频、性能记录和用户确认同时通过
