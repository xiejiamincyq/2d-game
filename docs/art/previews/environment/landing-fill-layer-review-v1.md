# S2-A：落点填充不再覆盖角色身体

2026-10-03，`5分钟超载`，本地开发、不发布。按用户最新指令由Codex独立判断，不再使用网页监督。本片沿用已批准的2D风格，只修复绘制层级，不增加或替换美术素材。

## 根因与修复

原先落点填充节点为相对 `z=-2`，但所属投射物容器为 `z=22`，实际得到 `z=20`，仍高于身体的 `z=0`。单层淡粉填充叠加后明显染色角色；“低于外轮廓21”并不等于“低于身体”。

填充改为绝对 `z=-1`，层级关系固定为：地板-100 < 落点填充-1 < 身体/障碍0 < 战斗特效20 < 玩家轮廓21 < 飞行弹丸及危险边线22。Godot的相对Z会累加父层，绝对Z停止继承，见[官方CanvasItem文档](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-property-z-as-relative)。

不改填充透明度、颜色、72px半径、弹丸/边线、伤害、轨迹或飞行时间。组件默认14伤害/0.85秒，以及Enemy实际覆盖的16伤害/0.9秒，均保持原值。旧四向截图脚本的`landing-before`特例显式恢复相对Z，以保留其历史高层填充的演示语义；未覆盖旧截图。

## 红绿与真实渲染

先扩展`ProjectileLandingVisualTest.gd`，在生产修复前实际失败：`LandingFill effective z=20 must lie strictly between floor -100 and actor body 0 (parent=22 ancestor=0 relative=true)`，退出1。修复后33断言通过：包含祖先相对/绝对Z与非零弹丸本地Z、目标锚定、飞行时序、半径内外伤害及填充清理。

新增137行`VerifyLandingFillLayers.gd`用实际Player与LobbedProjectile，在1280×720、1:1固定视角展示0/1/8个填充。人物入口结束，物理与动画冻结，弹丸固定在半程；不创建Main、不打开存档、不模拟伤害。两次实际渲染均为Godot 4.7 / Vulkan Forward+ / RTX 5060 Laptop GPU，退出0、无错误或泄漏日志。

- [修前原图](landing-fill-before-v1.png) / [修前原始JSON](landing-fill-before-v1.json)：实际填充层20。
- [修后原图](landing-fill-after-v1.png) / [修后原始JSON](landing-fill-after-v1.json)：实际填充层-1，角色未被大片粉色覆盖，边线与弹丸保留。

JSON记录脚本SHA、素材路径、层级和像素。看图确认后的5个身体内部采样点，在1层和8层条件下，修后RGB均与无填充对照相同；修前8层RGB绝对差总和为0.25490—0.56078。身体右侧50px地面点仍有染色（1层0.05882、8层0.36471），80px圈外点保持0，说明不是删除或隐去整个预警。采样只代表这些位置，不宣称所有纹理边缘或动态画面逐像素一致。

复现命令（真实渲染，不加`--headless`）：

```powershell
godot_console --path . --audio-driver Dummy --resolution 1280x720 --script res://scripts/art/VerifyLandingFillLayers.gd -- --run=after
godot_console --headless --audio-driver Dummy --path . --script res://scripts/tests/ProjectileLandingVisualTest.gd
```

输出`build/diagnostics/landing-fill/after.png/json`；已有证据时拒绝覆盖。`before`标签是此次生产修复前采集，不会在当前修复后的代码上自动回滚重建旧行为，应结合原始JSON源码SHA识别版本。Dummy不提供听觉验收。

## 验收边界与下一片

静态组件层级修复已由本地真实看图与针对性测试确认；完整预推送和独立审查结果另记下方。本片不代表自然刷怪、动态拥挤、整体视觉、平衡、实际声音、性能或人工试玩通过。地面填充被不透明障碍遮住符合既有层级；透视淡化障碍时透出地面是既有策略。危险边线仍优先显示。

后续保留自然WaveDirector，使用隔离存档与真实输入，观测正常波次的存活怪物峰值、种类与预警重叠；不把60AI压力夹具（含8个OVERSEER）当正常关卡。S2—S5仍未整体验收。

完整预推送实际通过：53个Godot套件、165819断言；26个Python套件、133测试。独立只读审查亲自查看两张PNG并核对代码/JSON，无阻断项，确认“不再覆盖角色不透明主体”，不扩大为全部朝向、抗锯齿边缘、障碍遮挡、运动或整局验收。新诊断脚本不创建Main/存档管理器，项目无autoload存档入口。

自然首波为32 scrapper、7 dasher、2 spitter，投掷怪从第三波才出现。首波观测可以检查拥挤和真实导演；预期LandingFill数量为0，不能单凭首波完成投掷预警的动态验收。
