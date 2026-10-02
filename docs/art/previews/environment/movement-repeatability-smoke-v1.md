# S1-B：真实输入采样工具初始切片

2026-10-03，`5分钟超载`。仅完成初始化、输入、存档隔离和诊断清理的短运行；**不是36次矩阵、平衡通过或实时时钟验收**。不修改玩家/敌人生产行为，不发布。

## 已实现

- 在 Main 进入树之前分配唯一 `user://movement-repeatability/<run>/run.json`；运行前后检查真实默认/测试存档及其 `.tmp/.bak` 的哈希，已有 run id 拒绝覆盖。
- 固定全局种子、地图与刷怪随机流初值、阵型索引；60个真实AI压力夹具，不锁血、不逐帧重置敌人。普通遭遇与整局仍待测。
- 真实 Input 行走/开火/冲刺及 SubViewport 鼠标事件，逐实际物理步检查输入、瞄准和连续采样；记录时间、位置、生命、敌人数与随机流状态。
- D仅压制hit-stop时长；R调用生产hit-stop，保留伤害、击杀和反馈。自然到期、状态重置与诊断清理恢复分开记录。
- 输出到 ignored `build/diagnostics/movement-repeatability/<run>.json`，标记 `measurement_only`；脚本完成标记不是平衡测试PASS。

## 当前可复跑命令

从项目工作树运行；每次改用未使用的安全 `--run` 标识。以下固定帧命令只用于采样冒烟：

```powershell
godot_console --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://scripts/art/VerifyMovementRepeatability.gd --quit-after 3000 -- --seed=20260908 --track=D --mode=walk --clock=fixed --run=local-d-walk-001 --steps=120
godot_console --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://scripts/art/VerifyMovementRepeatability.gd --quit-after 3000 -- --seed=20260908 --track=R --mode=dash --clock=fixed --run=local-r-dash-001 --steps=220
```

支持种子20260908/09/10，D/R，walk/dash，1至1200步，clock默认unknown。`--clock=realtime`也只是启动声明，不会自动设置 `real_clock_pass=true`。

## 本轮实跑

全部为独立进程、60Hz、Dummy音频，正常退出且无错误/泄漏标记。实际存档哈希前后一致、隔离树释放。数字不作为重复性或平衡门槛。

| run id | 模式 | 步数 | 末生命 | 实际冲刺步 | 顿帧请求 | 时钟分类 |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| smoke-d-walk-05 | D walk | 120 | 76 | 0 | 4（夹具压制） | 不适用D |
| smoke-r-dash-02 | R dash | 220 | 68 | 10 | 24 | sampling_smoke_declared_fixed |
| smoke-r-unknown-01 | R walk | 20 | 100 | 0 | 0 | sampling_smoke_clock_unknown |

R dash记录8次自然到期恢复，但使用加速固定帧，不能因此宣称真实体验中的顿帧持续时间通过。所有报告 `real_clock_pass=false`。

本切片提交前再次完整检查：PRE-PUSH PASS，53个Godot套件、165792断言，24个Python套件、87测试。断言总数是本次实际执行数，不作为固定覆盖率或确定性证明；采样工具另外以表中三次运行验证。

## 已发现并修正的测量问题

1. 首次编译因Variant路径类型推断失败；明确String后重新运行。
2. 初始退出报告AudioStreamWAV/PlaybackWAV引用泄漏。复用现有TestSupport音频释放并在测量结束后等待250ms真实墙钟，再释放完整树。最终推荐Dummy运行未见泄漏；不把音频驱动变化混淆为单一修复因果。
3. 实测 `OS.get_cmdline_args()` 不包含引擎消费的 `--fixed-fps`，不能据缺失参数推断实时运行。旧R01的实时路径标签无效；保留旧JSON，不改写历史。当前记录可见参数“不完整”、显式clock声明、实际墙钟/模拟步比，未知默认不通过。

## 下一片

完成不依赖“每渲染帧正好一个物理步”的实时采样，再执行既定三种子×三次×walk/dash×D/R矩阵；检查真实冲刺触发、掉帧/死亡终止、顿帧时钟及重复轨迹差异。远程敌人仍用墙钟和实例ID摆动，固定种子不等于已证明确定性，不在本片偷偷改AI或平衡。

用户已取消网页端，后续由Codex自行判断；保持原技术验收和不发布边界。
