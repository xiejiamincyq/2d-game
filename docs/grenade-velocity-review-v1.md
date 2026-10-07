# 榴弹速度修复（2026-10-07）

按用户试玩反馈修改火力终极进化`orbital_storm`的真实发射分支：`初速度 = Player.velocity × 0.30 + 射向 × projectile_speed × 0.48`。原基础系数0.40提升20%后为0.48；基础620时静止榴弹248→297.6px/s，前/后运动235时为368.1/227.1px/s，不再是483/13px/s。升级弹速仍比例生效。普通弹仍继承100%玩家速度；射速20%、伤害300%、爆炸范围/近炸/寿命和冲刺禁射不改。

真实Player发射`GrenadeVelocityTest`覆盖620/900基础弹速、6种玩家矢量（含高速）和2种射向，核对生成弹的矢量、伤害及实际0.05秒飞行位移，另验普通弹。旧实现实际红测退出1；修复后73断言通过。随后将测试物理禁用移至入树后，排除自动驱动副作用，新run仍73断言退出0。旧3项速度合同同步新的用户要求，不删除测试。

相关`DamageTest`51、`Phase19Test`25、`Phase20Test`17、`RateTest`10、`ProjectilePickupTest`20均实际退出0，合计6套196断言；三通道无错误/泄漏标记。隔离APPDATA，不写正式存档。资源导入另退出0。原日志保留在本机ignored `build/diagnostics/gameplay-feedback-v1/{grenade-red-v1,grenade-green-v1,grenade-green-v2}`，失败不覆盖。

本片只修速度，不称已解决小怪群体移动，也不称旧v8已包含修复。执行计划见[试玩反馈方案](../tasks/gameplay-feedback-plan-v1.md)。完整回归与新本机v9导出安排在群体运动片完成后；此前可运行当前Godot源码，v8仍是历史包。未修改任何位图、来源/许可或发布权限。
