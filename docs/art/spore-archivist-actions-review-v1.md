# 菌光档案 A4-A：藏孢书记独立动作资源

2026-10-11。本记录只审查原生骨骼动作资源，不是第四关 Boss 战完成。整体 goal active，第四关入口仍关闭，不能保存解锁5。资源状态 draft；不提交/推送中间里程碑、不更新旧试玩 EXE、不动真实存档、不公开发布。

## 原创与迁移边界

在已审查的原创墨线纸偶身体上制作新动作：27 Bone2D、原生加权 Polygon2D、外置可编辑 AnimationLibrary。书页/书脊、菌盖/菌褶、孢囊、手臂、披风下摆分别运动，不靠整个角色绕物理中心转圈。没有纹理回退、外部付费图、下载依赖或动画方法轨道；本阶段没有采用新的第三方素材，`license_origin=project-original` 不等于游戏全部素材许可总门已完成。

独立 `spore_archivist_paper_v2.tscn` / `spore_archivist_motion_v2.tres` 保留新体系已通过的 idle/walk/hit/entrance/death 五个基础片段，另外原创九个攻击阶段片段。这里保留的是本长期目标期间已重新制作并审查的原生资源，**不是沿用旧 PNG 动画**。v1 场景、v1 动作库、v1 声明和冻结全名册/覆盖报告不修改。单独 `spore_archivist_attack_v1` 只授权该候选从其27骨基线迁移，潮壳/炉工/藤卫门不能授权它；作者拥有用户授予的常规美术自主决定权。

## 动作契约与后续接口

| 动作 | warning / attack / recovery 秒 | 局部动作 | 语义挂点 |
|---|---|---|---|
| page | .22 / .40 / .52 | 书抬起、两页反向翻动/回翻、前臂跟随和下摆滞后 | Torso/Book/Spine/IndexOrigin |
| seal | .24 / .28 / .64 | 菌盖压缩后舒展、左右菌褶独立张合、手臂展开 | Torso/Head/Cap/SporeOrigin |
| brood | .26 / .36 / .70 | 孢囊压缩与释放、书脊敲动、左右前臂回摆 | Torso/SporeSatchel/ColonyOrigin |

上述是**资源采样时长**，不是已经验证的伤害/孢点落地时间。下一阶段由唯一攻击导演决定真实锁向页刃、两个短命封签孢点及有绝对上限的召囊/增援，再做真实30/60/120Hz逃离和墙/出生安全测试。AnimationPlayer由权威状态采样，不发伤害、不控制物理根、不改变身体 alpha；资源内实验 Warning 标签始终抑制。真正头顶短感叹号和必要薄落点提示在 Actor/世界状态层实现，本资源预览没有假装这些已经接入。

每个片段至少八个局部骨骼发生变化；相邻阶段端点连续，取消恢复所有27个关节的 rest；死亡锁定后不能重新攻击。五个基线片段逐轨道路径/类型/关键帧时间和值比对，镜像只翻 Facing，物理根不变。

## 测试先行与失败记录

- `archivist-actions-red-SporeArchivistAttackGateTest-v1.log`：终态1，缺独立迁移授权的预期 RED。
- `archivist-actions-red-SporeArchivistAttackResourceTest-v1.log`：终态1，缺版本化动作资源的预期 RED。均不是解析错误冒充 RED。
- 新授权门14检查，作者 Bake27骨/九新片段/三既有语义挂点、v1场景及库SHA不变，通过。
- `archivist-actions-green-SporeArchivistAttackResourceTest-v1.log`：真实执行后只有翻页幅度断言失败，终态1。定位到夹具选 .08/.30 秒两个近峰值，序列实际关键帧是 .08→.22→.32 秒，对应 .34→-.18→.34 弧度。修正第二取样到真正回翻点 .22，仍要求幅度差>.25，没有改动作或降低门限。当前 v2 **1169** 检查通过；stage连续/复位/基线保持/死亡等断言都保留。

## 当前 GPU 与读图

`archivist_actions_gpu_v1` 是通过但尚无极值/回翻对照的历史报告（448）。补充对照图后当前 `archivist_actions_gpu_v2` **449检查、168姿态**：14片段×三个时点×左右朝向×普通/真实闪白 shader。所有采样身体实色、无部分alpha/画面边缘裁切；非death采样全部在声明身体视觉边界内。每招30连续取样，相邻变化 page24 / seal12 / brood12；只统计实际相邻图像变化，不把输入次数当动作帧。

作者已查看两张左右九姿态图及当前极值/回翻图。三招偏克制，书页往返真实可见，封签/召囊主要是局部开合，不增加厚光/满屏喷发。预览在当前1:1原生尺度，纸色书本、菌盖主轮廓与深色披风保持不透明且完整。三张图仅证明这些资源的局部视觉，不证明真实战斗中提示可读性或攻击命中。

交付目录 `docs/art/previews/campaign/spore-archivist-actions-v1/`：两张左右姿态图、`action-keyframes.png` 和原始 `report.json`。全部四文件从 GPU v2逐SHA复制核对，报告11个源/资源SHA逐项检查。关键帧图行序 page/seal/brood，列序进度0/.20/.55/.80/1；九姿态图列序page/seal/brood、行序warning/attack/recovery。

## 当前终门与未完成范围

`archivist-actions-full-v1.log` 完整串行终态0，明确 `TEST RUN PASS: 235 godot suites (227213 assertions), 36 python suites (272 tests)`，无错误/泄漏、无跳过套件或降低门限。导入已生成五个新作者/测试脚本的真正 UID sidecar；全部脚本创建后才执行导入与完整回归，没有在回归中并行导出/渲染。

独立 `archivist-actions-pack-v1/game.pck` **6,538,012字节**，SHA256 **609c9fbdcf32304e442790d1f5d6425144ec962f581ff530e301d68240a17616**。离开源码目录、无 `--path`、只加载导出PCK：外部 `VerifySporeArchivistPackedResources.gd` **266** 检查实际v2权重/九攻击片段/物理根/复位/书脊挂点，并拒绝作者源码或声明泄入PCK；外部基线 `SporeArchivistPlaybackTest.gd` **13** 检查v1入口/步态/受击/暂停/镜像/脱离死亡。后者明确是旧基础资源回归，不冒充v2战斗适配。独立Main120终态0、无错误/泄漏。`archivist-actions-release-v1.log` 明确 RELEASE CHECK PASS，同 **6,538,012字节**，Main120且作者/测试导出排除门通过。未更新用户旧EXE或存档。

五维作者自审：契约/取消/端点连续及基线保持有真实测试；作者生成器只离线运行且拒绝覆盖现有输出；不往公共战斗模块添加角色分支，仅增加独立资源门声明；不引入第三方依赖/秘钥/运行时下载；所有GPU扫描/采样有有限上界，未改变游戏热路径。这里是作者自审与实际测试，不称独立他人/真人审查，也不将资源采样当性能测量。

A4第一子项资源门完成；真实ArchiveBoss、碰撞/出弹/逃离、阶段/有限召囊、实际Boss GPU、正式第四关及解锁5均未实现，A4其余两项与A5保持未完成。下一阶段明确需要在真实Boss死亡、仍存活Mote和待分裂后代同时存在时测试胜利边界：共享章节目前在Boss真正死亡离树后直接CLEARED，不能用这一默认路径掩盖危险/出生归属或放任战后攻击。按“击败Boss解锁”设计取消危险与战后出生，不伪造随从击杀奖励，再以RED选择最小适配。此处只是已核对源码的待验证风险，未声称修复完成。

本资源阶段通知已通过用户指定 Gmail 发送一次，ID `1a1285c8a5da2b89`。邮件明确资源门完成但Boss战/第四关入口/六关整体未完成，不重复发送此前A3通知。当前分支仍 `5分钟超载`，HEAD保持 `713dde5f75dd0827b7c56ab195d55eed5826c5a4`，无新增提交/推送，既有未暂存和无关变更均保留。
