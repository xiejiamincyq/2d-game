# ADR-006：章节流程共用，区域策略与内容就绪独立

状态：Accepted；2026-10-11。只解决实际第一、第二关，不宣称六关完成。

## 背景与决定

第二个可玩章节出现后，首关协调器中的地图、导演、热区绑定、文案、通关编号和重玩场景不能继续硬编码为苗圃。先以原首关45检查和新增结构测试提取 `ChapterRun`、`ChapterRunUI`，再添加第二消费者；不复制两份完整流程，不让铸坊继承苗圃的区域机制。

- `ChapterRunDefinitions` 是封闭的实际实现策略表：地图、导演、场景和本区说明。`ChapterCatalog` 仍是六关目录；目录存在不等于可玩。
- `NurseryChapter` 保留旧场景/脚本身份；`FoundryChapter` 仅提供编号2和实际热区绑定。共享协调器负责玩家、碰撞层、镜头、轮廓、战斗反馈、局内奖励、暂停、死亡、保存和退出。
- `ChapterSceneRegistry` 单独列实际就绪关卡，惰性加载场景以避免“场景→协调器→注册表→场景”的预载环。Main只检查就绪、永久解锁和存档状态，再按编号路由。
- 永久清关必须匹配当前章节、导演CLEARED状态与已接受的真实Boss实例；复制进度模型、核验顺序，再由原Store事务写入。保存失败不暴露假解锁，显示重试；重玩已通关区域不跳关。
- 重玩沿用同一区域、音量和存档路径，但保证新种子不同于上一局。返回加载实际Main，不把旧波次局内快照当作章节进度。

## 引擎内输入验证

本环境的Window鼠标轮询出现数亿像素的异常值。真实战斗/保存仍可能由无人机完成，不能只凭通关就签署瞄准通过。保留该证据，使用真实GPU SubViewport的标准输入管线进行可重复的工程验证；每次鼠标注入核对视口实际坐标，不直接改玩家瞄准/血量/伤害/位置。

章节切换保留原场景父节点；直接Window运行仍设置SceneTree.current_scene。嵌入视口时保留外层root场景，避免Godot禁止将非root子节点设为current_scene。此改动限于新章节入口/重玩/返回，不声称旧试玩所有嵌入导航也已扩展。

依据：[Godot Viewport输入接口](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-push-input)、[SceneTree源码](https://github.com/godotengine/godot/blob/4.7-stable/scene/main/scene_tree.cpp)。本地4.7试验确认root约束；首次夹具错误设置嵌套current_scene被拒绝，不通过修改引擎绕开。

## 验证与边界

首关旧行为回归、铸坊两条真实路线/热区/构筑/保存失败/重玩/返回、默认和嵌入视口输入空间均有独立检查。原生GPU正常引擎输入、跨进程恢复、独立PCK和全量结果另列在阶段审查，不用本ADR代替通过证据。

不增加第三方运行库/MCP或网络依赖，不动用户真实存档、旧EXE、冻结骨骼齐备证明。资源与真人手感、桌面鼠标、密集性能和完整六关链仍是不同完成门。
