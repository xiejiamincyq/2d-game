# 本机试玩交接 v6：音频退出收尾

双击本机 `C:\Users\21604\Documents\2D game\.worktrees\5分钟超载\build\playtest\5分钟超载-audio-exit-v2\five-minute-overdrive.exe`。保留同目录PCK，无需Godot编辑器；旧包保留，不随Git克隆下载，不发布。

操作仍是WASD移动、鼠标瞄准、左键射击、右键冲刺、Space暂停、结算1—6、开始C继续、胜败R重开。地图每局随机。正常人工运行使用正式存档；新局/胜败/重开可能清进度，普通关窗不额外清档。系统拦截时不要关闭保护。

本包保留既有2D美术/敌弹轮廓/HUD显示修复，新增音频真实回收后关窗/重开；收尾上限2秒，超时明确报错退出1。

| 文件 | 字节 | SHA256 |
| --- | ---: | --- |
| five-minute-overdrive.exe | 109019648 | b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0 |
| five-minute-overdrive.pck | 3005464 | 103141f55d694ee0d2e7c719dad9f71bd448a12cb3dc558e3e3f8c776e6b06ac |

最终三路完整门：71 Godot170771断言、33 Python238测试，退出0。五个实际EXE普通关窗/暂停/自然失败/R重开短测均退出0，engine/stdout/stderr无错误或泄漏；六正式存档及20原脏文件不变。输入HEAD e230865加本轮未提交源码/原用户脏资源，fresh副本190生产输入逐hash核对，不是clean HEAD。

证据范围与失败记录见[修复验收](audio-exit-review-v1.md)，机器哈希/五PID原图记录见[交接JSON](local-playtest-handoff-v6.json)。未代签完整EXE胜利、人工手感、声卡听感、最低配置或素材许可证，S2—S5整体仍待验。
