# S5 提前准备：当前运行素材来源与记录缺口

日期：2026-10-02。分支：`5分钟超载`。保存报告时 HEAD：`12d6e7a`。

状态：`needs_review`。本报告是工程侧证据清单，不是法律意见，也不批准素材使用、公开发布或发行。

## 范围与方法

本次只读扫描了当前运行脚本、场景资源、素材文件、`docs/art/manifests`、资产台账、既有来源审计、导出配置及音频文件的 Git 历史。没有联网、下载、运行游戏、执行验证器或构建导出包。报告保存是本次唯一文件修改；没有修改源代码、素材、manifest、台账或许可状态。

这里的“运行引用”指静态代码加载及调用链证据，不冒充本次完整局实测。必须区分：当前正常玩法使用、代码预加载但正常流程未生成、旧资源未被玩法引用、导出包是否包含、来源记录是否存在、使用权是否批准。后四者不能由前两者自动推出。

本次对 `docs/art/manifests/**/*.json` 的只读 JSON 扫描结果为 **59 份：57 份 `pending`、2 份 `not-applicable`、0 份 `approved`**。这是包含历史预览的 manifest 数量，不是当前运行文件数量，也不是 59 项独立生成任务。

## 当前 2D 角色、战斗与环境引用

下表路径以项目根目录为基准。角色 manifest 位于 `docs/art/manifests/characters-combat/`。

| 运行路径与代码证据 | 来源记录 | 本次确认与缺口 |
| --- | --- | --- |
| `Player.gd` 的 `PLAYER_CARDINAL_ATLAS_PATH`、`PLAYER_WEAPON_PATH`：`assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png`、`player_chibi_b_weapon_cardinal_atlas_v1.png` | `player_base.production-v2-chibi-b.json`、`player_weapon.production-v2-chibi-b.json` | 登记为内置 imagegen 加本地处理；所列 `assets/art/source/chibi_b/` PNG 与运行文件存在。两份均 `license_review_state: pending`。 |
| `Enemy.gd` 的七个 `*_TEXTURE`：`assets/art/actors/enemies/enemy_{scrapper,dasher,spitter,bruiser,marksman,lobber,overseer}_chibi_b_v1.png` | 对应七份 `enemy_*.production-v2-chibi-b.json` | 所列源图及运行文件存在；登记为 imagegen 加透明处理/打包，全部 `pending`。其中 chibi Overseer 被预加载，但当前正常六波的旧 `EnemyKind.OVERSEER` 数量均为 0，不能据此声称最终 Boss 已换图。 |
| `CombatVfx.gd:9`：`assets/art/effects/combat_hit_chibi_b_v1.png` | `combat_hit.production-v1-chibi-b.json` | 源图及运行文件存在，登记为 imagegen 加打包，`pending`。 |
| `FloorGrid.gd:6`：`assets/art/environment/mint_farm_floor_b_v1.png` | `docs/art/manifests/mint_farm_floor_b_v1.json` | 登记为 imagegen，`pending`。本次读取 PNG 头确认运行文件为 1254×1254；512×512 是绘制重复单元，不应据此断言源图丢失。 |
| `ArenaObstacle.gd:4`：`assets/art/environment/mint_farm_props_b_packed_v1.png` | `docs/art/manifests/mint_farm_props_b_v1.json` | 登记为 imagegen，`pending`。保留 `docs/art/sources/mint_farm_props_b_original_v1.png`，manifest 记录 2172×724 原图和 1088×1088 无缩放重排；本次不重新证明像素等价。 |

上述 **10 个 chibi 角色/战斗资源**及 **2 个环境资源**均有 manifest，但来源字段存在不等于使用权审查完成。当前记录没有给出可据以升级 `approved` 的完整账户适用条款确认及输入权利审查结果；这些结论保持 `unknown`。

玩家身体 manifest 的 `references` 还含 prompt-library ID `23749` 和第三方示例图片 URL，角色写为 “layout consistency reference only”。现有登记没有完整证明该图是否被实际作为生成输入、使用方式及其输入权利；均保持 `unknown`，不能反向猜测“已输入”或“未输入”。

环境来源补充可查 `docs/art/previews/environment/mint-farm-review-v1.md` 的“生成来源”：保留了地面、障碍及透明修订的 `exec-*.png` 标识。该文档的处理授权和本地打包记录不是素材权利批准记录。

## 最终 Boss 仍在使用的旧资源

此项不能归入“全部旧图仅作历史”。

- `scripts/systems/WaveDirector.gd:27` 加载 `OverseerBoss.gd`，`_spawn_boss_at()` 在 `:384` 创建独立 Boss。
- `scripts/actors/OverseerBoss.gd:24` 加载 `assets/art/actors/enemies/enemy_overseer.png`，`_setup_visual()` 在 `:331` 绑定该纹理。
- 对应 `enemy_overseer.production-v1.json` 描述旧 45°四足指挥机械及青紫霓虹配色；`:18` 明示 `reconstructed-brief-exact-provider-prompt-unavailable`，`:32` 为 `license_review_state: pending`。
- 它的生成来源登记为 imagegen，并保留 `assets/art/source/enemies/enemy_overseer_chroma_v1.png`、`enemy_overseer_alpha_v1.png` 的来源链；它不是这里所说的 Hunyuan 玩家模型。
- 新的 `enemy_overseer.production-v2-chibi-b.json` 与旧 Boss 并非同一运行文件。当前不能宣称“全部正式角色已经统一为新 chibi 美术”，也不能用新 manifest 覆盖旧 Boss 的来源状态。

该差异供 S3 视觉裁决及 S5 清单使用；本报告不自行更换 Boss 素材。

## 音频：用户提供文件与程序化声音分开记录

### 用户提供的 Bone Breaking 文件

“用户提供”来自当前监督任务上下文，不是此次从仓库单独证明的事实。仓库可以证明的是：

- `scripts/systems/AudioManager.gd:6` 加载 `assets/audio/overdrive_bone_breaking.mp3`，`streams["overdrive_kill"]` 使用该文件。
- Git 提交 `96e2dfe`（2026-07-22）引入该文件替换旧 sword-slice 音效；`b4011cd` 同日裁剪起始段。
- `scripts/tests/CombatFeedbackTest.gd:105` 的 “approved Bone Breaking source” 断言只检查资源路径，不构成作者、来源或许可证据。

本次在已跟踪文档及 manifest 中未检出此 MP3 的作者、原始来源网址、适用许可文本或用户拥有/获准使用该文件的证明。上述字段均为 `unknown`。文件名、用户提供、已提交和已通过播放测试，都不能被改写成“授权通过”。

### 程序化声音

`AudioManager.gd` 从 `:193` 起的 `_make_tone()`、`_make_bgm_loop()`、各 `_make_*` 合成函数生成其他主要 BGM/音效。本次应将它们登记为本地程序化代码来源，与外部 MP3 及 imagegen 图像分开；这只说明生成路径，不自动给出任何法律许可结论。

## 旧 3D/M2：未用于当前玩法，但包内状态未知

当前正式 Player、Enemy、systems、Main 和 scenes 的静态引用扫描没有查到 `player_m2_*_120yaw` 或玩家 GLB 的加载。旧 `player_m2_runtime_animation.preview-v1.json` 中的 `runtime_integration` 是历史状态，不是当前代码证明。

仍保留的旧资源包括：

- `assets/art/actors/player/player_m2_ready_120yaw.png`
- `assets/art/actors/player/player_m2_move_120yaw.png`
- `assets/art/actors/player/player_m2_fire_120yaw.png`
- `assets/art/source/player/` 下的历史 GLB、建模及烘焙来源。

既有 `docs/art/reviews/asset-license-audit-2026-08-30.md` 记录旧 Hunyuan → M2 派生链和未完成的权利审查。本次不联网复核这些历史条款，不把其对旧资源的描述直接套用到当前 chibi 玩家，也不宣布旧链限制已经消失。

`export_presets.cfg:9` 为 `export_filter="all_resources"`；`:11` 排除了 `assets/art/source/*` 等历史源目录，却没有排除上述三张 M2 运行图集。因此只能写：**当前玩法未引用；现导出配置未确保排除；实际包内状态 `unknown`**。本次没有构建或检查 PCK，不能声称“已经进入包”或“不会进入包”。

同一导出配置还排除整个 `scripts/art/*`，而 `scripts/Main.gd:4` 正式依赖 `scripts/art/PlayerOcclusionOutline.gd`。这是 S5 本地导出验收的静态风险，不是本次已复现的导出故障。

## 台账、审计快照与验证器覆盖缺口

1. `docs/art/asset-registry.md:16–33` 的角色/战斗表格缺少本报告列出的 10 个 chibi 资源。`:44` 虽将旧角色说明标为历史，但 `:52–59` 仍以“已锁定”标题保留 M2 120 向、45°和旧 Dasher 动作合同。当前运行文件与明确的历史归类尚未形成一份一致台账。
2. `asset-license-audit-2026-08-30.md:7` 的 47 份、45 pending、2 not-applicable 是当日快照，不覆盖本次 59 份、57 pending、2 not-applicable 的集合。不能把历史数量当作当前完整性证明。
3. `scripts/art/validate_asset_registry.py:70` 只加载 `*.production-v*.json`；`:120` 仅遍历已有台账行，没有从运行依赖反查未登记资产。缺少台账行的 chibi 素材不会因此被发现；两份环境 manifest 也不匹配该加载文件名模式。台账校验通过不等于当前运行来源与许可已经完整覆盖。

## 后续处理边界

- 建立当前运行清单、历史保留清单与实际导出包清单的对应关系，再更新台账；本报告没有替它们修改状态。
- 由监督者确认旧 Boss 的视觉处理；由有权限的项目所有者补充音频来源和图像输入/账户条款证据。缺失项继续 `unknown`，不以推测补齐。
- 本地导出时实际检查 M2 等历史资源及轮廓脚本的包内情况；导出能力和结果尚未在本次验证。
- 任何素材都没有因本报告提升为 `approved` 或 `final`；没有授权发布、删除历史资源、改变仓库权限或扩大使用范围。

本报告保留的是证据与结论边界。文档技能促使其将“已核实引用”“历史记录”“未知权利条件”和“未执行的包验证”分开，避免后续交接把技术测试通过误记为素材许可通过。
