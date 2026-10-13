# 原创原生命中纸星

2026-10-12，5分钟超载，接续[实际监工与旧资源收尾](legacy-overseer-actions-integration-review-v1.md)。旧CombatVfx实际依赖来源pending的combat_hit_chibi_b_v1.png，本片将消费者改为独立项目原创原生绘图；不是批准旧PNG许可，也不改变整个长期目标。

## 实际改动

`PaperImpactArt`用八个顶点绘制四尖奶油纸星和1.5px青绿细轮廓，没有贴图、采样、烟雾、光晕或每次命中的独立节点。顶点半径为record.size×1.3，强度2时16.9px；描边与抗锯齿边缘不计入顶点半径。方向来自原有黄金角visual phase，不新增随机数调用。

`CombatVfx`的生产引用HIT_TEXTURE换为HIT_ART，私有记录textured更名burst，局部常量也改为burst命名；生命/速度/更新/火力事实不变。重叠48px区域仍最多三朵完整星芒，其余短划线保留，全局spark96、debris48、ring16、afterimage24。BLAST八条射线仍不消耗局部完整星芒预算。z绝对-1，人物身体、头顶提示与物理不跟随效果淡出。原角色局部HitFeedback未改。

沿用已批准的原创纸偶语言，本次非新位图风格生成，不调用imagegen或下载素材。旧PNG专用manifest验证器要求PNG尺寸/路径，不能用于代码资源；不伪造1024px“源图”或削弱旧验证器。新[原生源manifest](style-manifests/paper_impact_native_v1.json)由专项检查实际源/消费者/原创标记/无位图依赖。保持旧素材文件、历史预览、原style-approved/pending许可记录。

## 证据与范围

- 首次新测试有脚本class/static接口解析失败，不是语义RED；修正检查脚本后第二次真正RED退出1，明确实际仍依赖旧位图。实现后135，补原生manifest断言后**136检查**实际退出0/唯一PASS/无错误泄漏。[最新专项](previews/campaign/native-impact-v1/f6-native-impact-green-v2.log)。验证有界顶点、真实消费者、局部/全局预算、零子节点、时间/过期和分层。
- CombatFeedback49、FriendlyLayer33、FriendlyPalette5、ChibiRuntime51均实际退出0/唯一PASS/无错误泄漏。Chibi首次旧PNG断言改为Script时发生属性解析失败，记录保留；用明确Script实例后51通过。正常导入退出0；三脚本UID由正常导入生成，UID策略3项通过。
- GPUv1脚本误把玩家四方向NativePlayerView当作敌人的单一player控制器，发生接口错误；虽然引擎最终quit-after退出0，**没有PASS，仍失败**，不计验收。v2修正真实接口，使用透明基线提取不透明角色像素mask，避免把半透明地面接触影误报为角色被擦除；v3增加真实ScrapperAttack.begin的感叹号覆盖检查。
- 最新GPUv3实际退出0/唯一正PASS/无错误泄漏，37检查、12个强度/时刻隔离采样，逐样本边裁/80×80安全区域外像素0，超过实际生命后像素0。[报告](previews/campaign/native-impact-v1/report.json)。这些是故意淡出的特效，不把其partial alpha算作人物身体半透明，也不声称覆盖所有方向/时刻。
- 实际玩家、小怪、独立监工各自2468/1995/11357个可见不透明采样像素，在20次重叠命中/爆炸组合前后零改变。实际小怪预警96个不透明像素，刻意叠20次友方命中后零改变。只证明这些控制夹具、当前层级和可见不透明像素，不是所有半透明边缘/所有特效/所有敌方警告或完整自然战斗证明。
- [隔离图](previews/campaign/native-impact-v1/isolated.png)与[组合图](previews/campaign/native-impact-v1/actors-impact.png)实际查看：尺寸紧凑，画面中角色不被大片爆闪涂白，刻意预警覆盖仍可读。仍需最终普通流程/密集性能/真人手感分别验收。
- GPU开始/结束canonical固定根源银行1712项与捕获结束后独立SHA核验一致；随后只改导出精确排除与manifest说明，不冒称该银行是最终当前全源。最终冻结后的全量/独立PCK/新六关链不省略。[20份复制证据](previews/campaign/native-impact-v1/copy-manifest.json)逐文件SHA一致。
- 独立只读五轴复审未发现Critical/Required，确认绘图/玩法隔离、burst改名闭包、原预算与证据范围。Optional顶点半径不包含轮廓边缘已写入manifest；复审未运行引擎、写文件或操作Git。

这是本次局部视觉风格签收，manifest为style-approved，不是全特效gameplay/final批准。无外部图像输入或依赖安装。未碰用户默认Campaign/Snapshot保存文件，没有中间提交/推送、邮件或公开发布。

## 退役与下一步

旧combat_hit PNG精确排除测试RED11套/1失败→GREEN11套，源文件保留，生产脚本/场景/native文本无消费且实际preload仍允许导出。**尚未新导出，因此包内零条目还未证实**；它会随最终候选一起查。

还剩两个真实pending位图消费者：FloorGrid地面、ArenaObstacle四类障碍。下一制作原创原生地面和道具（平面低对比、碰撞足迹清楚）；保留地图种子/导航/碰撞/遮挡规则，不将当前旧PNG的pending改成approved。两处完成后才冻结最终源、全量回归、独立本地候选与新同源六关链。
