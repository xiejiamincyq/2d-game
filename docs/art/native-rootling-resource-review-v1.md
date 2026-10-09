# 可编辑原生树苗纸偶资源：骨骼候选，不是六关成品

2026-10-09；`5分钟超载`，goal继续active。承接[加权皮肤验证](rootling-paper-skin-review-v1.md)，将原创草稿机械序列化为实际可编辑的Godot资源，没有沿用v13贴图或旧动作。

## 可直接编辑的内容

- 场景：`scenes/actors/native/rootling_paper_v3.tscn`，包含真实Skeleton2D、十二Bone2D、带完整权重的Polygon2D、AnimationPlayer与头顶Warning。不是仅含脚本、运行时才生出骨骼的空场景。
- 独立动作库：`assets/art/actors/native/rootling_motion_v3.tres`，本目标新制作的六动作；Scene引用同一外部库，而非重复嵌入一份。
- 纯视觉控制器：`scripts/components/NativeActorView.gd`，连续走路不会每次重启，取消回rest，死亡终止、暂停遵守SceneTree，镜像只动Facing。没有移动、碰撞、生命值或方法命中轨道。
- 原创来源和草稿限制：[原生manifest](native-manifests/rootling_paper_v1.json)。没有第三方图片运行依赖；未将原创资源擅自标为CC0，也没有重标旧音效许可。

在Godot编辑器里打开场景即可编辑骨链、网格权重或AnimationPlayer中的独立动作库。当前仍为`draft`；实际Enemy接入、时钟绑定、血条/标记布局、玩家/大型静态/效果风格锁都未完成。

## 自主美术审查

[六动作](previews/campaign/rootling-native-resource-v1.png) / [实际秒数运动](previews/campaign/rootling-native-resource-v1.mp4) / [暗地面与群体](previews/campaign/rootling-native-readability-v1.png)。三者均来自真实GPU原生场景，不是整张贴图播放；contact sheet的放大倍率2.0x，右侧为实际尺寸。

浅纸底、深苔绿、灰紫和石色背景已检查；头部木色/象牙眼睛与深地面有区分，短感叹号未改成长地面大圈。群体重叠时后排脚会被遮住，这是布局/排序检验，不是自然移动或真实战斗证据。轮廓可继续作为普通怪候选，但仍需完整角色风格组与游戏中的密集遮挡、受击、血条验证。

[透明背景原生画面](previews/campaign/rootling-native-opacity-v1.png)与[报告](previews/campaign/rootling-native-opacity-v1.json)：idle/rest画面1951个完全不透明像素、0个半透明像素，头部核心不透明、角落透明。报告只证明这一个姿态；不能拿它替代所有动作/战斗的alpha审查。

## 原生校验与真实失败

PNG规范和原PNG registry校验器保持不变；另设`NativeArtValidator.gd`及`VerifyNativeArtCatalog.gd`，检查实际Scene/Library依赖、骨骼数量、每顶点完整归一权重、rest pose、face索引、颜色/祖先/Polygon2D透明度、必要动作、非视觉轨道和证据文件。当前仅接受工程已审查的project-original资源；其他许可类型不得自动混入。结构通过不是许可或画面质量自动批准。

大型/Boss的新攻击资源在当前资源门未齐之前拒绝；本轮没制作大型攻击。未来完成全骨骼门后须明确更新这条门禁，不隐式放开。

资源专项先缺场景RED退出1，再GREEN；外部动画库断言又发现v1/v2重复嵌入，确实退出1。最小实测发现保存后resource_path仍为空；[Godot4.7 ResourceSaver源码](https://raw.githubusercontent.com/godotengine/godot/4.7/core/io/resource_saver.cpp)显示CHANGE_PATH保存成功后恢复旧路径，因此不能据保存成功认定资源已成为外部引用。v3重新加载实际保存文件再赋给AnimationPlayer，通过181断言。

原生校验专项还得到过资源缺失、JSON数字12不能往返、遗漏证据、缺失几何权重门、Polygon2D基色半透明的RED；当前36断言GREEN，实际目录1个declared resource通过。它没有声称全角色/六区资源齐备。未批准的v1/v2场景与动作库、临时序列化probe移入`build/diagnostics/campaign-goal/rejected-native-serialization-v1/`，可恢复，没有删除旧用户资源。

全量运行首次退出0：95 Godot套件176275断言、35 Python套件270测试，`build/diagnostics/campaign-goal/native-resource-full-green-v1.log`。之后仅补Polygon2D基色alpha门及该专项，最终36断言通过；不把旧全量断言数加一伪装成新全量日志。

## 导出证明与边界

实际PCK3,081,856字节。空的隔离项目目录使用`--main-pack`启动`rootling_paper_v3.tscn`120帧，verbose记录原始场景、独立库与NativeActorView的`Completed load`，无错误/泄漏。最初检查脚本只匹配`Loading resource`原始路径而失败；实际导出转换成`.scn/.res/.gdc`，对同一已完成日志核验原始路径的Completed load后通过，没有重启来冒充修复。

证据：`native-resource-pack-export-v1.log`、`native-resource-pack-run-v1.log`、`native-resource-pack-verbose-v1.log`，均在`build/diagnostics/campaign-goal/`。旧Main的实际PCK120帧检查也通过：`native-resource-release-v1.log`。技术场景/作者脚本仍排除；原生候选资源可导出，但Main尚未使用，不能称当前试玩已换骨骼。

Scene SHA256：`79367d87f21a5669cc94c1bda3b0641fe8c7e129bb823420249a2f7a93692e4a`；Library SHA256：`64bbe5cb38b4f986fb4179e83bef83d0d61448cdb82cd216ec898b16aee789fc`。

下一步完成玩家/大型静态/紧凑效果的跨资产风格锁，再接入普通怪实际状态与血条布局。新开始页、六关独立Boss/地图/敌族/奖励循环以及全部动画替换仍是完整目标，不缩小为一个资源交付。
