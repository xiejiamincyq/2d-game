# 开局 HUD 波次初始化修复

2026-10-07，仅修开局显示，不改变六普通波/Boss、入场动画、生成时刻、敌人数、存档或战斗规则。

实际旧EXE点击开始后，玩家入场期间显示`1/8`，之后导演准备第一波才改成`1/6`。根因是HUD默认文本写死旧总数，Main的fresh分支在导演`setup(..., false, ...)`后隐藏标题，却未先同步HUD。改为组件初始`波次 -- / --`，fresh分支隐藏标题前调用既有`ui.set_wave(1, wave_director.waves.size(), 0)`。总数来自真实导演，不新写死6；0表示入场期间尚未准备波次，随既有wave_changed信号更新。继续分支沿用原restore_stable_boundary发出的状态，不额外覆盖。

按测试驱动技能先补两个状态断言：UITest拒绝无数据时虚构总波数，StateTest检验玩家入场的第一可见HUD即反映导演总数。两个测试修前均真实退出1，修后分别89/43断言、退出0；StateTest红测退出时另有4例ObjectDB泄漏，原日志保留，不计为绿色退出。最终完整回归真实进程退出0：69 Godot套件170082断言、31 Python套件235测试，未跳过套件。

## 当前实际 EXE

新隔离副本1207文件116272372字节；190按原preset筛选的生产路径/hash，较v4只有Main和HUD两项变化；原用户脏资源仍包含在副本，不是clean HEAD构建。fresh import/export退出0，没有脚本/引擎错误/泄漏标记；不是完整导入缓存语义证明。保留新目录、不覆盖旧包，见[交接v5](local-playtest-handoff-v5.md)。

新保留EXE PID9340通过普通窗口开始按钮进入入场，实际有界原JPEG显示`波次 1 / 6 剩余0`、HP100、00:00；不是编辑器或外部脚本。EXE未变，PCK3002888字节、SHA256 `68b5d60e61c022aa7573d1f0420b6f357e332f9435419b780de3c6a815dcdeb8`。仅子进程APPDATA隔离，附加verbose/Dummy/1280×720/日志；Alt+F4后直接读取保留Process对象，真实退出0。引擎、stdout、stderr三路均保存，stderr再次出现2个ObjectDB泄漏，干净退出门失败；另有Vulkan层registry提示及RGB8转RGBA8硬件warning，均保留。不能因HUD修复/全套绿色而称泄漏已修。

本机旧包追加PID24604（继续第一波后退出）和33392（自然死亡/R回标题后退出）两次verbose诊断，退出0且其保存stdout/stderr未出现ObjectDB警告；它们没复现原2例，不反证原失败。新包首入场退出再次复现，根因仍待定位，不猜定为R或音频。

六个真实存档路径核验后均absent，20原脏文件逐hash不变。测试写自己的headless测试路径，native写隔离profile；未并行运行这些存档写入者。

## 可核查附件与未验范围

[证据包](hud-initial-wave-evidence-v1.zip)：23成员（22数据+索引）、283394字节，SHA256 `5fee9f058a0a1a8975f04905757aed591bd459edb5c8c2e97e87f815f98e812a`。包含红绿/全门原日志、4当前代码、fresh导出manifest/日志、旧开局原JPEG、新标题与开局原JPEG/时间和窗口身份、三路native日志、现场Process结果的衍生交接记录、一次性封包/导出辅助源。CRC/索引hash/原日志与代码等源到包字节一致已核对；派生handoff-v5.json使用LF，本地交接JSON被Windows写为CRLF，JSON语义一致而非字节相同。没有存档、GPU缓存或其他窗口。

旧新开局图片地图和时刻不同，仅对照HUD文本，不宣称固定seed像素差分或连续首帧录像。不是EXE全六波、商店、Boss、胜利、移动/射击/冲刺、声音或性能验收。S2—S5整体保持未通过；下一片优先ObjectDB退出泄漏定位，再补整局与连续视觉缺项，不增加新玩法。
