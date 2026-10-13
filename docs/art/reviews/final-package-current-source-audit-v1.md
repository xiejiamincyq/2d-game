# 最终独立包前置审查（2026-10-12）

状态：只读审查完成，修复/实际独立包未完成。全量会话57700运行期间不修改被冻结的代码、场景、shader、UID、导出配置或runner。不能把本报告当成最终验收。

## 必须处理的三个缺口

1. `verify_rift_observer_actions_pack.ps1`硬编码旧`rift_observer_actions_gpu_v2/report.json`。该报告23个依赖中，当前`Player.gd`与`NativeRigCheckpoint.gd`的SHA已不同。终态后用新的输出ID重新运行原来的GPU脚本，不改写旧报告。包门接收明确的当前报告，核对非空依赖、真实退出/PASS/无错误、168关键姿态、90连续样本、3实际尺度样本及四张图片SHA，并记录报告和日志本身。
2. `NativeImpactArtTest`与`NativeArenaArtTest`兼有作者manifest断言和运行时断言。docs有意不进入PCK，不能把它们直接复制到独立包运行，也不能塞回作者目录或移除原断言。终态后以可复制的canonical运行时夹具覆盖真实几何、预算、地板shader、四角色、碰撞和仅Art淡出；作者测试保留manifest校验。Legacy使用现有`LegacyOverseerMotionIntegrationTest`即可。
3. `CombatFeedbackTest`和`ArenaRuntimeTest`依赖绝对`res://scripts/tests/TestSupport.gd`，当前包门没有闭合这两个支持路径。若最终选择这些夹具，改为明确的包外相对支持依赖，逐SHA复制；否则使用不依赖作者目录的运行时夹具。制作/测试目录在包内不存在的断言继续保留。

只修改最终验证适配，不因此改变玩家参数、敌人伤害、地图规则、存档语义或美术方向。新的测试/runner版本与冻结全量版本分别记账；不能称先前全量覆盖未来改动。

## 实际声明与权利状态分列

- native-manifests当前35份：33份Actor声明`project-original`，28份style-approved、5份draft。五个draft是`tide_shell_paper_v2`、`spore_archivist_paper_v2`、`bell_priest_paper_v2`、`rift_observer_paper_v2`、`root_overseer_paper_v1`，均有真实消费者。
- 另外两份Salt环境manifest采用不同schema，仍draft/pending，不能因缺少Actor字段就误判为缺失Actor资源。
- 实际读取`paper_impact_native_v1`与`arena_paper_environment_v1`两份style-manifest，当前均为style-approved。它们只代表对应局部原创风格评审，不是全部资产许可/最终包批准。
- 历史位图与来源pending记录保留；源码无消费和精确exclude通过，不等于实际新PCK目录已退出这些资源。

最终仍需实际导出独立候选、核对包目录与运行时资源、同源六关链、保存前后、当前普通流程/性能以及角色动画消费者完整性。自动输入、受控GPU、实际操作系统输入和真人试玩分别陈述。无中间提交推送、无公开发布。
