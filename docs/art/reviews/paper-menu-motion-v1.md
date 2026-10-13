# 原生开始页轻动效：限定签收

自主美术审批仅针对这次原创装饰，不代替整项目完成或真人手感。完整审计发现旧背景实际上是静态，故补齐原规格的菜单动效，而不是删掉验收要求。

保持墨线纸偶背景、所有按钮和左侧读字区固定。6条低透明雾带在1280设计坐标中最多横移9px、纵移1.2px，按窗口比例缩放；门灯每6秒小幅暖光呼吸。无新图片、外部素材、声音或依赖；纯项目原创几何和时序。未触碰角色、地图、战斗、存档或输入逻辑。

## 实际证据

- 先RED：新增行为不存在时实际引擎退出1。GREEN增强版303项、原菜单187项、菜单集成14项、正式入口62项分别实际退出0，唯一正PASS，无错误/泄漏标记。
- GPU增强版136项实际退出0；960×540、1280×720、1920×1080各0/3/9秒封面及3个子页，加实际调度60帧，共19张。每张完整alpha字节均255；左侧像素和控件矩形不变。
- 对比保留的原静态源码SHA `e6727ffef4e848e2a4f4c77159cafab0d63463cb6b6b80c26bdb972003307251`，三尺寸静态基线像素完全一致；不是把新实现与自身比较。
- 主代理实际审阅v2的19张；v3重新校验后18张SHA与已审图完全相同，唯一不同的自动调度帧另行实际打开审阅，无文字遮挡、裁切或变形。19张图及6份来源哈希均核对实际文件。
- 隐藏父菜单停止调度、再显示恢复；暂停树时UI照常运动；无效delta不推进；长帧最多推进0.1秒；120秒周期接缝实测；开始按钮立即发出原事件。
- 独立只读代码审查Critical0/Required0；两项可选建议（周期接缝断言、锁定原静态SHA）已落实并实跑。Godot正常import退出0，UID由引擎生成，不手写。

[原始证据](paper-menu-motion-evidence-v1/report.json)、[实际退出](paper-menu-motion-evidence-v1/actual-exit.json)、[风格记录](../style-manifests/paper_menu_motion_v1.json)。原始日志/基线源码一并保留；复制不改报告内容。

## 技术边界

`visibility_changed`包含祖先可见性变化；`set_process`只切换该装饰的_process，不控制战斗物理。见[CanvasItem官方说明](https://docs.godotengine.org/en/4.7/classes/class_canvasitem.html)、[Node官方说明](https://docs.godotengine.org/en/4.7/classes/class_node.html)。生产代码不读取GPU图片、不打开测试存档、不加输入等待；完整背景在菜单可见时重绘，未做未经测量的优化。

隔离组件的设置页初值不证明真实Main音量值，SubViewport分辨率不证明Windows DPI，GPU图不证明OS鼠标或帧性能。F8整体验证仍是旧静态菜单源码历史快照；本次修改后当前全量/候选/正常链必须重新同源验证，资源未改的角色证据只在对应资源SHA一致范围内继续有效。电脑锁屏导致OS输入尚未验证，未尝试解锁或认证。

复跑GPU作者工具时，若忽略的build基线不存在，先将本目录`paper-menu-motion-evidence-v1/StaticBackdrop.gd`原字节复制到`build/diagnostics/campaign-goal/f9-menu-motion-static-original-v1/StaticBackdrop.gd`，核对上述固定SHA；不要覆盖现有不同基线。运行`RenderCampaignMenuMotion.gd`时传一个新的输出ID，原工具拒绝旧输出目录。正式游戏和完整状态测试不依赖该作者基线。
