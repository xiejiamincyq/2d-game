# R4e自动战斗：进行中，尚未阶段验收

最新终态：独立自动包25夹具/24555、Main120、7,100,260字节和release实际退出0；精确银行收据已保存。随后第六薄协调与Ready6开发接入/受控验证通过，当前普通路线GPU进行中。联合最终门及准确证据范围见[第六关当前进展](rift-chapter-progress-review-v1.md)。下文25936运行、Ready未开放等为此前快照；中断全量不算通过，R4/R5仍未签完。

2026-10-12继续核对：会话28159已不存在（工具返回Unknown process id），系统没有本次测试Godot/runner，仅旧GUI41396保留；v2日志最后写入2026-10-11 21:27:04，165套Godot PASS、零失败标记、无最终TEST RUN PASS。实际进程退出码未收回，因此此轮是**中断且未完成**，不能把165套当全量通过。保留日志，先启动同源独立包`rift-observer-automatic-pack-v1`会话25936；其终态之后再补完整回归，不因观察超时重启，也不关闭旧试玩。下方28159“仍运行”是前次观察时的历史。

仅`5分钟超载`工作树；长期goal仍active，R4e/R5/F1–F4均未签完，不开放第六、不修改正式存档、不发阶段邮件或中间提交推送。

## 实际实现与已有验证

唯一生产变更是`RiftObserverAttackDirector`：每个真实血量阶段依次自动beam→probes→refract，阶段进入重置索引；第三阶段沿用0.85秒间隔，其余1.1秒。远于340时0.2秒后重试；严格Beacon挂点受阻会跳过该槽至下一合法攻击，每次最多三次尝试，不伪造中央折射出生点或同帧无限重试。没有修改Player速度、判定圆、伤害、Boss生命、动作库或地图。

初始规范确实语义RED（645b93）：只出现六次beam。修正后自动路由37及原BeamClock34/ProbeAttack767/RefractAttack660/Gate17/Motion33实际exit0（11d902）。生命周期180项实际exit0（611848），三招分别覆盖暂停、玩家死亡/退出/排队删除、投射物容器退出/排队删除、Boss死亡/退出/排队删除、真实隐身、长帧、阶段/死亡及伤害回调重入。只有真实Health归零发一次died，取消不造胜利。

原生集成23项实际exit0（fe0d51）：真实30骨/14片段、一次入场及入场免伤、真实物理走动、实际暂停冻结本体/骨骼/燃烧/唯一时钟、恢复、镜像、不改变物理root的受击、真实70%/35%阶段、原生尸体保持Transform且不能复活。此前怀疑的通用Boss暂停漂移并未复现：入场结束既有代码已切换PAUSABLE，没有为假设改基础Actor。

新独立Runtime夹具只preload生产资源，适合之后在作者/tests被排除的PCK外运行。解析类型错误保留v1失败日志（35304f），仅显式bool修复；自然headless v2实际exit0/2886项（b8239e）。真实NVIDIA RTX5060 Laptop/OpenGL连续GPU v2实际exit0/2953项（63744f），两侧真实8秒左右、普通Player100/235/16.9/无盾/无冲刺/无隐身/无瞬移，305+303相邻移动、474+480实际引擎指针，HP76/100，均完整完成第一轮三招。Health阶段与死亡检查明确采用受控Boss伤害，不是自然胜利或正式六关证明。

GPU v2的26图均已实际查看，包含双侧三招短头标及真正中途飞行（不是刚出生与骨挂点重合的替身）、暂停清除、实际受击、两个Health阶段、960/1280/1920尺寸和死亡初帧；24个带取景元数据的捕获均both_fit=true。37个已记录源SHA；证据`build/diagnostics/campaign-goal/rift_observer_runtime_gpu_v2/`。此报告仍是**待补的中间证据**，尚未作为最终交付或包前置通过。

## 复核缺口已修正；终态门仍未闭合

1. 第二轮缺口已语义RED复现（6badf2：启动6但完成5），随后等待refract恢复IDLE并断言completed6；三阶段40项actualexit0（0b632d）。
2. 死亡抓帧过早已语义RED（85f605），改为自然physics/process等待动画到0.55秒，实际Torso变形且尸体root保持原Transform；再等实际自然销毁和一次died，不用seek/advance伪装。当前GPU v3通过这些检查。
3. HUD未初始化已语义RED（ff49e0），仅Runtime夹具像ChapterRun同步真实shield/max_shield和signal。当前26图为0/20；正式生产协调无需修改，Player数值不变。
4. 原OriginSafety测试另复现退出0但没有PASS：64次真实physics注册超过120个未限速process帧。Python runner守卫先RED（864dda），再为该套指定既有3000/max-fps120组；Origin58、runner3均actualexit0（0b632d），不降低PASS门。

全量v1在OriginSafety已确定失败后，仅停止归属本次runner的pwsh25340及当时Godot子进程56316（beb9a4）；会话58382实际终态exit-1（f2cc10），失败日志保留，不能称其全量完成。不是因为观测缺失重启，不关闭其他试玩。修正后新的全量v2会话28159仍在运行，日志`rift-observer-r4e-full-v2.log`；恢复同一任务，禁止再开Godot或修改其冻结源。

当前GPU v3实际exit0/2964项（5e6bcd），37源/26PNG；两侧普通自然移动305/303、实际引擎指针474/481、HP76/100，均第一轮三招自然完整结束。26PNG及report已逐个核SHA复制到`docs/art/previews/campaign/rift-observer-runtime-v1/`（4a8a85），本轮全部26图实际查看。死亡两侧均实际0.55秒倒塌而非死亡初帧；24个非死亡取景均both_fit。只证明夹具的自然躲避与受控阶段/死亡，不是正式第六胜利或完整六关链。六旧冻结资源按coverage报告中两个旧Boss的scene/motion/manifest准确定位，当前六SHA一致。

视觉复核另保留F4待核对项：Runtime夹具1280/1920缩镜时部分顶边露出灰色地图外背景；角色双方均入镜不代表完整视觉通过。夹具Camera2D未像正式ChapterRun一样设置地图边界限制，所以当前不能断言正式游戏已有同一问题。正式关卡取景/背景覆盖必须另做普通地图实测，再按实际原因修复，不为通过本切片隐藏该事实。独立PCK、release、最终全量与终态源复核尚待实际完成，不签R4e/整R4。

正常import已生成四新UID。run_tests已注册四夹具；包工具保持默认十图前置，只新增明确的ExpectedCombatCaptureCount参数以严格接受该套26图，未放宽作者源排除或30MiB预算。

五轴只读复核未发现新增路由实现的确定阻断、安全或明显性能问题；复核**未运行测试**，不替代终态。全部所需证据闭合后才可勾R4e及整R4、发送一次阶段Gmail，再实施R5正式第六协调与真实死亡保存。后续F1正式开始/继续入口、F2新独立档真实1→6链、F3多种子构筑平衡、F4最终视觉/密集性能/许可/交付仍完整保留。
