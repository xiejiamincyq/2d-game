# 本机试玩交接 v5：开局波次显示修复

打开`build/playtest/5分钟超载-hud-initial-v1/`，双击`five-minute-overdrive.exe`，同目录PCK保留；不需要Godot编辑器。这是本机目录，不随Git克隆下载，不是公开发布。旧ranged/radius/lob包保留。

完整路径：`C:\Users\21604\Documents\2D game\.worktrees\5分钟超载\build\playtest\5分钟超载-hud-initial-v1\five-minute-overdrive.exe`。系统拦截时不关闭安全保护。WASD移动、鼠标瞄准、左键射击、右键冲刺、Space暂停、商店1—6、开始C继续、胜败R重开。每局随机障碍；正常人工运行使用正式存档，开始新局/胜败/重开可能清理已有进度，不是只读诊断。

保留前轮敌弹圈/轮廓/投弹视觉修复；本轮仅去掉开局瞬间假`1/8`，从实际导演同步`1/6`。

| 文件 | 字节 | SHA256 |
| --- | ---: | --- |
| five-minute-overdrive.exe | 109019648 | b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0 |
| five-minute-overdrive.pck | 3002888 | 68b5d60e61c022aa7573d1f0420b6f357e332f9435419b780de3c6a815dcdeb8 |

导出输入HEAD046f3bb、加本轮未提交的Main/HUD两项生产变化与原用户脏资源；190过滤输入与前置manifest核对，副本fresh import/export退出0，不是clean HEAD或完整importer证明。[机器记录](local-playtest-handoff-v5.json)保留复制/源码/二进制hash与现场native事实，[修复记录](hud-initial-wave-review-v1.md)区分红绿/全门和真正EXE画面。

全门69 Godot170082断言+31 Python235测试通过；实际EXE点击开始确实显示1/6，退出0。但本次stderr有2个ObjectDB实例泄漏，干净退出门未通过；未把功能显示修复当泄漏修复。仅本机开场窗口验证，没有替用户验收整局、听感、最低硬件或手感。实际试玩与后续诊断可以继续，S2—S5整体及素材权利仍未签收；不发布。
