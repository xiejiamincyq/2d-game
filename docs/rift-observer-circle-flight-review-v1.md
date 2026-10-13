# R4d d0：保持行为的有限圆飞行提取

后续d1–d3现已按[R4d当前实际GPU与独立包审查](rift-observer-refract-complete-review-v1.md)完成；本文保留d0当时结构验收范围，不代替后续新攻击或整目标。

已验证的独立结构切片；不是折射攻击或第六关完成。2026-10-11，工作树`.worktrees/5分钟超载`，分支`5分钟超载`，HEAD仍713dde5，无提交/推送/邮件。

先写CircleFlightTest；第一轮错误地静态调用Script方法，exit1解析失败，不算语义RED。仅修正测试实例调用后，第二轮因真实缺少内核资源exit1，才开始生产提取。保留`build/diagnostics/campaign-goal/rift-observer-circle-flight-red-v1.log`和`red-v2.log`。

Observer局部RefCounted内核承接原Probe上下文、全路径薄墙、有限时间、分段相对圆扫掠、寿命裁剪、最后合法帧和重入前共享attempt。每次arm固定配置只采样一次，用double标量，不用float32向量包装；基类未配置不能arm。Probe仍6/360/0.12飞行+0.08驻留/27，原画法未动；Director、Player、Health和地图不变，没有第二clock。具体固定配置/画法仍在窄叶组件，三批策略不进内核或通用Boss层。

实际8组串行受控测试exit0/唯一正数PASS/无错误泄漏：CircleFlight20、Probe101、分段边界37、真实出生边界64、ProbeAttack766、BeamClock33、Beam86、OriginSafety58。日志`<Suite>-shared-kernel-v1.log`。新测试证明armed后配置突变不会改变半径、速度、寿命、伤害，并检查无配置和非法配置拒绝。

正常physics回归实际终态exit0：BeamDodge2836/936真实相邻位移，18普通输入延迟0.15秒躲避+18站立受36；ProbeDodge6480/2160位移，18双探针延迟躲避+18站立受27，以及原6+6超距控制。日志`<Suite>-shared-kernel-natural-v1.log`；30/60/120Hz，Player仍100/235/16.9，不用盾/冲刺/隐身或瞬移。执行器记录`exec-27ece97c-5ef9-4f90-ab82-69f95f715a99` completed/exit0，104645ms；观察丢失时只恢复既有终态，不重跑。

五轴自审：扫掠算法和Probe画法等价；固定getter只在arm调用，热帧不额外生成对象；查询仍有32饱和门；无依赖、I/O、存档或秘密；缩减叶组件重复判定，不扩大到通用弹幕框架。尚未进行新源GPU/PCK，本步仅结构回归。旧R4c 81源/GPU/PCK已成为历史，不冒称当前同源。d1/d2/d3和R4e/R5/F1–F4继续未完成，refract仍拒绝、Ready仍1–5。
