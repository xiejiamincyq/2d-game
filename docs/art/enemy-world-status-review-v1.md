# H1：敌方世界状态层审查

2026-10-11，`5分钟超载`，长期goal active。H1及S3工程/视觉门通过，最终全量v2终态退出0：210 Godot套件210898断言、36 Python套件272测试。未提交/推送、未覆盖旧EXE/存档；第三关Boss/入口仍未完成。阶段邮件见H1任务记录。

## 决策

EnemyWorldStatus是Actor直属Node2D，血条绝对Z23、感叹号子层Z24，保持原世界挂点；身体、原生Skin、实体和Y排序不变。敌条统一既有CORAL，Bruiser保留满血隐藏/受伤显示。八个区域绘制入口不再重复画状态。两真实章节Boss使用同组件及原WARNING谓词/-126挂点，不重复固定HUD血条；旧波次Boss不增加新提示机制。

组件只读、状态变化才重画；PROCESS_MODE_ALWAYS仅观察暂停时控制器取消，不推进战斗、动画、伤害或物理。普通敌人保持暂停冻结，炉心取消后撤掉头标。Actor退出释放状态，尸体不接管血条。没有新贴图、字体、网络或第三方依赖，均为项目原创绘制。

依据[CanvasItem的Z/Y排序规则](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)及[暂停模式](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html)：抬高整个身体破坏遮挡；单一状态层又会被邻居血条盖住，故分条/警告两个小层。不改为屏幕贴图。

## RED及错误记录

- GPU v1退出1：真实蟹0.18s预警，两个朝向被真实统御者身体覆盖，只剩70/96头标像素；盐针珊瑚条0。最小层分离后通过。补血条跨头标位置，v2再次退出1，只剩57/96；分Z24后全部96/96。
- 生命周期初稿错误假设Elite/Cutter有Move、等待process_frame又早于节点处理，脚本中断/漏释放；不当通过。修正夹具真实consider/完整帧后，RED v2精确复现炉心暂停取消但提示缓存残留。只读刷新模式修复后281通过。
- S3 GPU v7固定88px顶栏采样误拒已经可见的针怪提示；退出1保留。v8采用实际合法可见范围，并另断言与真实标题矩形不相交；没有改生产镜头/怪量/预警/身体。
- 全量v1失败：PerformanceTest写死旧helper；Dasher/Chibi测试误把最后一个child当碰撞形状。更新为当前状态失效helper（仍要求原两次body/ground重画）和按类型寻找唯一CircleShape，未删原半径/压力约束；30/15/51专项通过。
- 独立包轮廓测试FileAccess原.gd存在性误判编译重映射；改ResourceLoader.exists后真正加载与21行为检查通过。复制夹具v2相对路径错误导致文件不存在，失败日志保留；v3改绝对路径且复制失败即停。

## 当前证据

- [受控GPU报告](previews/campaign/enemy-status-layer-v1/report.json)：66检查/15图/15当前源SHA；三组真实重叠96/96头标、92珊瑚蟹条，身体遮挡3721/3690/2856像素仍存在；针条80，炉心警告18/暂停取消0。这是冻结模拟时钟的绘制夹具，不是自然战斗或FPS证明。
- EnemyWorldStatusTest281：七基础Kind/十二工厂Role/旧Boss/两真实章节Boss，真实伤害与治疗、隐身、取消、暂停、挂点/身体transform/Z/半径/Skin、尸体及所有者释放。致死伤害仅检查生命周期，不是自然胜利。
- [真实S3 GPU v8](previews/campaign/salt-encounter-flow-v2/report.json)：534检查/七图/601相邻位移（428走至潮道）/100自有玩家弹丸/5盐针；23独立针弹与20589潮带像素，蟹头18/条69、针头18/条80，标题不相交；42当前源SHA。无出生后位移/速度/健康写入，保守导航拒绝0，未删断言。两组22PNG+两份原始JSON逐SHA交付相等，报告build路径不改写。实际重叠/提示/Boss暂停及七张S3图已查看，角色不透明、玩家遮挡轮廓仍正常。
- 独立`enemy-status-pack-v1/game.pck`：6,131,384字节，SHA256 `2fc7ce3b9ddae5f6d67371d3c563c748d941a067ecc61c3c3aba516907037150`。无源码--path，281/84/568/18/646/26/111/1092/21专项及Main120无错误/泄漏；Runtime346位移5盐针、潮带物理81位移。标准release同大小包/Main120通过。修正仅包外测试，PCK未变，没有重复导出成功包或覆盖旧EXE。
- 资产台账通过。冻结审查SHA仍`033c72a1af216517ae2b5243cf204fd8cba4aee22496480188234f521cf58010`，冻结资源报告仍`9e0fe8d5d59b69d860b164f96749fcee9095ae5e614c9e2b8924081cfda85675`。旧Actor源SHA因合法修改现在只是历史快照，不改写冻结证明；当前源/包验证在本页。

## 审查与完成边界

Gmail阶段邮件已成功发送，唯一ID `1a127d13352acbc7`。不再重发S3通知。

实际RED、像素差分、全部Actor状态/生命周期覆盖功能；组件不到60行，统一十三入口，Main/Player/物理/伤害未改。没有新依赖、凭据或资产授权晋级。每Actor两个小CanvasItem及一次状态比较有成本，仅变化才重画；30项压力和释放检查不是FPS签署，密集GPU/多分辨率/OS输入/真人仍归M6。作者自审不冒充独立模型或人类审批。

最终全量v2已通过，H1/S3工程视觉门签署；下一S4潮壳独立攻击。Main仍[1,2]；第三关Boss/入口/解锁4、后三关、全新弹丸/死亡/最终许可均未完成，整体goal不能complete。
