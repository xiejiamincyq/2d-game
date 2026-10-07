# 本机试玩候选 v7：同步当前受击颜色修复

双击 `C:\Users\21604\Documents\2D game\.worktrees\5分钟超载\build\playtest\5分钟超载-current-v7\five-minute-overdrive.exe`，保留同目录PCK，无需Godot。旧包未覆盖；此包仅在本机，不随Git下载、不公开发布。

WASD移动、鼠标瞄准、左键持续射击、右键冲刺、Space暂停、结算1—6、开始C继续、胜败R回标题。地图每局随机。普通人工运行使用正式存档，新局/胜败/重开会清进度；普通关窗不额外清档。系统拦截时不要关闭保护。

| 文件 | 字节 | SHA256 |
| --- | ---: | --- |
| five-minute-overdrive.exe | 109019648 | b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0 |
| five-minute-overdrive.pck | 3005464 | 9b9ca7ce30eff456380c26bd43cc83de1654f2a1305e563d8883cf478d8564fe |

基线提交c5987af，fresh副本1222文件，按导出preset过滤的190生产输入前后相等，相对v6只有Enemy.gd改变；EXE引擎模板相同，游戏变更在PCK。构建含原20脏文件中的运行资源，不是干净HEAD。没有新位图、改玩法/碰撞/数值或提高资源审批/许可状态。

import/export实际退出0，各自engine/stdout/stderr无错误或泄漏。本片复用上一片实际完整门73 Godot173366断言、34 Python250测试；代码/测试输入未改，另做本片文档检查与文件hash复核，不称新跑同一完整门或fresh副本已跑全套。

## 普通EXE窗口验证与失败边界

事前计划见[冻结计划](../tasks/local-freeze-v7-plan.md)，机器记录与终态见[交接JSON](local-playtest-handoff-v7.json)。仅普通Main，用子进程APPDATA隔离存档，默认音频驱动；无--script/--path/MovieMaker、伤害注入或修改PCK。

- `exe-c5987af-pause-v1`，PID14120：第一局输入冲刺前已自然失败，第二局实际右键冲刺击杀13，但Space截图已是自然失败，不算暂停。原图05/09及同进程R回标题均保留；第三局正常开始后Space进入战术暂停，41/100生命、00:06时间在两张相隔10.852秒截图保持不变，随后Alt+F4正常关闭。实际退出0、三路无错误/泄漏，无watchdog。不是第一次尝试全部通过，也不是新的OS进程替换失败结果。
- `exe-c5987af-death-v1`，PID18852：正确看到标题/正常开局，随后窗口工具报告已有活动请求；重新绑定截到了另一个赛车界面，再次目标激活仍报告占用。按Computer Use恢复规则停止所有UI输入，不从错配截图决定动作。第二进程的自然死亡/R/普通关窗验证未完成；预设300秒watchdog会清理自己的进程，终态单列，不可当作普通干净退出。
- 三张初始/恢复错配截图只保留在本机原始目录，排除出精选证据及视觉验收。文件名`01-title`、`09-pause`、`04-natural-result-observation`是采集时的预期标签，不证明画面状态：其中01/04错配，09是Result。其余真实游戏画面已逐张观察。

第一进程覆盖所列短路径，但第二进程独立复核未完成，v7仍为候选。已观察到群怪叠挡玩家，危险/友方线穿头枪的既有视觉待办继续；不把受击颜色修复叫全部遮挡修复。当前生产输入另有[自然完整胜利与62张收集窗口](collection-natural-review-v1.md)记录，属于Godot诊断，不是普通独立EXE整局。

六正式存档与20原脏文件保护、二进制前后hash、精选证据索引在JSON中分列。精选ZIP不含EXE/PCK、APPDATA/正式存档内容、无关应用截图或完整工程；保留失败日志，不是可移植项目。

人工手感、声卡听感、最低硬件、精确音效下载链/许可仍待验；[Bone Breaking候选来源](audio/overdrive-bone-breaking-source-v1.md)仍needs_review。S2—S5整体及全项目未通过，不重开网页，不新增发布授权。
