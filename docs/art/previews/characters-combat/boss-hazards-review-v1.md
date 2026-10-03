# Boss 危险提示、地面层与短时触手扫动

日期2026-10-04，分支 `5分钟超载`，本片基线 `6bd978c`。继续用户已选B清爽玩具/B薄荷农场/C清楚描边；工作区自行判断，未使用网页监督。程序化效果修订，不生成或修改角色位图，不提升素材许可状态。

## 实施与自审

- Boss扇形弹幕与砸地散弹统一珊瑚色实体菱形、深青3px描边、奶油中心，去除粉紫光晕；玩家方形子弹不改。砸地只换用同一`Projectile`子类的绘制，继承原碰撞、伤害与清理。
- 1秒扫击/1.1秒砸地预警保持原尺寸与锁定位置，边界用深青外线/珊瑚内线。大面积填充移至每Boss一个`GroundFill`，绝对z=-1，位于地板-100上、角色0下；不随Boss父层抬高，不再直接染色角色内层。
- 扫击的0.22秒激活期增加25点橡胶管表现，固定13/8px双色线和小端头，在原扇形内扫动。**仍是原先全扇形、每次攻击只命中一次的判定**，不是按可见管子逐像素判定，也不是增加攻击。
- `BossProjectilePattern`仅改子弹色和瞄准扇预警绘制；RNG、生成计划、空档、速率与数量上限不改。触手时间/半径/伤害/实体碰撞、隐身取消与所有权清理保持。
- 自审：仅描画、地面画布和重绘调度改动，无新依赖/外部输入/凭证；每Boss只多一个画布节点，线段数组固定25点，无每帧新增节点。没有额外独立最终审查，不冒称独立验收或性能改善。

## 红绿与失败记录

`BossPatternTest`先真实退出1：旧弹幕tint不是珊瑚。`BossTentacleTest`先真实退出1：旧预警不是珊瑚；换色后第二次红测确认缺少绝对地面层。修后分别265/79断言通过，新增检查碰撞半径5、弹幕伤害9、地面层与拥有者释放。

新增碰撞检查最初遇到测试在`SceneTree._initialize`里造弹过早、`_ready`未建shape的问题，初次“pattern-green.log”包含错误，运行已中断，不是绿测。改为先等待树就绪、检查shape存在，最终`pattern-green-ready.log`才是有效通过；未删除原失败日志或削弱断言。

采集工具初版也无效：Movie Maker启动时输出目录尚未创建；普通Node2D模拟Boss没有world_bounds，砸地弹中断留下9孤儿节点。改为有明确Rect2字段的视觉拥有者、提前创建录像目录、主动取消后释放。初版 `build/diagnostics/boss-hazards/` 不纳入验收；有效最终成对采集在 `boss-hazards-v3`，实际角色尺寸、画面边界和同步预警已修正。v2是中间夹具检查，不冒充最终对照。

## 原样证据

- [修前提示图](boss-hazards-before-v1.png) / [修后提示图](boss-hazards-after-v1.png)
- [修后连续录像](boss-hazards-after-v1.mp4)
- [成对PNG/JSON/录像、红绿与完整回归日志](boss-hazards-evidence-v1.zip)

证据包5603142字节，SHA256 `791ca0057a96946018ec06edbed4134911308ad6ee0eab97550265dab2b46845`。

同一采集脚本SHA、同一随机种子/输入：每份360个组件帧，攻击阶段/elapsed、三轮命中、每弹世界位置/速度/半径/伤害、弹数全部前后一致，差异0。每三轮扫击18伤害、砸地20伤害不变。两次Vulkan Forward+ / RTX5060 Laptop GPU渲染均退出0，无错误/泄漏，拥有节点释放，孤儿0→0。两份MP4为1280×720、60fps、367帧、6.116667秒；多出的7帧是初始化、循环清理/退出，不是360个采样中的额外攻击步。

已本地看原图、砸地散弹图与录像抽帧：轮廓比旧细霓虹线清晰，短管只在激活期间出现并扫动/消失，主体未换色或变透明。录像和组件都采用显式固定步长、普通视觉拥有者和模拟受击目标，**没有Main、自然玩家输入、完整Boss战、帧时或平衡验收**。Movie Maker耗时不能当实机性能。

`check_boss_hazard_preview.py`只读校验输出valid=true，绑定PNG/JSON与最终源SHA。警告第30帧对比无填充第85帧的相同静止玩家：3×3源Alpha全255的794个内层样本，修前794个被染色，修后0个变化。初始单像素Alpha筛选955点中修后仍有31边缘混合点；最终明确排除抗锯齿边缘及邻域，不声称身体每像素都全不透明。

```powershell
godot_console --path . --audio-driver Dummy --resolution 1280x720 --write-movie build/diagnostics/boss-hazards-v3/after.avi --fixed-fps 60 --script res://scripts/art/VerifyBossHazards.gd -- --run=after
C:\ProgramData\miniconda3\python.exe scripts/art/check_boss_hazard_preview.py build/diagnostics/boss-hazards-v3
powershell -ExecutionPolicy Bypass -File scripts/tests/prepush.ps1
```

先创建录像目录；已有before/after文件会拒绝覆盖，标签不是自动回滚生产代码的开关。需要重采时先指定新输出目录。

## 导入隔离修复与完整回归

首轮完整预推送在资源导入阶段失败，并非所有套件通过：诊断矩阵CSV被Godot按翻译表导入，`errors`列产生无效语言警告，PowerShell将stderr作为错误中止。依据实际csv_translation导入记录与[Godot目录隔离规则](https://docs.godotengine.org/en/latest/tutorials/best_practices/project_organization.html#ignoring-specific-folders)，添加版本化的`build/.gdignore`，阻止构建/诊断数据被当运行资源导入；FileAccess诊断输出不变。原CSV/translation/AVI未主动删除，未屏蔽stderr。

单列聚焦提交 `e215bdffde635615fc4bf1eb8c52a7195a697b4c` 与新策略红绿测试。最终完整预推送55 Godot套件166301断言、26 Python套件159测试通过；导入、暂停所有权、秘密与空白检查通过。总断言是该次实时套件结果，不保证每次相同。

本片只完成Boss瞄准扇弹、扫击/砸地这一子项；旋转弹/缺口环的预警展示、普通敌人/玩家武器霓虹余留、同条件六景仍未整体验收。S2后期自然窗口、S4整局/结算/继续、S5来源/实机性能/交付继续，人工手感和最低硬件不自动勾选。不发布。
