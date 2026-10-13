# F4六区地图边缘衬底

2026-10-12，分支“5分钟超载”。本切片只修地图外侧的未绘制区域，尚未代替真实Boss取景、最终整包或全目标验收。

## 为什么不夹紧镜头

BossCameraFraming为玩家全身、Boss与HUD保留空间，会合理地看见物理world_bounds之外；原Floor仅画边界内。夹紧摄像机或扩大碰撞地图都会改变已验证的取景/玩法，因此保留两者。ChapterMapBackdrop为六张实际地图安装低对比、全不透明CanvasLayer底色，以及Floor下方的闭合双边缘。沿用现有六区配色，不增加域外道路、危险符号、纹理依赖、碰撞或导航节点。停止process，不引入每帧背景逻辑。

## 失败证据也保留

- `f4_map_edges_red_v1`不是合格RED：裸地图SubViewport用了Godot默认灰色，亮度阈值误判通过。本主看图后发现；不能以它证明游戏中问题不存在。
- `f4_map_edges_red_v2`先启动实际Main取得游戏清屏色，再测六区×三分辨率×八条边/角，共144场景，实际exit1/144语义失败，无解析错误或泄漏。每例存在未绘制域外样本。
- 生产衬底接入后`f4_map_edges_green_v1`实际exit0/唯一PASS321，无错误/泄漏，144场景void_samples均为0。18张代表图；本主实际检查首/三/六关1280×720右下角，原地面和低对比闭合边缘保持可辨。
- `green_v2`仅校正观察器报告写入顺序（存档不写检查先于报告），同生产版实际exit0/唯一PASS321，无错误/泄漏，报告检查数与PASS一致。它不算第二次独立生产修复。
- 独立复核指出早期观察器仅隔离campaign，Main仍可能读取真实旧波次snapshot；没有写它，但不能声称完全独立。观察器随后在Main ready前隔离SnapshotStore，完善同名普通文件拒绝/报告打开失败清理；`f4_map_edges_isolated_v3`实际exit0/唯一PASS323，无错误/泄漏，同144例void=0。生产衬底不变。当前独立地图证据以v3为准。

以上日志和原图在`build/diagnostics/campaign-goal/`下各独立run目录，没有覆盖旧失败。观察器每次拒绝覆盖已有目录，使用专属空进度路径，核对实际map bounds、seed障碍描述与Collider数量不变。实际玩家/Boss不在此观察器中，因此不能从地图测试声称演员/HUD/入场/转阶段/返回全部通过。

`docs/art/previews/campaign/map-backdrop-v1/`已保留24份逐SHA匹配副本：当前v2的18图/报告/日志、合格语义RED报告/日志、明确不合格的false-GREEN报告/日志。sha256-manifest记录原始路径与副本哈希；额外manifest不计入24份。失败原图仍留在独立build目录，未冒称全部都复制进canonical。

v3另存`isolated-v3/`20份逐SHA副本（18图/报告/日志）及独立manifest，旧24份不覆盖。

## 地形回归

正式ChapterMapBackdropTest注册到run_tests：六实际地图的全屏覆盖、透明度/区域色、底层顺序、不截输入、无Collider/处理、重复安装与同seed再生成检查，实际75通过。Nursery4471、Foundry4302、Salt59、Archive103、Echo128、Rift58同版严格通过；七项共9196检查，实际exit0/唯一正PASS/无错误泄漏。不是当前完整full，也不是碰撞运动和真实Boss验收的替代。

## 真实Chapter背景/生命周期验收

`VerifyChapterBossEdges`由独立验收作者编写，主端全文审查与运行。首轮v1仅rig_id动态属性类型推断解析失败，保留原日志，不算语义RED。主端显式int后v2实际exit0/唯一PASS1036，无错误/泄漏；三分辨率×真实首/六关，共6fixture/162截图。144健康阶段边角每例至少336个未被HUD/演员遮住的真实域外像素，clear_color_hits全部0。真实Main按钮信号→两遭遇真实敌受控damage/真实奖励交易→supply/finale→自然Boss入口→真实血量phase→受控死亡/实际保存→Return→旧Chapter/rig释放。campaign与wave snapshot均在专属证据目录，不触碰真实存档。第六关1–5 prerequisites显式Progress API fixture，不是五次普通胜利。

1678源银行在引擎终态后逐SHA匹配；随后只修改MapEdges观察器，该历史银行不冒称最后整源。162原图保留build；canonical `boss-backdrop-v1/`33份逐SHA副本包括六fixture各入场/phase3edge7/clear/returned图共24、六campaign收据、报告/日志、首轮解析失败日志，另有manifest。主端实看首/六关960×540 phase3edge7、第六1280×720 phase3edge7和返回Main。960部分Boss有方向提示/遮挡，不签完整演员取景；1280所查看例全身清晰、地形边缘闭合，返回图实际显示六区菜单。受控damage产生的即时hit flash不当作平时材质或持续透明度证据。

演员冻结/受控位置与take_damage只用于背景复现，不冒称普通输入通关、动态攻击动画阶段、密集性能或人工体验。原生绘制manifest保持draft，标准PNG manifest校验器不适用，不伪造PNG或许可审批。F4文字/音效确切来源、旧图集包依赖、密集性能、最终当前源full/独立本地候选/新同源六关链仍待完成。不做中间提交、推送、完成邮件或公开发布。
