# S1-A2：隐身恢复 R/U 分账验收 v1

2026-10-03，`5分钟超载`。本片定向验证及完整回归通过；commit/push 仍 pending。仅为 S1-A2 技术闭环，S1-B 至 S5 未完成，不代表项目、平衡、最终美术或人工试玩通过；不发布。

## 修复与证据边界

生产范围：`scripts/actors/Player.gd` 恢复窗口、`scripts/world/StealthRecoveryMotion.gd`、`scripts/world/TerrainSweep.gd`。正常非恢复移动保持原路径，不延长隐身、身体禁用或免疫，不改变技能时序。

R 只做一次实际 body/global transform、原 safe_margin、零 motion 的 `body_test_motion` 查询，始终读 result.travel；只接受地形/实体/边界安全的直线前缀，不写入原生候选再回退。U 从原输入初始化一次，只递推本阶段余量，不以“原输入减总位移”补走。R/U 共用 max_slides=4，内部查询次数另记，耗尽丢余量；velocity 不由恢复位移回灌。

证据分三层：数学反例仅证明独立检查器能拒绝归零后补走、来源链断开、错误投影、超预算和历史清零，不声称合成反例已在真实外凸角复现；QueryTest 六夹具实测只读查询前后位置/transform/velocity/shape/碰撞及生命状态不变，disabled shape 的零 travel 不冒充有效恢复；实际 R/U 轨迹再受独立分账、几何和连续输入诊断检验。

分账逐段检查 `Raccepted=beta*Rrequested`、`Uaccepted=alpha*bounded`、来源连续、有效法线投影、每前缀“累计路程+余量≤原U预算”及终点分解。独立线段-矩形/线段-圆几何检查整段安全，不只看终点；旧重叠不加深、改善后不回退、新敌不穿过。原几何容差0.1px、分账容差0.001保持不变。

恢复长测包含零输入/朝墙各5秒、上下各2秒、实体让开/死亡/shape移除、封闭出口重开、第二敌人、实际暂停恢复、从未隐身正常接触对照。新增敌人移除后连续顶墙11步：首步有真实地形输入约束且 changed_any=true，但 guard 退出；后10步恢复 trace 为空、guard 关闭且有实际 slide collision。不是把“没有碰撞”当作普通贴墙退出。

Area 正负控用真实 CoinPickup/Projectile shape 和组件回调，仅冻结传感器移动/寿命。负控保留接受位置2px初始间距，仅计算只读 `start+recovery_requested`，不写回角色；若提案未形成接触则失败为未证明。60Hz两个负控各48个提案接触、0个接受位置接触、最小实际间距2.000002px、0次进入/拾取/伤害；正控硬币真实进入1次、收集1次共7，弹丸真实进入1次、伤害3。不能用失效回调伪造安全。

## 实跑结果

下表数字为断言数而非覆盖率。定向日志由主代理实跑，本文只读核对完成标记；三频率按等模拟时长、实际物理步采样。

| 测试 | 30Hz | 60Hz | 120Hz |
| --- | ---: | ---: | ---: |
| StealthRecoveryTest | PASS4266 | PASS8388 | PASS16632 |
| StealthRecoverySideEffectTest | PASS628 | PASS1204 | PASS2356 |
| StealthRecoveryAccountingTest | PASS638 | PASS1214 | PASS2360 |
| StealthRecoveryQueryTest（6夹具） | PASS98 | PASS98 | PASS98 |
| StealthTerrainTest | 完整runner通过 | 定向PASS8356；完整runner通过 | 完整runner通过 |

最终 R/U 实现另有 DashTest PASS215、Phase20Test PASS17，不冒称默认配置为三频率矩阵。主代理最终完整 pre-push 实际 exit0：**PRE-PUSH PASS，53个Godot suites / 165803断言，24个Python suites / 87测试**，含 Terrain 30/120Hz；此结果不是本文另行复跑。

原始日志留本地 ignored `build/supervised-evidence/`：`StealthRecoveryTest-{30,60,120}-ru-v2.log`、`StealthRecoverySideEffectTest-{30,60,120}-ru-v2.log`、`stealth-accounting-{30,60,120}-ru-v2.log`、`stealth-query-{30,60,120}-v1.log`，以及 `StealthTerrainTest-ru-v1.log`、`DashTest-ru-v1.log`、`Phase20Test-ru-v1.log`。日志后缀不等于影片版本。

## 最终 V3 运行证据

[V3录像](stealth-recovery-runtime-v3.mp4) · [逐步JSON](stealth-recovery-runtime-v3.json) · [诊断PNG](stealth-recovery-runtime-v3.png)。主代理已看截图，它不是最终美术验收。最终重录为 Godot4.7、1280×720、60fps、275影片帧；JSON保存时 process_frames=274，不与编码帧数混用。JSON source_sha256 绑定最终 Player、StealthRecoveryMotion、TerrainSweep 与 VerifyStealthRecoveryRuntime 四个源文件。

真实 Input，独立 World2D，UP/DOWN顺序执行，各120物理步/2秒；ready后冻结并核对初始位置、等待时钟和shape，避免全局反向输入互相污染。玩家起点(63.1,0)、冻结BRUISER(30,0)，薄墙Rect2(80,-700,20,1400)。

| V3实测 | UP | DOWN |
| --- | ---: | ---: |
| 最终位置，约 | (63.02416,-469.99960) | (63.02416,469.99960) |
| 方向位移 / 实际shape最大地形侵入 | 470px / 0px | 470px / 0px |
| body恢复 / 分离 / guard退出且保持关闭 | 第1 / 7 / 8步 | 第1 / 7 / 8步 |
| 只读R提案最大侵入，未写回 | 4.8118042px | 4.8118042px |

4.8118px是被约束的只读提案，不是角色实际穿透；接受轨迹侵入0。录像由 clear_runtime_modifiers 触发恢复，无Main/存档/音频/开火/冲刺，是强制重叠组件证据，不代表自然整局、AI、性能或艺术验收；自然到期等路径由对应测试覆盖。

## 历史与交付

候选2错误diff/raw资料保留本地 ignored build；旧v1/v2诊断artifact不改、不充当fresh证据。在诊断产物范围内，本片仅拟提交最终V3 PNG/JSON/MP4及本报告，不混旧产物或无关在制品。

网页裁决05为历史已收到意见；最新人类规则是“Codex工作区判断为主，网页当前模型监督而非审批”。本轮新规则同步及重试出现 Unknown error、无法发送，未取得新监督意见，不能写成网页批准/看过V3/独立复跑；这不取消本地标准，也不阻塞已授权工作。

随后用户明确取消网页端使用，转由 Codex 自行判断：不再请求或等待网页监督；上述裁决与发送失败仅为历史背景，不存在网页待审批/待回门。技术证据、权限和不发布边界不变。

收尾状态：定向验证与完整回归已通过；聚焦commit/SHA **pending**，origin推送 **pending**，由主代理完成后登记。S1-B双轨36-run及S2—S5继续既定路线；不发布，不代签人工与最低硬件条件。
