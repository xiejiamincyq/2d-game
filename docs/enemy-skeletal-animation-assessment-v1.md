# 敌怪2D骨骼动画可行性与工具

2026-10-09；状态：建议，尚未全量迁移，未安装任何动画MCP或付费软件。

## 当前事实

Enemy七类敌人与真正OverseerBoss目前使用整张128×128 PNG和Sprite2D。现有走路反馈是整图轻微摆动/压缩，不是真正肢体骨骼动画。本轮搜索未发现敌怪分层源文件、骨骼或动画工程；旧玩家3D资源不适用于已批准的2D Q版方向。

可以由代理在Godot内制作Skeleton2D/Bone2D与AnimationPlayer资源并接入游戏，不必先购买编辑器。但原PNG没有被遮挡肢体、关节重叠余量和分层；直接自动切割不能保证动作质量。需先拆分/补绘头、身体、左右肢体、武器、装饰等部件，骨骼驱动分层贴图，而不是取消贴图或晃动整张图片。

## 工具选择

1. **Godot原生2D骨骼，优先建议。** 现有项目可直接运行，资源为原生可编辑场景/动画，无额外付费动画运行库。参见[官方2D骨骼说明](https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html)。复杂动作可结合替换脸/手部图，不强行拉伸所有部位。
   MCP候选：[Vollkorn-Games/godot-mcp](https://github.com/Vollkorn-Games/godot-mcp)。作者文档列出节点、资源、脚本、create_animation_player/add_animation和运行/截图工具，适合创建骨骼场景与关键帧。它是社区项目，不是官方Godot服务；文档能力不等于本机实测。尚未连接，需先审查并用隔离样例验证。现有文件与Godot CLI已能执行原生资源制作，MCP并非制作的前置条件。
2. **Spine，专业付费备选。** 专门的2D绑定/关键帧/网格动画编辑器，适合以后人工精修大量动作；有[官方Godot运行库](https://us.esotericsoftware.com/spine-godot)，需要核对编辑器/导出/运行库版本、Godot版本与Spine Runtimes许可证。
   MCP并非Spine官方内置功能。[zhoushengmin/spine-mcp-server手册](https://github.com/zhoushengmin/spine-mcp-server/blob/master/docs/USER_MANUAL.en.md)明确目标3.8.75，称4.x格式可能失败，不建议新项目为此直接降级；另有[egorfedorov/spine-mcp](https://github.com/egorfedorov/spine-mcp)，从分层/切分素材生成骨骼与动画，涉及4.2 JSON/4.3 CLI，其Windows与本项目的兼容性尚未实测。不能把社区桥接存在当作整套生产可用。

## 建议先做一只样板

- 保持已批准2D Q版、加粗轮廓和当前视角，先选追击者；按美术管线提供拆件/绑定预览，确认后再扩展。
- 样板动作：待机、行走、短预警、抓击、扑击、受击、死亡；命中仍由已有战斗时钟决定，动画跟随状态，不改变既定前摇/频率/伤害或hitbox。
- 检查轮廓穿插、左右朝向、取消/隐身/死亡、暂停与高密度性能；通过游戏内动态预览后再做其他小怪与Boss阶段/技能动作。
- 保留旧资源回退；不一次性替换全套，不用骨骼动效掩盖画面拼缝，不对未验证性能或美术质量作完成保证。

用户不需要先学习完整绑定流程；可由代理完成资源与接入，用户检查预览。若选择Spine，正版授权和兼容MCP验证需要另行确认；当前推荐先走免费原生Godot样板。
