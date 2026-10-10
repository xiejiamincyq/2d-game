# 巡界员原生玩家实际接入 v1

2026-10-10；`5分钟超载`，M3.1 工程检查点完成。新玩家已实际接入共享 Player / Main 旧波次演示 / NurseryChapter，不再只是资源预览。自主风格状态仍为 **style-approved**，不签 final、真人手感或六关全部完成；大型/Boss 新攻击门仍关闭。

## 已发生的变化

实际 Player 创建 `player_paper_v1.tscn` 四个独立朝向；不再加载/绘制旧身体或武器图集。右手骨下的手枪和 Muzzle 是实际发射挂点，普通弹/榴弹从该世界坐标出发。碰撞半径16.9、角色位移、伤害/射速、普通弹速度大小以及榴弹30%玩家速度继承和原基础速度提升20%的公式未变；实际输入的基础方向改为枪口到准心，修复挂点偏移引入的平行瞄准偏差。

`NativePlayerMotion` 只读 Player 的权威时间与状态。入场、冲刺、短受击、射击、行走/待机有明确优先级；射击把新手/前臂/头后坐叠在当前腿部步态上，移动开火不冻结腿。四向枪只接受局部残余瞄准，身体不做360°屏幕旋转。各向七个动作均来自上一检查点的新原生库，不使用旧图集动画。

死亡信号先启动终止姿态，再传给场景暂停。正常动作随 Player 物理/入场时钟，只有死亡视觉在暂停后继续0.55秒，不能转向、取消、移动、复活或开火。受击只改变RGB，正常身体alpha=1；隐身才有明确0.42视觉alpha，清理修饰器立即恢复。测试还发现进入树前批量构筑会采样未入树骨架，已限制为真正入树后才采样；不改经济测试结果来掩盖引擎错误。

## 新遮挡轮廓

`PlayerOcclusionOutline` 改为128×128透明 SubViewport 中的身体骨骼副本，逐骨复制当前视图姿态，隐藏手枪；内侧纸白/墨线轮廓覆盖前景敌人，不给身体填半透明幽灵。仅出现实际前景敌人视觉重叠时 UPDATE_ONCE，平时关闭更新；生产路径没有 `get_image()` CPU读回。仍禁止穿透前景地形、隐身、入场或死后显示。

UPDATE_ONCE 只更新下一帧的语义依据 [SubViewport 官方文档](https://docs.godotengine.org/en/stable/classes/class_subviewport.html)；ViewportTexture 是实际动态视口纹理，避免逐帧GPU到CPU转换的取舍依据 [ViewportTexture 官方文档](https://docs.godotengine.org/en/stable/classes/class_viewporttexture.html)。轮廓建立在新身体和骨姿态上，不再取旧图集的朝向区域。

## 功能和 GPU 验证

- `PlayerNativeIntegrationTest` **699检查**：实际 Player、四向真实枪口、普通/榴弹原速度、移动后坐、冲刺/受击/入场、隐身恢复、碰撞不变、入树前构筑、暂停死亡及终止保护；另覆盖每5°、20/200/900px距离的216组真实准心射线、手腕±45°约束、三弹同挂点/7.5°散射和实际榴弹继承。直接fixture/事件调用是组件测试，不当作普通输入试玩。
- 轮廓21、ChibiRuntimeArt50、GrenadeVelocity73、Dash215、NurseryChapter43；Damage51、EconomyBuild2913保留原伤害/构筑覆盖。仅把Damage的旧固定32.5px断言改为实际挂点，不降低伤害或速度门禁。
- [当前GPU原始报告](previews/campaign/player-native-runtime-opacity-v2.json)：277检查、4向×7动作×3阶段×正常/受击RGB共168组，主体不透明像素>500，半透明和边缘裁切像素均0。四向实际mask/轮廓非空，轮廓alpha不半透明、偏离mask像素0；SceneTree真正暂停时死亡自动播完且不推进战斗。仅排除父类旧程序化地面绘制，保持 Player 创建/控制的真实body；非连续所有姿态或普通输入验收。[v1报告](previews/campaign/player-native-runtime-opacity-v1.json)保留为修正瞄准前的源码快照。
- 最初轮廓Shader的自定义函数使用TEXTURE导致编译失败，即使退出0也拒收；改为显式mask sampler后严格通过。GPU测试最初错误地拆走已经绑定的蒙皮节点，出现原点裁切，已保留失败记录并改为不拆活体骨架，只排除父绘制。后续独立GPU原始证据通过，不把失败图算成品。

## 实际普通输入与失败记录

四局均从实际 Main 的鼠标菜单进入随机第1关，普通移动/瞄准/发射/冲刺与正常奖励按钮操作；没有改生命/无敌、演员输出/碰撞、Boss10800生命、门户/遭遇时钟、直接伤害或伪造死亡。每局所有已登记生产和验证源码SHA256前后一致，新永久进度使用显式隔离路径，不使用用户永久存档。v1–v3是修正瞄准前的快照，**当前代码对应v4**；不冒称旧报告绑定新源码。

| 运行 | 地图种子 | 实际位移 | 发射 | 结果 |
|---|---:|---:|---:|---|
| [v1](previews/campaign/player-native-chapter-failed-v1.json) | 802621488 | 7510 | 1725 | Boss战死亡，52击杀，未存通关；FAIL保留 |
| [v2](previews/campaign/player-native-chapter-failed-v2.json) | 3287373914 | 6348 | 1475 | Boss战死亡，51击杀，未存通关；FAIL保留 |
| [v3](previews/campaign/player-native-chapter-flow-v1.json) | 933515433 | 10588 | 2389 | 10774检查、18原生帧、62击杀、生命73，真实首领死亡并保存1通关/2解锁 |
| [v4当前](previews/campaign/player-native-chapter-flow-v2.json) | 4048794459 | 9349 | 2121 | 9534检查、18原生帧、59击杀、生命19，真实首领死亡并保存1通关/2解锁 |

只升级了作者侧输入试跑策略：危险预警作避险评分，不当不可穿越的墙使玩家困在场内；区分横扫/砸地，适度绕首领，正常追逐地图上可见金币/心/盾，不直接给予奖励或生命。各局种子不同，早期输入策略也有调整，**不据此推断性能改善、平衡通过率或因果上的生存提升**。没有改生产玩家/BossAI以保证通关。

[当前敌群战斗](previews/campaign/player-native-chapter-enemies-v2.png)、[真实通关](previews/campaign/player-native-chapter-clear-v2.png)已审查；新身体/侧面和手枪在1280×720可辨，但其他族旧素材与新资源混用是未完成迁移。[当前新进程恢复](previews/campaign/player-native-chapter-restore-v2.json)验证实际 Main 读取同一隔离进度，1可重玩、2虽解锁但制作中仍禁入，文件哈希不变。供给路线是完整普通输入证明；风险路线仍只有原独立核心事务测试。旧战斗/通关/恢复图报告保留，不覆盖失败证据。

## 枪口视差回归

提交前实际SubViewport准心测试发现八个45°方向全部偏离：附着手的枪口与身体根不重合，而旧 `_fire` 仍用身体→准心方向平行发射。`player-native-aim-red-v2.log`退出1是正确行为RED，不是解析失败。修正后实际 `_fire` 向 `_spawn_bullet` 提供目标和散射角：先采样当前步态/后坐并调整有约束的手枪残余角，再从真实枪口朝准心发射；同一齐射共用挂点，散射绕该中心线。显式方向调用保留原速度契约，不改变伤害、输出时钟或榴弹参数。

`NativePlayerView.aim_hand_at`是仅视觉的世界目标接口：非有限目标/死亡拒绝，身体朝向不由它改变，三次有界手腕修正，不旋转角色根。每次正式动作采样后重新对准目标。接近枪口的目标仍由弹丸射线精确对准，枪的局部角不能为此突破±45°。测试还暴露225°在角度重建/归一化的浮点差异，四向选择归一化后添加小边界容差，避免开火前后朝向跳变；未用放宽断言掩盖。当前699项绿灯与全量回归同时通过。

## 预算与实际包

[当前渲染预算](previews/campaign/player-native-budget-v2.json)与[负载画面](previews/campaign/player-native-budget-v2.png)：RTX5060 Laptop / Vulkan，128只实际Enemy创建的原生身体、实际四向玩家步态/后坐和连续遮挡轮廓；240帧预热、1200采样，P95 **4.987ms**、最大7.560ms，采样约4.16秒、峰值264绘制调用，通过16.7ms局部视觉预算。采样期没有截图读回/文件写入；关闭AI/物理负载且视觉时钟为合成采样。这是未限帧post-draw墙钟间隔，不是GPU单项时间、显示器呈现FPS、真实完整游戏性能、前后性能提升或六族密集最终预算。旧v1测量保留，不作严格前后对照。

当前全量 `player-integration-full-v4.log` 退出0：**108 Godot套件186053断言、35 Python套件270测试**；没有跳错误/泄漏门。此前v2/v3绿灯快照保留。首次full-v1因生命周期与旧枪口预期失败，已修复再运行，不覆盖前次失败日志。

当前实际PCK **3,468,280字节**，SHA256 `4da392f4ca404267d3d0202d2b9e760da00b5998674d359958438475fad2dca5`；在仅包目录、无`--path`运行外部 `VerifyNativePlayerRuntimePack`，12检查证明真正Main菜单/首关、新Player、自然入场、普通移动/开火、战斗返回，作者/技术脚本排除。严格包日志无错误/泄漏，标准release gate与Main120帧通过。

新本地候选 `build/playtest/v16-native-player-v2/five-minute-overdrive.exe` 已导出，独立EXE实际进程94420启动120帧退出0、日志无错误/泄漏；其PCK与上述诊断包SHA256相同。尝试让release EXE跑外部Probe时没有12项PASS标记，严格判失败，不把退出0算包流程验证；该模板`--help`确实不提供`--script`，与[官方命令行构建类型说明](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)一致。因此12项流程证据只属于完整Godot引擎加载真实PCK；EXE当前只有启动门，未冒称独立EXE完整普通试玩。旧v15、v16-v1均保留，不公开发布。

## 五轴审查与下一步

正确性：信号顺序、死亡终止、暂停清理、入树前初始化与遮挡状态有正反验证；伤害/移动仍由原演员掌管。架构/可读性：新增小型Motion组件，避免继续把动作分支全堆入大型Player；副本只在遮挡时更新，共享静态库，无第二战斗时钟。安全：无下载/凭据/新运行库/MCP安装，资源仍原创，隔离写入和精确证据复制，不包含用户存档/无关改动。性能：有局部实际GPU预算，不用测试数量替代整体性能。

保留的迁移债：旧atlas常量、朝向helper、`_draw_chibi_weapon`/`_load_png_texture`仍供部分历史作者工具/测试引用，但当前Player不加载/调用旧绘制；旧玩家PNG仍可能在PCK中，未虚称包裁剪完成。四向资源仍不属于单视图NativeCatalog schema，实际结构与接入专项独立验证，后续应统一目录/验证契约；不新建假位图production manifest。历史图/素材/工具未删除。

新发现待处理：Boss framing缩放/移镜时可暴露地图边界黑区（当前真实帧可见），最终击杀HUD有一帧滞后；它们不是玩家蒙皮失败，但必须在后续地图/镜头验收修复。纸偶轮廓与小窗口/完整快动手感还需最终艺术打磨，不能把工程通过升级为人类认可。下一步M3.2孢子射手等普通族，随后大型/Boss非攻击骨架；全部角色骨骼齐备前不制作新大型攻击。M3/M4/M5/M6与goal仍未完成。
