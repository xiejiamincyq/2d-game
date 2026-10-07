# 2026-10-07 试玩反馈：榴弹速度与小怪群体运动

直接执行用户本次玩法要求及既有自主决策授权；不是新美术风格或发布任务。分支`5分钟超载`，基线`79bd63d`。旧冻结索引仅绑定v8，生产逻辑改变后不得冒称现行包仍已覆盖。

## 目标与边界

- 榴弹初速度严格为`player.velocity * 0.30 + aim_direction * projectile_speed * 0.40 * 1.20`。基础620时为297.6px/s，普通弹、射速、伤害/范围/寿命及主武器冲刺禁射不变；升级弹速仍按比例生效。
- 小怪在原追击/地形导航方向上受附近小怪速度对齐、低权重聚合、短距分离及大体积慢怪预测绕行影响，速度平滑且不超过自身有效速度。大型怪物不作为对齐速度样本，避免整个群体随其慢行；远程仍保持射程区间，近战攻击停步、出生冲量、隐身/燃烧、碰撞箱与伤害不改。
- 所有移动仍走真实`CharacterBody2D.move_and_slide()`及地图绕行。没有取消实体碰撞、穿怪或给敌人增加全图定位能力。邻域查询须局部化，避免新增每怪每帧全量扫描。

## 分片与验收

1. 榴弹：真实Player发射红测覆盖静止/前后/横向/斜向/高速度与升级弹速，核对实际飞行位移；修改最小常量/公式并同步3个旧合同断言，运行相关现有套件，独立审查、相关提交/推送。
2. 小怪：先独立真实节点红测重现邻居运动无影响/大型hitbox堵路；实现局部群体转向与绕行，测试远处/死亡/失效邻居、速度上限、近战停步及真实导航下的绕行进展。受影响回归和新边界测试通过再提交/推送。
3. 合并验收：隔离APPDATA串行运行完整门；固定真实碰撞诊断、原生短连续画面与至少一局真实输入自然流程；不把公式/截图计数代替运行表现。以新目录导出v9本机EXE/PCK，输入hash/导出日志/本地启动及来源边界核对，更新README和冻结状态，不覆盖v8。

## 文件与执行方式

生产入口`Player.gd`、`Enemy.gd`及必要邻域/转向组件；Godot测试在`scripts/tests`，记录在`docs`，原始日志/图像在ignored `build/diagnostics/gameplay-feedback-v1`。保持现有snake_case/显式Vector2类型，例如`velocity = player_velocity * 0.30 + aim_direction * base_speed`。本计划单独保存，不重写历史`tasks/plan.md`和`tasks/todo.md`。

针对项：`godot_console.exe --headless --audio-driver Dummy --path . --script res://scripts/tests/GrenadeVelocityTest.gd --quit-after 120`；群体项同样运行`EnemyFlockTest.gd`（较长物理帧预算）。完整门：`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1`，通过子进程APPDATA隔离，不触正式存档。导出使用既有`Windows Desktop`preset及实际源字节副本，不改发布配置。

常规系数由Codex按测试/实跑选择；新依赖、无关功能、许可提升、付款/公开发行不在授权内。保留20项原有脏文件及2项旧性能证据。通用技能的Definition of Done引用文件未安装，采用项目严格运行器、红绿/实际日志、针对性运行及审查门。

状态：三片技术工作均已完成。榴弹`2d6c838`、群体`a42a0ae`已提交/推送；最终完整门78 Godot/35 Python通过；相机必修问题补齐真实红绿测试并独立复审清零。最终源单局真实Input通关、普通EXE标题正常退出、实际v9 PCK四套196断言通过。v9生产194输入与登记/fresh副本一致，首次模板隔离导出失败保留并修复；详见[交接](../docs/local-playtest-handoff-v9.md)。不复用v8完整回归或旧压力数值冒称改动已验，真人手感及其他外部门未代签。
