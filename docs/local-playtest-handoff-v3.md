# 本机试玩交接 v3：敌方碰撞修正版

当前版本保留上轮投弹视觉，并修复狙击/旧Overseer物理半径初始化及变换父下喷吐弹出生点。旧lob-v1/c5c5710目录都保留历史用途，不作为当前代码包。

## 双击启动

打开`build/playtest/5分钟超载-radius-v1/`，双击`five-minute-overdrive.exe`，PCK须同目录。无需Godot编辑器；本机目录不随Git克隆下载，没有上传/公开发布。

完整路径：`C:\Users\21604\Documents\2D game\.worktrees\5分钟超载\build\playtest\5分钟超载-radius-v1\five-minute-overdrive.exe`。系统拦截时保留提示，不关闭安全保护。WASD/鼠标瞄准/左键射击/右键冲刺/Space暂停、商店1—6、开始C继续、胜败R重开。每局随机障碍。

人工正常运行使用正式存档，新游戏/胜败/重开可能清理已有进度，不是只读诊断。

## 包与实际启动

导出前HEAD`c0ca2073af14d9032c10524e74234994616e881c`，runtime副本1203文件，包含当前生产修复和原有用户未提交资源，不是clean HEAD包。复制后新测试扩充124→180，测试目录被既有preset排除；188个eligible生产路径与hash仍完整等于前置manifest。import/export分别实际退出0；此有限清单不证明所有importer/cache语义。

| 文件 | 字节 | SHA256 |
| --- | ---: | --- |
| five-minute-overdrive.exe | 109019648 | b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0 |
| five-minute-overdrive.pck | 3001792 | 03eb26b7b8e39f24fe2af5c25f1e2d49c286926c561531bfcd5b4a8bc92a5efe |

新保留目录EXE实际PID16160、headless/Dummy/120标题迭代、退出0；无外部脚本/源码回退，日志无错误/泄漏，六真实存档前后不变。导出原包同身份EXE另做原生Vulkan固定movie三帧标题，PID26140、退出0、1280×720原PNG；实际看过标题原图。这不是独立EXE整局、实时性能、游戏内运动/碰撞或实际听感验收。

[机器记录](local-playtest-handoff-v3.json)保留命令/PID、188输入与二进制hash、存档检查。代码180断言/完整68 Godot+31 Python门禁、编辑器引擎自然11941步胜利/实际弹体形状观察另见[技术修复记录](enemy-projectile-radius-fix-v1.md)，不混作整局EXE证据。

实际声音、素材作品派生链/许可证、最低硬件、完整独立EXE从开始到Boss/胜败/恢复的实际操作与人工手感、S2—S5整体仍未签收。继续完善，不发布。
