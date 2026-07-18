# 五分钟超载清剿：实施清单

## Phase 1: 传送门暴兵

- [ ] Task 1：建立传送门生成竖切（预警、分帧爆发、关闭）
- [ ] Task 2：接入玩家环带内的 3–5 门攻势和全局生成预算
- [ ] Checkpoint：PortalTest、WaveTest、PerformanceTest 通过并完成人工观感检查

## Phase 2: 连杀超载

- [ ] Task 3：建立连杀充能和 2.8 秒自动超载状态机
- [ ] Task 4：实现超载无敌、4 倍全伤害和攻击加速的统一修饰器
- [ ] Task 5：完成触发重击、短循环、尾音、程序化特效和 HUD
- [ ] Checkpoint：超载起止清晰，无伤害、倍率、音频或暂停状态泄漏

## Phase 3: 极速构筑

- [ ] Task 6：建立升级家族、前置条件和保底进化选择
- [ ] Task 7：实现弹幕终极进化“轨道风暴”
- [ ] Task 8：实现无人机终极进化“雷网矩阵”
- [ ] Task 9：实现冲刺地刺终极进化“裂地超载”
- [ ] Checkpoint：三条路线均可在最终阶段前成型且通过性能上限测试

## Phase 4: 五分钟闭环与续玩

- [ ] Task 10：重构五阶段节奏和简化最终强敌
- [ ] Task 11：建立版本化阶段快照存档
- [ ] Task 12：接入继续游戏、清档和状态机流程
- [ ] Checkpoint：新游戏、保存、退出、继续、胜负和重开形成闭环

## Phase 5: 验收

- [ ] Task 13：收敛传送门、经验、超载、进化和最终阶段平衡
- [ ] 运行 `powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1`
- [ ] 运行 `git diff --check`
- [ ] 完成四种目标分辨率和三条构筑的手动试玩记录
- [ ] 确认提交不包含现有 `.superpowers/sdd` 临时文件或其他无关状态
