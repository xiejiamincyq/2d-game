# 原生普通怪骨骼技术样板审查

2026-10-09；`5分钟超载`。结论：原生骨链与动作工程样板可留存；**角色风格未通过正式美术门禁，不接入游戏、不计作全套资源完成**。

## 已证明的内容

- `scenes/art/technical/NativeMonsterSample.tscn`为真正Skeleton2D/Bone2D层级：躯干、头、双上臂/前臂/手、双腿/脚，共12关节，各有显式rest/长度。不是旋转一张完整人物贴图。
- AnimationPlayer六条新动作：待机1.2秒、行走0.64秒循环、头顶感叹号预警0.18秒、普通攻击0.36秒、受击0.16秒、死亡0.42秒。没有大型敌人/Boss新攻击动画。
- `play_clip`拒绝未知动作/死亡后的动作，重复idle/walk不重启时相；`cancel_action`清理队列/rest/标记；`reset_sample`仅为实验室显式重置。镜像只影响Facing；动画不改根节点位置/缩放/旋转，不含碰撞或伤害方法轨道。
- 专项测试245断言，覆盖骨链联动、全部动作、取消/暂停/终止/重复行走、源文件hash与不透明调色。实际游戏攻击钟、AI、血条还未与此组件连接。
- NVIDIA RTX 5060 Laptop / Godot 4.7 / Compatibility实际渲染的v3预览：1280×720、60个实际时间采样帧，59次相邻像素变化。PNG为动作中间姿势比较，MP4为60Hz的一秒动作采样，不等于真人游玩或自然输入的战斗验证。

预览：`docs/art/previews/campaign/native-monster-technical-v3.png` / `.mp4`。SHA-256分别 `eace0c42d67a55ea1b27607966011ead470794cde45b92c9473a1eb6c42dbee6` / `46f0caa098688f124a7ffe463a89acb213c5c04812ce7562c5ca6ecff6883dd9`。

## 素材与风格结论

7个未修改字节的Kenney Monster Builder Pack单张拆件，包内CC0许可、作品页、ZIP与单文件hash位于 `assets/art/source/campaign_native_sample_v1/`。新制作骨骼、场景调色/缩放/挂点及关键帧，不使用游戏旧玩家/敌人PNG。完整包仅保存在ignored build，未执行URL/SWF。

实际小尺寸表情可读，身体调色alpha保持1；但方形手脚、曲线臂重复接节、缺少强墨线轮廓，不符合正式原创纸偶风格。技术样板不作为正式风格锁，不将CC0参考冒称全部原创。后续需新皮肤、关节接缝和地图背景对比验收。

## 性能测量与撤回决策

串行原生v4视觉样板：每档30帧预热、120帧采样、1280×720离屏viewport、关闭vsync请求、循环walk。帧墙钟是process_frame至frame_post_draw间隔，不含AI/物理/正常输入/PresentMon掉帧，不是整场战斗预算。

| 怪数 | 原生关节 | 帧墙钟P95 ms | 创建ms | 最大绘制调用 |
|---|---:|---:|---:|---:|
| 32 | 384 | 1.578 | 16.422 | 480 |
| 128 | 1536 | 5.556 | 48.132 | 1920 |
| 256 | 3072 | 11.893 | 94.658 | 3840 |

原始记录：`build/diagnostics/campaign-goal/native-monster-density-v4.json/.log`。256只仅视觉已占明显成本；不得据此宣称六关密集战斗性能通过。

图集试验：包内Spritesheet与单PNG是不同导出，原始源像素已有差异（如body_whiteC 728像素变化、213像素alpha不同），不是Godot裁切错位。共用RID仍为约3584调用，只减少约6.7%；试验并行录制，墙钟不能当严格对比。撤回该切换而非放宽等价断言；新hash测试保护所选单PNG的确切来源。候选图集/tres已可恢复地移入 `build/diagnostics/campaign-goal/rejected-official-atlas-v1/`，v2录制为被拒候选，不能当最终证据。v1的TIME_PROCESS监视列混入低频/创建读数，明确废弃；v4仅使用逐帧墙钟。

正式角色设计必须限制皮肤片数、复用动画资源，并评估原生加权Polygon2D/可批渲染皮肤；测量后选方案，不能把这只高节点数样板直接复制为六区成品。

## 导出与审查边界

Windows preset排除全部source素材及`scenes/art/technical/*`，release门禁检查导出转录。当前实际PCK 3,034,912字节、主场景120帧无错误/泄漏通过；只证明旧游戏打包仍可启动，不证明新骨骼或六关在PCK内可玩。

当前严格回归通过：91 Godot套件175176断言、35 Python套件270测试，日志 `build/diagnostics/campaign-goal/native-sample-full-green-v3.log`。导出范围专项先RED（门禁未检查technical路径）再GREEN七测试；源哈希专项245断言通过。PCK/渲染进程均检查实际退出0及无错误/泄漏，不用进程存活推断通过。

改动只增加隔离技术场景/测试/渲染及预算探针、来源与导出排除；未改游戏碰撞、伤害、当前角色、地图、旧存档或Boss动作。代码审查已逐项检查状态恢复、方法轨道、根变换、来源、帧采样与导出范围；性能和正式风格仍是生产接入门，不被本技术交付替代。

后续：完成角色风格锁与紧凑原生皮肤，普通怪生产动作通过真实战斗和密集预算后再接入。开始页和六关闭环仍按总计划推进；全部骨骼齐备之前不制作大型攻击。
