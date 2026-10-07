# 本机试玩交接 v2：投弹视觉版

本轮重新导出当前资源与投弹视觉脚本，旧`5分钟超载-c5c5710`包保留历史用途，不再是当前视觉版本。没有公开发布或上传EXE/PCK。

## 直接启动

打开本分支的`build/playtest/5分钟超载-lob-v1/`，双击`five-minute-overdrive.exe`。PCK必须与EXE保持同目录，不需要Godot编辑器。

本机路径：`C:\Users\21604\Documents\2D game\.worktrees\5分钟超载\build\playtest\5分钟超载-lob-v1\five-minute-overdrive.exe`。此目录不随Git克隆提供；若Windows阻止启动，保留提示，不关闭系统保护。

WASD移动、鼠标瞄准、左键射击、右键冲刺、Space暂停、结算页1—6选卡；开始页有存档时C继续，胜败R重开。每局随机障碍。人工正常启动会使用正式存档，新游戏/胜败/重开可能清理进度；不是只读诊断。

## 包身份与范围

导出前基线HEAD`dc042f8d8daaa47cd6d9e7b6360e749c1413da26`，包含当前未提交投弹组件、新测试及原有用户资源，不是clean HEAD包。1201个runtime目录文件逐字节复制，import/export实际分别退出0；按现行preset过滤后188个输入路径/哈希与工作树匹配。机器记录保留导出前清单hash，不把它当import后缓存闭合证明。

| 文件 | 字节 | SHA256 |
| --- | ---: | --- |
| five-minute-overdrive.exe | 109019648 | b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0 |
| five-minute-overdrive.pck | 3001872 | 1aa2bdb75b5b00000a5ac0308c9be59957093479d70aa50adc93366114dab75b |

新保留目录实际EXE无窗口120标题迭代：PID25288、退出0、日志无错误/泄漏，六真实存档前后不变，无源码回退或外部脚本。独立导出EXE另做原生Vulkan固定movie三帧标题：PID23140、退出0、1280×720原PNG，主执行者实际看过标题原图；不是实时性能、游戏内投弹或完整EXE操作证据。

[机器交接记录](local-playtest-handoff-v2.json)含188输入哈希、命令/PID/二进制及日志hash、存档核验。投弹的四向组件及9922步编辑器引擎自然胜利、74帧实际飞行/落地原图另见[投弹视觉记录](lobber-visual-review-v1.md)，不混作独立EXE整局验收。

实际听感、精确音频作品派生链和所有资源许可证、最低硬件、完整独立EXE从开始到Boss/胜败/恢复的操作与人工手感仍未签收。S2—S5整体保持未完成，不发布。
