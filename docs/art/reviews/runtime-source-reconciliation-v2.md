# S5 现行资源台账与来源复核 v2

基线：分支 `5分钟超载`，HEAD `208c688d2e7708c88dfb2bff9078e31cba3b782f`，本次工作树。状态仍为 `needs_review`；这是工程记录，不是法律意见、许可批准或发布授权。网页监督已由用户取消。

本片仅修改台账/审计说明和回归测试，不修改游戏、图像、manifest 或审批状态。旧报告[2026-10-02来源审计](supervised-runtime-source-audit-2026-10-02.md)保留为当日快照，本报告替代其关于“当前Boss仍用旧图”“M2包内未知”“轮廓脚本导出风险未复现”和台账缺项的现行描述。

## 当前文件证据

[机器快照](runtime-source-snapshot-v2.json)记录12份现行位图 manifest、运行PNG/声明源文件的尺寸与SHA256、生产 `.gd` 中17个不同字面资产路径及引用位置、当前导出配置与保留PCK的SHA256。快照SHA256：`1122926b82b28184911290f0aa0759388804d2f41b59c86e9cebd3eb1523bf22`。

扫描覆盖生产脚本的 `res://assets/` 字面路径，排除 `scripts/art` 和 `scripts/tests`。它不是所有场景、动态加载、插件、引擎字体或完整依赖闭包，也不证明所有预加载资源实际生成。PNG头尺寸、源文件存在和来源字段不能证明生成过程、像素等价或使用权。

| 类别 | 当前文件/来源记录 | 核实范围与保留缺口 |
| --- | --- | --- |
| 玩家身体、枪械（2张） | `Player.gd`：`player_chibi_b_cardinal_atlas_v1.png`、`player_chibi_b_weapon_cardinal_atlas_v1.png`；对应 `player_base`/`player_weapon.production-v2-chibi-b.json` | 实际256×256、2×2格，每格128×128；源记录在 `assets/art/source/chibi_b/`。manifest仍为style-approved/pending。身体84×84、侧向枪72×72/前后58×58是脚本绘制框，不是碰撞箱或源图分辨率。 |
| 七类敌人（7张） | `Enemy.gd`：`enemy_{scrapper,dasher,spitter,bruiser,marksman,lobber,overseer}_chibi_b_v1.png`；对应7份chibi production manifest | 各128×128，单帧加程序化缩放/摆动/翻转和攻击反馈。5类共享记录的 `enemy_lineup_alpha_v1.png`，Scrapper/Bruiser各有源文件。不能计作7次独立生成或手绘逐帧动画。 |
| 最终Boss（复用上述Overseer） | `OverseerBoss.gd:25`与 `_create_boss_visual()` 绑定同一chibi Overseer；`WaveDirector.gd` 创建独立Boss | 旧报告“最终Boss仍使用enemy_overseer.png”已过时；独立Boss并非新增第13张贴图。Boss当前纹理绑定另有 `BossTest.gd` 回归，不替代完整动态视觉验收。 |
| 命中特效（1张） | `CombatVfx.gd:11`：`combat_hit_chibi_b_v1.png`；`combat_hit.production-v1-chibi-b.json` | 实际128×128，源记录 `combat_hit_alpha_v1.png`；style-approved/pending。程序化其他技能不因旧位图计划未完成而被记作缺功能。 |
| 地面、障碍（2张） | `FloorGrid.gd`、`ArenaObstacle.gd`；`mint_farm_floor_b_v1.json`、`mint_farm_props_b_v1.json` | 实际1254×1254、1088×1088。512×512为地面世界重复单元；障碍原图记录2172×724、无缩放重排。两份draft/pending；本片不再证明重排像素等价。 |
| 四个shader | `dasher_hit_flash.gdshader`、`player_occlusion_outline.gdshader`、`prop_alpha.gdshader`、`floor_surface.gdshader` | 快照另记4个生产代码资源，不混作生成位图；本片没有复核完整代码权属。 |
| 外部MP3 | `AudioManager.gd:6`：`overdrive_bone_breaking.mp3` | 快照另记文件hash/引用；作者、原网址、许可文本、获准使用证明仍unknown。“用户提供”不是本片从仓库独立证明的事实。 |

12张位图全部有manifest，新增10行角色/战斗登记与既有2行环境登记一致。状态仍为10项style-approved、2项draft，12项授权pending。全59份manifest依然57pending/2not-applicable/0approved，包含历史预览，不等于59个运行文件；两个not-applicable也是旧声明，不是本片法律判断。

玩家身体 manifest 中 prompt-library 23749 的第三方示例URL仍只登记为layout reference；是否实际作为图像输入、输入权利和适用账户条款的审查结果仍unknown。所有生成来源字段保持原样，不以本片审计补出未知提示词或授权事实。环境 `mint-farm-review-v1.md` 保留生成标识/透明修订记录，但处理授权不等于素材许可批准。程序化音频合成与外部MP3分开；生成代码路径也不能代替权利批准。

## 旧资源与本地包

旧45°/M2与Dasher A/B台账仍保留，标题明确为历史，禁止再把它们当现行制作合同；不删除历史图、工具、源文件或记录。旧planned弹丸/拾取物/无人机位图不代表现行程序化功能缺失。

- `Main.gd:6` 当前从 `scripts/effects/PlayerOcclusionOutline.gd` 加载轮廓组件。实际独立EXE失败及修复见[轮廓导出报告](../../standalone-outline-review-v1.md)，不是未执行的静态风险。
- 三个M2运行图集已精确排除；实际包成员187→181、仅移除对应3个ctex和3个import见[包精简报告](../../m2-package-review-v1.md)。其他旧贴图可能仍在包内，本片不扩大结论或排除范围。
- 本次重新读取保留PCK：3000912字节，SHA256 `7ead85380dde3ea1505d4e8904171eb9747411094731fe7e3bc17d910e116d8c`，与上一片实际包一致。只复核hash，不重新导出/挂载/枚举包。此前构建源来自含既存脏文件的受检工作树复制，不能冒称纯HEAD构建。
- EXE标题启动、编辑器引擎 `--main-pack` 开局诊断和实际EXE完整玩法是三种范围。此前有输入无运动的旧记录已纠正，本片没有新游戏实跑，也不签收EXE整局、性能、最低硬件或人工试玩。

## 验证与后续

新增 `test_current_chibi_and_environment_manifests_are_registered` 覆盖上述12份manifest的登记、路径与状态。旧表真实红测：7测试中的新增测试产生10个缺项失败，退出1；补表后7测试通过，退出0。12份manifest结构校验及 `validate_asset_registry.py` 通过。验证器本身仍只检查登记行/production manifest；环境由新增回归另核对，均不授权升级。

本次分进程运行30个 `test_*.py` 共222测试及 `validate_art_pipeline_skill.py` 的13测试：31套、235测试全部退出0；不是沿用上一片测试数字。另运行 `ChibiRuntimeArtTest` 50断言、`BossTest` 31断言，均退出0，原日志无脚本错误/泄漏标记。这是两套headless组件/绑定测试，不是新原生整局、性能或整套Godot复跑。原日志保留在本地 `build/diagnostics/source-review-v2/`，不冒称仓库已包含可移植原始日志包。20项既有用户脏文件的逐文件hash保护检查未变化。

独立只读审查核对快照54条文件记录的字节/hash/PNG头尺寸、17资产引用位置、12份声明及PCKhash，并独立重跑登记7测试、台账及12manifest校验；复核日志总数235与两Godot标记81。文档Boss函数名的小项已更正，最终无Critical/Required或遗留Optional/Nit；审查没有自行重跑Godot、原生整局或许可验收。

本片要完成的是现行清单一致性，而非素材权利签收。后续继续完整本地交接和性能测量；项目所有者提供缺失来源/输入权利证据前，授权pending/unknown和S5整体未完成状态保持。没有发布、付费、网页上传或扩大自动审批权限。
