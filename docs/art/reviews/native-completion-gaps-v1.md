# 原生重制收尾缺口：独立旧Boss与包内遗留

2026-10-12，5分钟超载。当前全量f4-current-full-v1仍运行，源码保持冻结。本轮只读完成审计得到两个需要实际修复的缺口；没有因此批准全部资源、重新导出、删除文件或缩小长期目标。

## 独立旧Boss攻击身体动画缺失

正式菜单仍能进入波次兼容模式，WaveDirector创建OverseerBoss。它绑定root_commander_paper_v1与NativeBossMotion，只有idle/walk/hit/entrance/death；Motion不读取攻击阶段。NativeLegacyBossIntegrationTest也明确接受五片段，所以当前测试全绿不能证明“全部Boss新攻击动画”完成。六关专属Boss的新动作不能替代这个实际入口。

待做：保持原创纸偶的23骨、物理锚点和镜头预算，为现有扫击、锁点砸击、三种弹幕、阶段增援制作独立可编辑动作库；身体姿态只读取现有权威时钟，不产生伤害、弹丸或奖励。既有HP/碰撞/速度/伤害/攻频不改，隐身/死亡/暂停/取消不能残留攻击姿态；六关自己的Motion保持独立。首轮真实资源/选择测试必须RED，不能只将原五片段要求放宽后签通过。随后实际Actor/自然时钟、GPU关键与连续帧、独立PCK和前序Boss回归。

这不是新增第7关，也不是先前全角色齐备门之前违规制作大型动作：资源门已经通过；五非攻击片段是在当时延期攻击策略下留下的明确债务。

## 六张无字面引用旧位图仍在保留PCK

重读先前native-retired-audio-pack-v1/game.pck，实际SHA仍为07964613f2db5463f23c57c9d70cc3e4e31d5adb636f2d836257201d9a52cbec，594条目录。除3张真实位图依赖外，enemy_bruiser/lobber/marksman/overseer/scrapper/spitter.png每张还有ctex/import两个条目。先前“13PNG+MP3退役”的窄结论仍正确，但不代表全部历史角色贴图已退出包。

生产scripts/scenes/native资源的字面路径扫描对这6张均为零，它们由all_resources纳入的可能性明确；字面零引用本身不能证明动态加载安全。待全量终态后逐文件精确排除，保留原件、历史manifest/预览/作者工具，不宽泛排除enemies目录；RED→实际包目录零匹配→完整原生演员/实际Main普通流程才可签收。当前尚未实施这些排除。

## 三张真实依赖不能盲删

| 文件 | PNG头尺寸 | 当前字面消费者 | 原来源状态 |
| --- | --- | --- | --- |
| combat_hit_chibi_b_v1.png | 128×128 | CombatVfx | imagegen / style-approved / license pending |
| mint_farm_floor_b_v1.png | 1254×1254 | FloorGrid（兼容模式） | imagegen / draft / license pending |
| mint_farm_props_b_packed_v1.png | 1088×1088 | ArenaObstacle（兼容模式） | imagegen / draft / license pending |

声明的提示词/源路径、实际PNG头、包内条目不能独立证明生成输入权利或许可。当前不将pending改approved，也不移除仍被预加载的文件。收尾采用确切来源核验或原创替代，并分别验证受击和地形观感；保持既定障碍/碰撞/伤害规则。

[机器快照](native-completion-gap-snapshot-v1.json)记录9张PNG的SHA/尺寸/字面消费者、旧包条目及Boss源SHA。扫描范围不是全引擎动态依赖；目录来自保留旧包并重核其SHA，不是当前重新导出。完整目标仍包含新关卡/所有动画/入口/最终当前源验证，不能用这份审计代签完成。
