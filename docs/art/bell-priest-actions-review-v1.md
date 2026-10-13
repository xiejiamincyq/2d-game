# 钟骨司祭 E4a：独立原生动作资源自审

2026-10-11，分支 `5分钟超载`，整体 goal active。本轮独立v2资源和视觉时钟适配、最终全量/独立PCK/release已通过，只勾E4a；不是实际Boss战或第五关完成。Main仍[1,2,3,4]，正式第五关、三招实际判定、保存解锁6待E4b/E5。

## 资源、风格与所有权

沿用本目标新作的原创墨线纸偶钟骨司祭26骨身体，而非旧PNG或旧大型攻击素材。保留已审查的五个新原生基础片段，新增钟槌/双坠/冠钟各warning、attack、recovery九片段，共14。哑光铜钟、钟舌/钟唇、左右七节手臂链坠、头冠与肋板分别运动，动作不只由物理根晃动或特效承担。

新场景 `bell_priest_paper_v2.tscn`、外部 `bell_priest_motion_v2.tres` 和manifest独立保存，v1和冻结名册不改。独立 `bell_priest_attack_v1.json` 仅授权本资源从已冻结v1派生；资源授权不能成为关卡完成授权，其他首领的请求不能冒用。离线作者脚本拒绝任何已有输出，后续修订须显式新版本，不通过删除旧输出重跑规避保护。

所有新增轨道只驱动Bone2D position/rotation/scale，没有动画伤害事件、透明度轨道、物理根轨道、位图、运行时作者依赖或第三方库。视觉时长：钟槌0.24/0.42/0.54秒，双坠0.22/0.56/0.66秒，冠钟0.24/0.48/0.60秒；仅动作取样时长，不是已冻结可躲避的攻击时间。冠钟三次张开中间有回落，不能用三张相同峰值图冒称没有运动。

NativeBellPriestMotion复用NativeBossMotion，只读取未来唯一导演的动作、1–3阶段和已过时间；不推进战斗、不造成伤害，不改变CharacterBody2D根。真实Boss/导演尚不存在，本轮用明确标注的受控时钟验证适配契约，而非冒称普通实战。入场优先，非攻击恢复步态/待机/受击，死后不能复活。以后短头标须依真实头部定位，不能把本轮仅用于取景的宽边界当头部或碰撞盒。

## 先失败再实现，以及真实取景修复

授权、资源、Motion契约分别先执行缺少能力的语义RED：`bell-priest-gate-red-v1.log`、`bell-priest-resource-red-v1.log`、`bell-priest-motion-red-v1.log`，均真实退出1。没有把解析错误或超时算RED。实现后授权16、当前资源1148、Motion27检查终态退出0；NativeRigCheckpoint44及原书记授权15也通过，额外白名单请求的原测试循环增加一项属真实覆盖，没有删断言。

初次GPU `bell_priest_actions_gpu_v1` 实际退出1：双坠active、左右和闪白四姿态各1598实色像素超出旧静止姿态的视觉声明；局部测量 `bell_priest_actions_bounds_red_v1` 保持旧16 padding后再次退出1，最大额外43.342285像素。真实图像本身没有透明或320边缘截断，但旧视觉范围不能正确描述甩出的链坠，会影响未来镜头取景。

仅draft v2的视觉padding按16+测量43.343+不足5像素余量改为64，作者脚本和序列化资源保持一致。没有缩动作、放宽测试、改变玩家速度/身体、Boss物理碰撞或alpha，v1仍16。当前资源测试固定此边界，最终GPU继续逐帧检验真实像素在当前声明内；失败日志/图/原SHA全部保留，不改名为通过证据。

## 实际像素与运动证据

最终 `bell-priest-actions-gpu-v2.log` 真实退出0，638检查；14片段×3时相×左右×原有hit-flash 0/0.35，共168 GPU姿态，另有三招各30个连续active画面，共90。不透明像素均超过3000、partial alpha 0、320视口边缘像素0；非死亡姿态及90连续active全部在声明内，死亡也检查实际画面无边缘截断。

29对相邻采样中，钟槌27/双坠20/冠钟27对像素真正变化，不把输入决策数当运动数。真实Marker2D世界跨度分别33.9684/70.0568/11.2652像素；资源测试另验证阶段连续、回收超过20像素、取消全部26骨rest、真实胸钟下敲/冠钟肋板张开、四语义挂点以及死亡禁重启。

作者实际读过三个当前PNG：[三招七时相](previews/campaign/bell-priest-actions-v2/action-keyframes.png)、[右面向](previews/campaign/bell-priest-actions-v2/action-poses.png)、[左面向](previews/campaign/bell-priest-actions-v2/action-poses-left.png)。三行分别钟槌、双坠、冠钟；七列含动作峰值和谷值，保持实色细墨线和克制身体张开。左右姿态、胸钟下敲、链坠外展回收和冠钟倾转可辨，仍需E4b真实战斗和后续人类手感验收。

[原始JSON](previews/campaign/bell-priest-actions-v2/report.json)冻结14源SHA，前后未变。三PNG+原JSON四交付文件逐SHA复制一致；仅比较PNG/JSON，不删除引擎.import侧车。报告保留原始build路径和当时范围，不假装是Boss战/普通躲避/整关胜利/解锁6、OS输入或密集性能证据。

## 最终回归与独立包门

当前生产源冻结后串行执行，均实际终态退出0、唯一正PASS、无ERROR/TEST FAIL/资源或RID泄漏：

- `bell-priest-actions-complete-full-v1.log`：264 Godot套件/250733断言、36 Python套件/272测试。旧前四关正式流程和三个新Bell专项均在内。
- `bell-priest-actions-complete-pack-v1.log`：36规范专项/21055断言、Main120；其中Bell Motion27、名册644以及当前E3遭遇/动态分离和旧E2真实物理均通过。不同自然输入运行计数变化，未改日志凑数。
- 同一包外部 `VerifyBellPriestPackedResources.gd`：315检查，作者manifest/Bake确实不可访问；真实v2的26骨/权重/14片段/四挂点/取消rest可加载。新旧原生skin顶点/色/三角划分/每骨rest与权重/全部身体变换一致，64仅视觉边界，不是缩身体或改碰撞。该自足作者夹具在包外按SHA复制，没有将正确排除的作者脚本放回PCK。
- 本包6791840字节，SHA256 `7f236c4e4b9d8db9f136322b8b758fb38bbdc9c306bd5f2669791cc93f22923b`，验证前后不变、30MiB预算内。38份规范夹具/支持/外部资源脚本逐SHA一致，导出+36专项+Main+资源共39日志干净。没有--path工作区生产资源回退。
- `bell-priest-actions-release-v1.log`：RELEASE CHECK PASS，同大小6791840字节/独立Main120。只是本地独立包门，没有生成新试玩EXE或公开发布。

GPU14当前来源SHA与四交付PNG/JSON在上述执行后仍一致；v1 scene/motion与冻结覆盖内SHA相同。名册review/coverage及旧A5 EXE/PCK四SHA也不变。真实保存/旧v13/旧可玩候选/失败证据和原有无关工作保留，未清理或纳入中间提交。HEAD仍713dde5f75dd0827b7c56ab195d55eed5826c5a4，暂存0，无本轮提交/推送。

实际命令均在指定工作树；GPU为真实gl_compatibility，不是headless图像替代：

```powershell
$taskEngine='C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
& $taskEngine --headless --audio-driver Dummy --path . --editor --quit
& $taskEngine --headless --audio-driver Dummy --path . --script res://scripts/tests/BellPriestAttackResourceTest.gd --quit-after 120
& $taskEngine --headless --audio-driver Dummy --path . --script res://scripts/tests/BellPriestMotionContractTest.gd --quit-after 120
& $taskEngine --audio-driver Dummy --path . --rendering-method gl_compatibility --max-fps 120 --script res://scripts/art/RenderBellPriestActions.gd -- bell_priest_actions_gpu_v2
& scripts/tests/run_tests.ps1
$taskAdditional=@('EchoLayoutTest','EchoMapTest','EchoMovementTest','EchoBeatTest','EchoFieldTest','EchoBeatPhysicsTest','EchoBeatEntitySeparationTest','EchoEncounterPolicyTest','EchoEncounterTest','EchoEncounterRuntimeTest','ArchiveChapterTest','ArchiveChapterLaunchTest','SaltChapterTest','SaltChapterLaunchTest','FoundryChapterTest','FoundryChapterLaunchTest','NurseryChapterTest','SharedChapterRunTest','CampaignChapterLaunchTest','BellPriestMotionContractTest')
& scripts/tests/verify_archive_boss_pack.ps1 -EvidenceId bell-priest-actions-complete-pack-v1 -AdditionalSuites $taskAdditional -ExtraFixtures TestSupport
& scripts/tests/run_release_checks.ps1
```

外部资源夹具按源SHA复制到上述独立证据目录；从该目录运行引擎 `--headless --audio-driver Dummy --main-pack <同一绝对PCK路径> --script <外部夹具绝对路径> --quit-after 120`，不加--path。完整终态记录与脚本副本留在证据目录，不把此资源专项冒称普通首领实战。

## 五轴审查和下一依赖

正确性：授权隔离、原始基础动作逐key保留、阶段连续和取消、真实GPU取景RED后测量修复；明确资源与实战边界。可读性：独立小作者/采样/资源和Motion测试，阶段命名沿用原生约定。架构：专属10行Motion只复用共享基类，未在Main或公共碰撞里插特例，不另造通用战斗框架。安全：本地原创、输出新路径保护、冻结SHA，不提取付费/安装/发布/触碰真实保存。性能：运行仅资源和读时钟适配，像素扫描属于离线作者验证，不当作密集战斗性能门。

下一E4b-1真实Actor/唯一导演与Health/短头标/失败取消，再逐招真实形状/薄墙/普通走位30/60/120Hz及站立命中对照；完整自动阶段与死亡归属后才E5正式入口/保存解锁6。当前整体未完成，不提交/推送中间里程碑，不重发E3邮件。美术管线将资源/身体/当前像素/实际判定区分；调试技能要求先保留真实失败并量边界，只修视觉元数据；没有把授权或像素PASS扩张成整关验收。

E4a所有门完成后，经指定Gmail连接向认证账户本人发送一次资源阶段完成邮件，消息ID `1a12945cac40575c`；明确项目继续与未完成Boss/入口，不重发E1/E2/E3/A5。最后文档状态4测试/registry7测试及实际台账VALID通过，git diff --check通过；工作区1026项状态记录/暂存0，含原有长期工作和无关内容，均保留，没有中间提交或推送。
