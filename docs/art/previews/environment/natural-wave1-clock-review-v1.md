# S2-B：自然刷怪的单一时钟与数量守恒

2026-10-04，`5分钟超载`。用户取消网页端使用，后续由Codex依据本地证据判断；不发送网页、不等待网页审批。沿用已批准2D风格，不发布。

## 实际缺陷与最小修复

自然第一波计划41只，但修前传送门关闭时会丢掉未发出的队列。严格观测在第98步仍为存活21＋待生成20＋击杀0＝41；第99步变成21＋14＋0＝35，采样立即标记无效，不能把少刷怪的旧结果当成自然战斗验收。

根因是`WaveDirector`入树前调用`portal.set_process(false)`，随后Godot因`SpawnPortal`覆盖`_process`而在ready前自动启用它；导演也手动推进同一个portal。双时钟把预警和寿命推进了两次，关闭时删除尚未清空的队列。Godot的自动启用与ready信号顺序见[官方Node文档](https://docs.godotengine.org/en/stable/classes/class_node.html)。

修复仅在普通/增援、Boss入口两处改为一次性ready连接，在portal ready之后关闭自动process，保留导演唯一计时。没有调整波次数量、生成间隔、0.7秒普通预警、伤害、速度或美术。

## 红绿验证

新增`PortalRuntimeClockTest.gd`等待真正入树后运行自动导演，不手动调用advance或_process。冻结敌人而非导演/portal，以发出数＋待生成数逐帧核对41；同时检查普通、增援及Boss入口的时钟归属与清理。增援/Boss只是入口归属检查，不冒充完整Boss战。

- 修前实际退出1：三个入口均有第二时钟；第一波发出23、待生成0，未发满41。
- 修后直接测试发出41、待生成0；当前按runner参数复跑434断言，退出0。实时时钟帧数随调度波动，不要求固定断言数量。
- 第一轮完整预推送失败：runner默认120帧在测试完成前截断，未出现pass标记。仅此测试帧上限改600，内部五秒生命周期看门狗保留，不降低断言、不跳过套件。
- 第二轮完整预推送退出0：54 Godot套件166264断言，26 Python套件153测试，资源导入、空白、暂停归属、秘密扫描通过。没有完成修复后额外的独立最终审查；根因诊断曾交叉复核，最终改动由工作区自审与上述运行验证支持。

## 真实输入短观测

复用S1-B入口，新增`natural_wave1`，通过Enter开始，等待原样入口/横幅/释放输入保护，再从未刷出任何敌人的初态观察。不是注入60敌人的压力夹具，也不跳过自然预警、改血量或重置敌人。

固定初始化种子20260908，实际生产地图种子426363786；每75步换方形移动方向并射击，冲刺组每180步请求一次。两个运行均1200步、约20秒；这是机器人短观测，不是整波通关、平衡或人类手感验收。

| 修后观测 | 活怪峰值 | 末态活怪 / 击杀 / 待生成 | 末态血量 | 终点 |
| --- | ---: | --- | ---: | --- |
| 普通移动，实际Vulkan渲染 | 36 | 27 / 14 / 0 | 49 | 预算结束，仍PLAYING |
| 冲刺，headless | 32 | 11 / 30 / 0 | 68 | 预算结束，仍PLAYING |

所有采样步均满足存活＋待生成＋击杀＝41，首批生成恢复到第42步/约0.7模拟秒。离线检查器对两份记录均返回valid与budget_exhausted，没有wave_clear。各运行8份源码前后SHA相同、6个真实存档路径前后状态一致，拥有的树/音频引用释放、孤儿节点不增加；退出日志已检查无错误/泄漏，但日志不包含在本证据包内。时钟声明仍为unverified，不把接近1的墙钟比例升级为自动实时时钟证明。

真实截图显示密集怪群仍聚成一团，黑底HUD与薄荷Q版场景不统一；玩家粗轮廓在本帧可辨认，不等于所有拥挤/运动情境通过。截图是在post_draw采集，可能包含最新物理步之后的idle回调，因此HUD与采样数不能当成逐像素同步证明。第一波没有LOBber，落点填充为0不能验收该危险预警。

- [当前真实画面](natural-wave1-runtime-v1.png)
- [原始红绿JSON、前后8份源码与4张运行截图](natural-wave1-evidence-v1.zip)，2722098字节，SHA-256 `41428cb83eadf4a1542da073cebf28f640ae480c9bebf2aa61016c455c48b7c9`。包内顶层`natural-wave1-v1-evidence/`。旧无效/少刷怪观测保留，不覆盖。

复现（每次更换run，已有证据拒绝覆盖；真实渲染不加headless）：

```powershell
godot_console --path . --audio-driver Dummy --max-fps 60 --resolution 1280x720 --script res://scripts/art/VerifyMovementRepeatability.gd -- --scenario=natural_wave1 --seed=20260908 --track=R --mode=walk --steps=1200 --clock=realtime --run=natural-new-walk-01
godot_console --headless --audio-driver Dummy --path . --script res://scripts/tests/PortalRuntimeClockTest.gd --quit-after 600
python -B scripts/art/check_movement_repeatability_report.py build/diagnostics/movement-repeatability/natural-new-walk-01.json
```

## 下一步与边界

S2整体不勾选。后续仍需3种子×3重复×普通/冲刺的自然对照、第三波LOBber动态预警与拥挤可读性，以及完整整局流程。不能用这两份20秒结果代替18次矩阵。S3角色/Boss/HUD统一、S4胜败/商店/存档和地图安全、S5来源与本地交接也未完成；人工试玩、最低硬件与未知素材许可继续待验。
