# 最终Boss：修复预警时钟并接入既有Q版监工

2026-10-04，`5分钟超载`，本地开发、不发布；网页端已停用。本片使用已经存在的B清爽玩具图，不生成/修改位图，不提升来源或许可状态。

## 先确认实际攻击时序

真实生产顺序是Boss.setup先创建组件，随后Boss入树。`BossAttackDirector.configure`中的`pattern.set_process(false)`发生在入树前，Godot ready自动启用覆盖的_process；Boss物理导演又手动advance同一pattern。

新增`BossRuntimeClockTest`按该生产顺序构造，在真实引擎回调中等待自然入口、第一阶段远距扇形预警及首弹，不手动推进。实际[红测日志](boss-clock-red-v1.log)：声明0.45秒，但0.216761秒发弹，退出1；同时检查到pattern第二自动时钟。

修复仅增加一次性ready连接，在pattern ready后关闭自动process，保留现有直接关闭以覆盖已ready父节点。独立pattern默认自动处理不改；攻击数量、计划、0.45预警、冷却、碰撞、伤害均不改。[绿测日志](boss-clock-green-v1.log)：0.450007秒首弹，9断言、退出0；BossDirector38、BossPattern244通过。该真实墙钟测试与下述固定帧录像分开，不用录像加速结果证明时钟。

## 视觉接入

最终Boss原先加载`enemy_overseer.png`旧霓虹机械图；现在加载已登记的`enemy_overseer_chibi_b_v1.png`。维持128×128纹理、1.25基础缩放（160px外框）、BODY_RADIUS56、生命10800、移动63.8、AI/攻击合同。母图左右翻转朝玩家，不引入转台或多向生成。

新轻量行走只改变Sprite局部位置/旋转/缩放：最大上抬2px、摆角0.02弧度、压缩2%；静止时复位，不写CharacterBody位置或碰撞。自然入口仍保留1.4秒揭幕渐显，结束alpha=1；入口圆环只改为既定青绿/珊瑚色。受击白闪保留。

ChibiRuntimeArtTest先对实际旧Boss纹理失败，再验证新纹理、局部运动、身体变换/56半径/生命不变、左右朝向及静止复位，50断言通过。BossTest更新为明确Q版路径，不再把旧路径断言误叫“批准美术”。

## 原样组件渲染与运动证据

`VerifyBossArt.gd`不用Main、不创建存档：上方为显式推进入口后的冻结左右姿势，下方为实际Boss物理回调、脚本定位的普通Node2D目标，在第180帧把目标移到另一侧。这是组件视觉夹具，不是自然输入、完整Boss战或人工试玩。

- [修前图](boss-chibi-before-v1.png) / [修前JSON](boss-chibi-before-v1.json) / [修前录像](boss-chibi-before-v1.mp4)
- [修后图](boss-chibi-after-v1.png) / [修后JSON](boss-chibi-after-v1.json) / [修后录像](boss-chibi-after-v1.mp4)

两次真实Vulkan Forward+ / RTX5060 Laptop GPU渲染均退出0、拥有节点释放、孤儿节点0、无错误或泄漏。每份JSON保存360姿态；前后所有身体位置、速度、alpha、入口结束标记逐帧一致（差异0），只有Sprite表现变化。左右翻转分别true/false，生命10800、半径56保持。MP4实际1280×720、60fps、363帧、6.05秒；原AVI保留在忽略的build诊断目录，未删。

录像采用[Godot Movie Maker固定步长](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html)，不是实机帧时/性能或自然预警时长证明。原图和录像已本地检查：新Boss的温室罐、奶油胸板与青绿轮廓和地面同风格；旧图的深黑机械形体不再运行。弹幕仍有旧霓虹配色，HUD仍未统一，不能称六景视觉验收通过。

纹理Alpha只读分析：128×128，非零8965像素，其中7308完全不透明，中心(64,64) alpha255，非零边界(11,8)-(116,120)。边缘有抗锯齿/半Alpha，中心样本不证明每个身体像素完全不透明；没有篡改Alpha或来源图。

```powershell
godot_console --headless --audio-driver Dummy --path . --script res://scripts/tests/BossRuntimeClockTest.gd --quit-after 600
godot_console --path . --audio-driver Dummy --resolution 1280x720 --write-movie build/diagnostics/boss-art/after.avi --fixed-fps 60 --script res://scripts/art/VerifyBossArt.gd -- --run=after
```

已有PNG/JSON会拒绝覆盖；before/after只是采集标签，不在当前生产代码自动回滚重建旧图。before渲染已带本片弹幕时钟修复，视觉仍旧；通过JSON源码SHA识别版本。

## 集成与边界

完整预推送55 Godot套件166264断言、26 Python套件158测试通过，资源导入、暂停所有权、秘密扫描及空白检查通过。没有完成额外独立最终审查；工作区自审与红绿、原样渲染支持本片推进，不冒称全项目验收。

对应素材manifest仍style-approved且license pending；旧来源审计的“最终Boss仍用旧图”是历史快照，当前引用已改变，权利缺口没有因此消失。S3仍待HUD、弹幕/触手配色、六景连续证据；S2后期自然战斗、S4整局/地图与S5本地交接继续未完成。
