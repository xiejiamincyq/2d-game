# Boss持续受击可读性与首个干净自然六景

2026-10-04，`5分钟超载`。Codex自主判断、不使用网页、不发布。保留B清爽玩具/薄荷农场/C明显轮廓，不生成或改动位图，不提升素材来源/许可状态。

## 根因与最小修复

自然Boss原帧持续全白；Player无人机每个物理步调用正式take_damage，Boss每次把80ms闪白重置到1.0，连续命中使Shader长期把身体RGB混到白色。不是角色Alpha故障，也不能通过减少命中或伤害解决。

仅在OverseerBoss增加`HIT_FLASH_AMOUNT=0.35`并替换两处1.0。继续使用原80ms计时与共享Shader，保留65%的原RGB贡献；ShaderAlpha、入场渐显、正常不透明度、56px碰撞、10800生命、移动、攻击、伤害/事件/命中频率完全不改。其他普通敌人的闪白不改。

旧BossTest要求几乎100%变白，现明确改为“立即有反馈且不超过40%变白”；这是对有视觉问题的旧表现要求的修订，不删除伤害、生命周期或时序检查。

## 红绿、原生组件和逐帧对照

- BossReadabilityTest修前真实失败：`flash=1.0 frame=0`。修后244断言，覆盖120次连续LASER命中、120伤害/120事件、根与Sprite Alpha1、碰撞/阶段不改、80ms后清除。BossTest31通过。
- 复用VerifyBossArt，用相同组件脚本/目标轨迹、360步、90—300帧每帧真实1伤害；每次211命中，最终HP10589。左右上方为冻结参考姿势；下方实际Boss物理回调，是组件诊断，不是自然输入。修前/后分别idle、single、sustained、recovered四张原PNG和363帧60fps影片。
- 360步身体位置/速度、朝向、Sprite局部姿态、入场Alpha、生命/阶段完全相同，机械差异0；只有受击材质参数从1.0到0.35，恢复均0。
- 实际看修前idle/sustained及修后single/sustained/recovered，身体不再变整块白。对应同姿势原图区域，修前11640个近白样本，修后仅7个仍近白、8790个有明显色差；这不是所有抗锯齿Alpha边缘或全场景验收声明。
- 两次真实Vulkan渲染退出0，原日志零错误/泄漏、orphan0、图像和当前源码SHA检查通过。影片Movie Maker固定步长只用于组件运动，不用于真实预警时长/性能结论。
- 首次录制扩展有suffix动态类型编译错误，原日志保留；明确String类型后使用新的AVI/log路径，未覆盖失败。首个PowerShell外部计数把Properties.Count读成四个1而拒绝，改为显式数组Count=4后再核验；未改生产或降低实际四图/211命中门槛。

## 自然六波与六景（不是全项目视觉批准）

`boss-readable-natural-09-v1`，初始全局RNG20260909、实际地图种子2573397633；正式输入pilot、六波/自然Boss/真实伤害与顿帧/首结算C/最终R。10476有效战斗步，自然胜利、621击杀、最低HP86，原日志零错误/泄漏，六真实存档路径哈希不变、orphan0。

开场、可视围堵、冲刺、实际相交落点预警、Boss攻击、商店全部自然出现，各30原帧共180张，`--require-six`严格外部检查通过：原日志、自然报告、图像/时间/起始条件、源SHA和missing均有效。实际Windows Vulkan Forward+ / RTX5060 Laptop GPU / 1280×720 / 60物理Hz、max-fps60，没有fixed-fps/MovieMaker。它有诊断GPU读回和图像内存开销，不是性能测量。

根代理实际看六景000/015/029共18张原帧，确认Boss在真实连续激光下保留颜色，商店首帧无遮挡。但旧瞄准环会盖住敌人/Boss中心，脚下条、技能、落点线仍有青蓝/品红霓虹，高密度危险不够清楚，下一片继续这些问题。商店30帧包含正常选择后到第二波的变化，不是持续商店停留。没有声称全部连续视频已经人工观看、四向/同条件前后六景或独立最终复跑通过。

当前完整门60 Godot套件166688断言、28 Python套件178测试通过。旧v1带3221错误和v2五景不足的记录保留，不能回填成新六景通过；新自然seed09与旧seed08不同，不作严格前后配对。S2—S5整体、人工手感、最低硬件和素材许可证仍待验。

独立只读代码/证据审查未发现阻断或必须修复项：重新比较360帧十类机械字段共3600项、差异0，检查八张组件PNG及归档绑定SHA，并看修前/后sustained和自然Boss原帧。审查没有运行Godot，不冒称独立复跑。两个可选加固留作后续独立切片：闪光测试增加可见强度下界，以及录制开始时对全部四张输出图进行查重；当前归档源码不在采集后回改。80ms未变由源码差异佐证，测试只验证81ms后清除；120次LASER是直接组件调用，不代替自然无人机时序。

## 证据与复现

证据包[boss-readability-evidence-v1.zip](boss-readability-evidence-v1.zip)，22836455字节、89条目，SHA256 `35c44517a0c6bb751a9c8bc3f458f727999be89186a8c24327d9b4ab9105ac8d`。包含组件原图/JSON/影片、原始红绿/失败/门日志；自然六景000/015/029共18原PNG、全部180帧的六条有损MP4预览、完整manifest/报告/日志/源快照。其余自然原PNG和原AVI保留本地build，不把大型原诊断素材写入Git。自然MP4名义15fps、30帧约2秒，实际采样节奏以manifest的逐帧wall/physics/process时间为准。

```powershell
godot_console --headless --path . --audio-driver Dummy --script res://scripts/tests/BossReadabilityTest.gd --quit-after 120
godot_console --path . --audio-driver Dummy --max-fps 60 --resolution 1280x720 --script res://scripts/art/VerifyNaturalRunRendered.gd -- --seed=20260909 --run=fresh-id --steps=36000 --clock=realtime
python -B scripts/art/check_natural_render.py build/diagnostics/natural-run/captures-fresh-id.json --report build/diagnostics/natural-run/fresh-id.json --log fresh-id.log --require-six
```

保存原始输出、每次用新ID；当前代码不会自动回退到修前100%闪白重拍旧图。归档源码以采集版本为准，后续视觉修改须新录制，不篡改报告使旧证据符合新源SHA。较小Git包不含全部原PNG，不能单凭它重新执行180张逐图哈希检查。
