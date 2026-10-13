# 原生纸偶地面与四类障碍

2026-10-12，5分钟超载。接续[命中纸星](native-impact-original-review-v1.md)，将最后两张实际pending位图消费者FloorGrid/ArenaObstacle改为项目原创原生绘图。三张原pending位图均不再是实际生产消费；旧文件、历史预览/manifest/许可pending状态全部保留，未假批原作品来源。

## 实际改动

兼容波次地面采用原创 `paper_arena_floor_v1` shader：世界坐标锚定的低对比哑光方板，无纹理/noise输入；FloorGrid仍绝对z-100、±4096覆盖范围、一次绘图、原900命令上限。六关各自的原生地区地面未被这个兼容地面替代。

独立 `ArenaPaperPropArt` 原创四类装饰：粗叶木花床、闭门温室、表盘罐体、厚管与夹箍。无Sprite/atlas或老alpha shader，按实际占地原生绘制；新资源不覆写任何旧已批准文件。碰撞仍以原世界矩形/前接触边排序，查询层/组/导航接口不改。

**有意升级遮挡**：只Art装饰平滑淡至0.32，root/plinth保持1.0；可碰撞占地始终明确，玩家自己不调alpha。触发仍使用玩家84px视觉覆盖、在障碍后方和实际新decor边界，而非旧atlas宽高比。视觉边界变化不移动碰撞；不宣称原遮挡表现完全不变。[原生source manifest](style-manifests/arena_paper_environment_v1.json)仅局部style-approved，不是全部地图或最终游戏签收。

沿用已批准的原创纸偶语言，使用代码/shader而非新位图生成，未下载付费资源或安装工具。旧PNG专用manifest验证器不适用于代码资产，不伪造源图尺寸或修改旧验证门。新版原生环境专项检查源契约及四角色/无位图标记。

## 验证

- 实际旧消费者语义RED退出1→新专项135，加入原生manifest检查后**136检查**实际退出0/唯一PASS/无错误泄漏。首轮新prop的x类型推断错误与由此产生的导入/调用失败保留，不计通过；明确float后正常导入无错误，缺Art分支改为明确失败清理，不能出现无PASS却被当通过。
- ArenaRuntime55、ArenaMap9198、Performance30、EnemyFlock33、PlayerDashWallContact625均实际退出0/唯一PASS/无错误泄漏。Runtime旧Sprite与整体fade断言更新为实际原生Art/solid root，不删碰撞、生成、导航、波次和保存断言。Runtime使用本进程新campaign/snapshot路径，不删除用户或共享headless存档；Main ready可能只读默认继续档，因此不宣称完全不访问用户档。
- Native专项覆盖四类角色×0.5/1/2尺寸的实际圆形CharacterBody.move_and_collide；原ColliderRect、layer、mask、真实生成描述一致。对照前一个捕获银行，ArenaLayout/TerrainSweep/Player三个生产源SHA完全未改，验证不是通过改地图或角色移动“让美术过关”。
- 最新GPU实际退出0/唯一正PASS/无错误泄漏，**147检查**（真实随机障碍数影响检查总数）：36障碍状态样本，opaque范围外/边裁0；占地**内缩8px内部**所有采样alpha1，不声称圆角/抗锯齿边缘每像素不透明。装饰0.32且root1，恢复后回1。[报告](previews/campaign/native-arena-original-v1/report.json)。
- 3个实际camera位置（0/负2200,1600/正2200,1600）地面网格抽样无黑/透明，亮度0.47345–0.51238，仍一绘图命令。这不是全域每像素或GPU帧率证明。真实Main兼容开局960/1280、自然随机种子与实际玩家登场通过，保存写入本次新evidence目录；不注入战斗成长/伤害。
- 补充真实Player站在温室后方、且在真实碰撞箱膨胀范围外的[遮挡前](previews/campaign/native-arena-original-v1/behind_opaque.png)/[装饰淡出后](previews/campaign/native-arena-original-v1/behind_yield.png)图已实际查看；player/root均alpha1，Art0.32。上层装饰让出玩家轮廓，实心底座保持；是一个受控位置，不是全障碍/全朝向/普通输入运动证明。
- [四角色图](previews/campaign/native-arena-original-v1/props.png)、[低对比地面](previews/campaign/native-arena-original-v1/floor.png)、实际兼容Main两窗口图均实际查看，未把早期开局截图当胜利或完整地图探索。
- GPU开始/结束canonical固定根源银行1720项相同，结束后独立重算0差异；之后新增manifest断言和两个PNG精确排除，故该银行不是最终当前全源银行。[25份复制证据](previews/campaign/native-arena-original-v1/copy-manifest.json)逐文件SHA一致（含仅本次夹具写出的snapshot，不是用户档）。
- 独立只读五轴复审未发现Critical/Required，确认绘图/物理边界、保存路径及范围。Optional内部8px/圆角限制已记录，随后补真实behind-player图；不把单draw/caps专项冒称完整性能。不操作Git/引擎或写文件的审查不能替代实际运行证据。

## 导出与最终门

最后floor/packed props两PNG精确策略RED11套/2失败→GREEN11套，生产脚本/场景/native文本无消费，实际preload保持导出。只排除确切两个文件，不删环境目录或历史文件。与先前六basePNG、命中PNG退役一起，**实际最终PCK目录还未核验**；下一集中全量与独立候选，不重复小切片导出。

资源生产收尾完成后冻结完整当前源，跑当前全量、真实独立本地候选/PCK、最终目录/许可与新同源六关链，按实际结果修复，不缩小目标。整个Goal仍active，未提交/推送、发完成邮件或公开发布。
