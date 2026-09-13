# 玩家被敌群遮挡：A/B/C 预览审批

日期：2026-09-13。状态：待用户选择，未接入正式游戏。

证据：`player-occlusion-options-v1.png`。左上为当前规则，右上 A、左下 B、右下 C。使用真实 Player、Enemy、FloorGrid，保持原始运行尺寸；每组相同的四个 Overseer 和四个 Bruiser、固定位置与朝向、禁用自动处理。珊瑚色斜线只是用于检查覆盖关系的模拟危险线，不代表真实攻击测试。

- A：头顶定位标记。敌人完全不变，容易找到位置，但无法读到被挡住的身体动作。正式实现需要避开血条和 HUD。
- B：前方敌人的局部遮挡区域让位。最直接露出玩家，身体本身不透明；代价是敌人图像出现局部缺口。这是有意的预览效果，不是恢复曾经错误的整个人物半透明。
- C：玩家身体的浅色轮廓穿透。保留敌人外观，不把整个玩家本体置顶；代价是只显示轮廓，不能看清完整动作，重叠血条依然需要整理。当前只预览身体，不包括枪支。

倾向 C，但未替用户批准。三种方案均为独立渲染脚本中的原型，不改变 Player、Enemy、正式材质或碰撞规则，也不推进资源为 gameplay-approved/final。

## 验证与限制

Godot 4.7 导入通过；Vulkan 实际渲染无脚本/着色器错误，输出 960×720 图片并人工查看；Python 74 项通过。初次角色 ready 顺序及着色器采样参数错误已修正，错误图片不作为最终证据。仅预览工具变化，未重新跑完整 Godot 游戏套件。

预览不包含运动、隐身、死亡、入场、障碍物或真实弹体验证。选定方案后必须补充遮挡触发/退出、前后排序、隐身与离场清理、危险预警可见性、障碍物关系及性能回归；不能直接把此脚本中的高 z 层移入正式游戏。

美术管线要求保留已批准 B 角色/环境方向；本次新增遮挡呈现规则先展示对照，等待用户选择后再正式实施。

## 复现

```powershell
godot --audio-driver Dummy --path . --script res://scripts/art/RenderPlayerOcclusionOptions.gd --quit-after 180
```

`godot` 替换为本机 Godot 4.7 程序；同时检查输出不含 `SCRIPT ERROR`、`SHADER ERROR`、`ERROR:`，不能只依赖进程退出码或截图成功标记。

技术参考：[Godot 官方着色语言说明](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html)，纹理采样器通过函数参数传入轮廓采样函数。
