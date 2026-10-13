# R4b 窄束切片通过；整场观测者 Boss 尚未完成

真实 RiftObserverBoss（30 骨、HP10800、半径56、物理根不缩放旋转）和唯一 RiftObserverAttackDirector 已实现，只允许 beam，probes/refract 明确拒绝。第六关未注册、Ready 仍1–5；这不是整R4、Boss胜利或长期目标完成。

## 行为与实际验证

唯一时钟 warning0.30 / active0.12 / recovery0.45。预警只有黑边小感叹号，方向在预警开始锁定；进入 active 先采样真实动作，再读取 Pupil/AimOrigin。360px、半径8胶囊的显示和实际圆体相对扫掠共用几何，36伤害、每轮最多一次尝试，不随人物或目标追踪。

真实缺Actor/clock语义RED后建立未注册Actor框架，最初28项通过。审查补出的末帧测试真实失败：最后合法帧可以扣血但画面已清光束。修复为末帧保留ACTIVE/绘制，下一tick无伤害地进入RECOVERY；最终Clock33项actualexit0（0484db）。invalid delta不推进，攻击长帧>1/15取消、不补伤害且保留1.1秒间隔；暂停、目标/容器离场取消通过。三招轮换、全部Health phase、Owner重入和真实击杀仍由R4e验收。

自然physics普通输入覆盖30/60/120Hz、六个方向、反应至少0.15秒：18次横移均HP100，18次站立均HP64且只受一次。首版失败是测试输入在每帧被错误释放，仅修测试缩进，不改玩家或放宽断言。生产末帧修复后的工作区验证2836项/936次实际相邻位移、actualexit0（ef75a3）；随后当前独立PCK再次自然验证2835项，结果同样18避开/18受伤。帧数和断言数受自然调度量化影响，不把两次计数混成同一次；玩家始终235px/s、16.9px、HP100、无盾、无冲刺/隐身/碰撞禁用作弊。

## 原生挂点出生与真实GPU

四个真实骨挂点、左右镜像、默认层与QUERY_LAYER薄墙、挂点圆体和世界边界先真实语义RED（b7e7bb）：共享NativeProjectileOriginSafety漏了查询层2。只把该层并入共享ray/circle mask，不复制假出生检查。最终58项actualexit0（f370bc）；另验beam86/clock33/钟祭三招12、17、17/旧Boss原生50/取景1862，均actualexit0（862573）。

真正NVIDIA/OpenGL的1280×720第六地图seed521、生产Actor/Player/BossHealthBar，受控推进唯一clock而非整场普通试玩。检查左右短头标、active释放时无提前伤害、半径7px芯/11px外部、实际首击HP64、末帧仍可见、收招/暂停清除、物理根稳定和HUD安全区域。139项/10张图actualexit0（97a0f0），10图全部实际查看；41源SHA不变。交付11文件逐SHA一致，见[预警](art/previews/campaign/rift-observer-beam-v1/warning-1.png)、[发射](art/previews/campaign/rift-observer-beam-v1/active-release-1.png)、[末帧](art/previews/campaign/rift-observer-beam-v1/active-last-1.png)及[完整报告](art/previews/campaign/rift-observer-beam-v1/report.json)。报告SHA256 d803715f0c5fa161baa4a54939cdba2b102573fd194fd17c37c9cf9cfb3e8e28。

## 当前独立包

早期clock包6夹具3990项是共享出生修复前的历史证据。当前包首次失败保留：BossCameraFramingTest在外部夹具中仍引用被正确排除的res://scripts/tests/TestSupport.gd。仅把规范测试改为相对依赖并将同SHA支持文件复制到包外，不开放作者目录、不修改断言；工作区取景1862再次通过。修复后的当前包12规范夹具6006项、Main120、74证据源保持、所有测试实际exit0，整个脚本actualexit0（99eff7）。

PCK 7,088,196字节，SHA256 7e2b956038484c5dfb290e60adefd2b288a8248a5a92e7882a86fb4bd4269f6c。无测试/作者/源美术/docs目录入包；13个规范夹具/支持文件同SHA。正常导入actualexit0，两新增UID（OriginSafetyTest/Render）以及之前四个Actor/Director/Clock/Dodge UID保持。没有称这些专项为最新全量回归；R4e整Boss闭合才做全量并发一次阶段邮件。

## 下一步与未验收

下一R4c双探针：两个有限锁定落点、错位时间、真实左右关节出生、非钟祭往返弹；随后R4d分批折射和R4e完整Boss。R5真实第六关/save6与不产生7、F1正式主入口、F2连续六关普通解锁、F3长期构筑重玩、F4全文字/密集性能/许可/最终本机包均未完成。未安装/购买/复制参考资产，未碰真实保存或旧候选，未提交/推送/公开发布，goal active。
