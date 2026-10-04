# 战斗状态布局修复（2026-10-04）

当前分支 `5分钟超载`，生产基线 `a865f64983875f397c73befca2b869d05681e529`。用户已取消网页端；本片由工作区证据判断，不发布。范围仅为现有 Boss 血条、连杀/超载卡片与模块提示的屏幕布局；不改战斗、存档、角色、碰撞或已批准的 2D 薄荷奶油风格。

## 根因与修复

旧 GameHUD 的连杀卡片固定在 y130、模块提示固定在 y82，BossHealthBar 独立固定在 y126。各自调整坐标不能建立可靠布局关系：血条覆盖连杀，模块提示覆盖主 HUD，也可与血条和连杀互挡。

GameUI 现在用现有 HBox/VBox 容器组合原控件，不创建第二份消息状态。血条与连杀/完整超载消息共用一行；模块提示位于下方。顶边取实际 HUD grid 下边缘，四列/两列转换无需硬编码 HUD 高度。保持 14px 横边距；同一行间隔8px、模块提示间隔6px。显示控件不截获鼠标，菜单/标题绘制仍在其上方。

BossHealthBar 新增纯查询 `get_preferred_width(viewport_size: Vector2) -> float`，返回原72%—90%响应宽度，不改变位置/尺寸。独立血条的 `apply_viewport_size` 旧合同不变；组合布局只设置最小宽度，由容器管理位置/尺寸。实际 resize 更新70%/35%阈值线。连杀变长时减小血条宽度，保留完整消息和血量/阶段文字，不再增加额外连杀行挤占战斗带。

HUD 仍负责文本、计时和淡出。重新挂接的状态层同步跟随 HUD 可见性，几何重排采用合并后的 deferred 更新；没有逐帧轮询，也没有更改原相机断言。实现参照 [Godot BoxContainer](https://docs.godotengine.org/en/stable/classes/class_boxcontainer.html) 的最小尺寸重排合同。

## 真实失败与回归

1. 新 `CombatStatusLayoutTest` 在旧实际 GameUI 上首先测量可见外框：1280×720 Boss `(179.2,126,921.6,34)`，连杀 `(560,130,160,47)` 相交，退出1。不是缺少新API、解析错误或冻结角色的自然战斗结论。
2. 第一个布局候选仍调用血条的旧定位函数，后续刷新把容器局部y覆盖为126，实际血条落到y252。旧相机测试真实失败；新增共同行高/实际HUD下边缘断言也先失败。改为纯宽度查询并移除组合路径的旧定位调用后通过。`status-after-v1` 保留为失败候选，不作合格结果。
3. 第一完整回归抓到标题→战斗同步可见性回归：原记录器测试在立即捕获时丢失重新挂接的可见面板，退出1。生产层同步可见性修复后，原测试21断言不改即通过；没有延迟夹具或降低六面板断言。
4. 初次截图工具存在局部变量类型推断解析错误，已修正为显式 String。该错误日志保留，但不算生产红测或生成图片。

最终完整门：`build/diagnostics/combat-status/full-gate-status-v2.log`，**62 Godot套件168507断言、28 Python套件178测试，退出0**。新布局测试666断言，覆盖四原生目标尺寸及额外800×600两列HUD、九种状态、完整超载/模块文本、实际字体最小尺寸、所有可见面板两两不相交/不出屏、共同行高、标记比例、纯查询无副作用、稳定布局和标题立即隐藏/恢复。Runner给予600帧预算，不以截断测试伪造通过。原BossHealthBar47、UITest88、BossCameraFraming1133均通过。

## 原生组件证据

修前 `status-before-v2`：四尺寸各四状态，共16原始PNG；采集器、测试、实际可见 UI/地板依赖共12项源码和资源在采集前复制冻结，并绑定SHA。修后最终 `status-after-v3`：同四状态四尺寸，状态切换后的首个 `frame_post_draw` 和四帧稳定后各一图，共32PNG，同样绑定当时12项完整选定来源；不是用后来源码回填旧哈希。

四状态是 Boss+连杀、Boss+完整超载、Boss+连杀+模块提示、普通模块提示。外部只读 Python 重新计算每张实际可见面板两两面积、viewport包含、Boss紧凑共享行、标签字体最小尺寸，并核对冻结源码、当前修后源码、PNG尺寸/非单色/SHA。修前16图存在28对面板相交；修后32图0对相交、0文本空间不足、0出屏或共同行偏移。`valid=true` 对修前只表示证据完整，不表示旧布局通过。

800×600只有 headless 真实控制树验证，不冒称第五种原生截图。首绘制组件图是四个明确固定状态的第一绘制，不代表任意输入时刻均无暂态。原生组件采集无Main、真实存档、自然输入或性能结论。底图随机纹理没有像素配对，不宣称整幅图片零差异。旧 `status-after-v2` 在测试追加后成为历史快照，最终只引用v3精确来源。

实际已看过960×540修前全部提示重叠图、修后完整连杀+模块/完整超载图；血条、消息和HUD分开，原字体/颜色保留。其余图由几何/字体检查补充，不代签人工视认或手感。

## 自然整局和未完成项

最终当前源码 `combat-status-natural-09-v1` 原生窗口/Vulkan Forward+、60FPS上限、输入驱动且保留生产hit-stop，初始RNG种子20260909。9267有效战斗步自然胜利，585击杀，最低HP57.76224、结果HP77.76224，首结算C恢复和R重开清档/标题通过；六个真实存档路径哈希不变，orphan1→0，原日志无错误/泄漏，进程退出0。final.state=START是结果后R重开的标题。`--require-six`核验180原PNG、六景配额及当前44来源通过；44项来源另在运行前复制冻结，事后逐字节哈希核对。

完整Boss战1583个post_draw样本，首末墙钟26.367127秒。另一个只读检查重新计算**UI对UI**两两面积：1583样本中面板相互遮挡0；相机检查单独计算角色/UI：Player冲突0，Boss/UI相交96、部分出屏4、完全出屏0，1454样本双方可用带内，129样本显示cue，全部实际冲突都有cue，zoom0.8003498—1.00。因此不能把“血条和消息不互挡”写成“Boss任何时刻全身无遮挡”。与旧整局的AI轨迹、伤害或时长没有条件化配对，不能宣称此次更少步数就是性能/平衡改善。

实际看过Boss000/015/029原图，玩家/血条读得清，旧青色圆与粉色友方技能仍在，下一片处理其语义。只看三张选段，不冒称逐像素看过全战1583帧。原始180自然图、48组件图、历史失败候选全部留在本地；没有永久删除。

本片不勾选 S3 或全项目。底部收集卡片与超载条并存时、旧友方霓虹与敌方危险色语义、四向/完整连续视觉、S2后期三种子重复矩阵、S4实际20地图、S5资源来源/本地包/性能及人工手感仍需要各自验证。不把原先自然相机证据冒称为本片最新源码。

## 封存和复核

[证据包](combat-status-layout-evidence-v1.zip)：161项、43,516,192字节，SHA256 `dac5e213f76909c9b20037b46df660d805ac1e66afc5d3dd7b705222d1198ee0`。生成后CRC、唯一项及每项与实际来源的完整字节对应验证通过；不覆盖旧包、不删历史。

包括全部48组件PNG及前/后各12项选定来源快照、自然44项来源快照、完整自然/捕获JSON、真实失败和最终完整门日志、三个外部checker及打包脚本、3张自然Boss原图。其余177自然原图、失败候选图片在本地保留。单项666的 `layout-final-v1.log` 在封存后另行生成，仅本地；包内已包含最终完整门，不冒称包含该单项原日志。选定来源快照不是整个项目；自然JSON图片路径仍为当时项目路径，只有3张自然图入包，**ZIP不是可直接运行游戏或直接对全部180图复验的发行包**。

本地复核入口：

```powershell
python -B -X utf8 build/diagnostics/combat-status/check_status_evidence.py build/diagnostics/combat-status/status-after-v3 after
python -B -X utf8 scripts/art/check_natural_render.py build/diagnostics/natural-run/captures-combat-status-natural-09-v1.json --report build/diagnostics/natural-run/combat-status-natural-09-v1.json --log build/diagnostics/combat-status/natural-status-09-v1.log --require-six
python -B -X utf8 build/diagnostics/boss-framing/check_framing_evidence.py build/diagnostics/natural-run/captures-combat-status-natural-09-v1.json
python -B -X utf8 build/diagnostics/combat-status/check_natural_status_evidence.py build/diagnostics/natural-run/captures-combat-status-natural-09-v1.json build/diagnostics/combat-status/natural-source-v1
```

外部检查脚本作为证据快照随ZIP保存，不是新增生产依赖。当前完整回归与自然整局的退出0由执行方实际观察；独立审查采用只读差异、日志、图及哈希复算，不代签另一台机器Godot复跑、最低硬件或人工操作。

独立封闭包复核另行确认161项均对应本地原字节、CRC/SHA一致、48组件捕获和3张所选自然图来源一致；直接从包内JSON复算Boss/UI/Player/cue及自然结果得到相同数字，无剩余Required。两份组件来源快照各包含一张地板资源PNG，因此包中组件前缀下实际有50个PNG文件，其中只有48个是捕获图。

60FPS上限来自执行方实际调用参数，并非JSON自行证明帧率。下面是当时的真实自然采集命令；重放须改用全新`--run`避免覆盖原证据，不能把上限当作性能保证：

```powershell
godot_console --path . --audio-driver Dummy --max-fps 60 --script scripts/art/VerifyNaturalRunRendered.gd -- --run=combat-status-natural-09-v1 --seed=20260909 --steps=18000 --clock=realtime --mode=flow
```

工程记录：v3组件采集返回执行session后，完整headless门启动时两者曾短暂同时运行，随后实际观察两者分别退出0并完成来源/图核验；后续正式自然整局单独运行。组件帧不能作为无并发背景的性能证据，本片不作任何性能改善结论。
