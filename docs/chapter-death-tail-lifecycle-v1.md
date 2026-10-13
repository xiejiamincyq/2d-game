# F4通关死亡尾段：生命周期切片

2026-10-12，“5分钟超载”；这不是普通输入胜利证明，也不是整个F4/全项目验收。

## 原因与最小变化

真实Chapter受控遭遇/奖励/UI、真实Boss入场与take_damage、实际通关保存会暂停SceneTree。原死亡视觉已脱离Actor、没有碰撞，但PAUSABLE+PHYSICS动画也被冻结。`chapter-death-tail-red-v1.log`实际exit1，仅两个语义失败：Boss尾段和小怪尾段无法完成；手动暂停对照本来正确。

NativeScrapperMotion只在release_death后将ghost加入native_death_tail组。ChapterRun._modal只在Director.CLEARED时调用settle_cleared_death_tails；该方法只放行当前owner子树中的已脱离死亡视觉，不放行活体、不修改树暂停、不改变奖励/保存。保存失败同属CLEARED，死亡视觉也可结束；重新保存不会重复奖励。group自随Node释放消失。

手动暂停仍冻结死亡视觉；任何其他owner的tail不放行。原章节离开时ghost仍在章节子树内，随场景释放。不改变死亡游戏事件/击杀计数、攻击/移动或碰撞。

## 验证与复核

初次GREEN28未充分证明活玩家暂停边界：继承受控fixture停用过玩家physics。独立只读复核发现后补证，不用旧28宣称活体边界已实测。当前测试恢复真实玩家physics，普通UP六个真实physics帧先证明位移；手动暂停和通关期间physics仍开启但can_process=false。通关后另保留活敌，检查位置/HP/处理保持；永久SHA不变。外owner真实死亡tail不放行，取消owner后释放。

当前实际GPU v2 exit0、唯一ChapterDeathTailTest44、无错误/泄漏；四图在`build/diagnostics/campaign-goal/chapter-death-tail-gpu-v2/`，日志`chapter-death-tail-gpu-green-v2.log`。本主实看saved_clear_start/finished，两图通关面板遮挡了部分死亡Actor，因此它们证明实际界面/渲染，不单凭图片宣称动画全部可见；完成/释放由实际AnimationPlayer和Node状态检查证明。旧v1图/37检查不覆盖。

生产同版相关回归EnemyNative40/NativeLegacyBoss50/NurseryChapter46 actual0/唯一PASS/无错误泄漏，保留原手动暂停和真实保存失败重试测试。独立只读复核确认Required已消除，无新增Critical/Required；未冒称复核者重新跑GPU或看图。正式run_tests已注册1800frame/max-fps120；PowerShell解析与diff检查通过。

下一视觉切片为六区物理边界外的原创低对比衬底，先真实边缘GPU RED，不缩掉Boss、不扩大地图碰撞、不遮掉高优先级危险提示。F4文字许可/密集性能/最终当前full、独立本地候选、新同源六关链仍未完成。不中间Git/邮件，不公开发布。
