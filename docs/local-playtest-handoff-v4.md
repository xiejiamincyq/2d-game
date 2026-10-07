# 本机试玩交接 v4：远程危险视觉版

保留敌弹碰撞初始化修复，加入普通敌弹的圆形深青轮廓、珊瑚/酸绿分色，以及不染玩家中心的投弹蓄力提示。旧radius-v1/lob-v1目录均保留历史用途，不覆盖旧包。

## 双击启动

打开`build/playtest/5分钟超载-ranged-v1/`，双击`five-minute-overdrive.exe`，PCK必须同目录。无需Godot编辑器；本机目录不随Git克隆下载，没有上传/公开发布。

完整路径：`C:\Users\21604\Documents\2D game\.worktrees\5分钟超载\build\playtest\5分钟超载-ranged-v1\five-minute-overdrive.exe`。系统拦截时保留提示，不关闭安全保护。WASD移动、鼠标瞄准、左键射击、右键冲刺、Space暂停、商店1—6、开始C继续、胜败R重开；每局随机障碍。人工正常运行使用正式存档，新游戏/胜败/重开可能清理已有进度，不是只读诊断。

## 核验与限制

导出输入HEAD`3b7cf19d6752c5ae3b03dcd7a2afc79cadaa4151`，复制包含本轮生产修改及用户原有未提交资源：1207文件116271984字节，不是clean HEAD构建。190个按原preset过滤的生产输入路径/hash与前置manifest完全一致，包含新Palette与UID；这不是全部importer/cache语义证明。隔离副本import/export实际退出0，无日志错误。

| 文件 | 字节 | SHA256 |
| --- | ---: | --- |
| five-minute-overdrive.exe | 109019648 | b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0 |
| five-minute-overdrive.pck | 3002856 | 16fec82c223d4f7725b150e7448ede3bda082836a8c78e621bc6c5d43d051f8e |

实际从新保留目录启动EXE：headless/Dummy/120标题迭代PID11616，原生Vulkan/Dummy/固定movie三帧标题PID25520，均实际退出0、无错误/泄漏，六真实存档前后不变；实际看过1280×720标题原PNG。没有外部脚本或源码回退。标题检查不是独立EXE整局、实时性能或实际声音验收。

[机器记录](local-playtest-handoff-v4.json)保留命令/PID、190输入hash、二进制身份与存档检查。[视觉片记录](ranged-warning-visual-review-v1.md)另列代码回归、固定渲染、编辑器引擎自然输入流程，不混作EXE整局证据。

S2—S5整体、全部密集视觉、实际听感、素材作品派生链/许可证、最低硬件和人工手感仍未签收；保持不发布。
