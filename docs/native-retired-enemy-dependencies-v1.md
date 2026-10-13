# F4旧敌位图依赖精确退役

后续更新：在下述八张的基础上，另五张无消费位图与旧MP3已[精确退役并验证新包](audio/original-overdrive-cue-v1.md)。本文件604条目录/809检查是前一切片历史；最新包为594条/5507专项。尚留资源段中的scrapper、玩家和未打包道具目前也已退出，实际地面、packed道具和命中特效仍保留。

2026-10-12，“5分钟超载”。本次只退役确认已由原生角色替换的八张敌位图，不删除素材文件、不清理整个目录，也不改攻击/血量/碰撞/存档。

## 改动依据与边界

全scripts/scenes检索确认Enemy的DASHER/BRUISER/SPITTER/MARKSMAN/LOBBER/OVERSEER_TEXTURE及OverseerBoss的OVERSEER_TEXTURE七个常量只在声明出现，实际_ready均创建原生场景。移除这七条无消费preload；static_visual接口/高度/回退绘制仍保留，避免夹带不相关API重构。旧位图只供历史资源测试/作者预览，均保留。

export_presets精确新增六张`enemy_*_chibi_b_v1.png`及两张`enemy_dasher_[ab]_actions_runtime_v1.png`排除项。没有把整个enemy目录排除；现有shader、原生场景/动画以及其他有实际依赖的资源不变。

## 验证

新增发布策略用例：八个原件必须存在，必须逐文件排除，全部可导出GD不能再引用其res路径。首次RED实际8个语义失败（排除项缺失），不是解析失败；生产最小改动后Python策略10项全部通过，原有runtime preload不得被排除的检查也通过。

实际资源导入exit0。工作区EnemyNative40、NativeLegacyBoss50、EnemyStaticArt90、EnemyDasherArt15、ChibiRuntimeArt51、EnemyHealthBar84、BossCameraFraming1862、CombatFeedback48，八项共2240检查，actualexit0/唯一正PASS/无错误泄漏。保留历史文件的测试照常运行，未删除或绕过。

独立`retired-deps-pack-v1/game.pck`当前导出6,838,004字节，SHA256 `26a780538a1fac883dc34a30214df9a33a86fcfaeeddf055529730ec36e09e62`。从实际604条包目录读取（非仅依赖文本或导出日志），八个retired stem、*.import、*.ctex匹配为0；作者预览/测试/源素材目录匹配为0。读取规则依据[同版Godot PCK读取源](https://raw.githubusercontent.com/godotengine/godot/5b4e0cb0f/core/io/file_access_pack.cpp)，遇加密/未知版本会停止，不尝试解密。

在只有当前PCK与原测试SHA副本的独立目录、以--main-pack实际执行EnemyNative40、NativeLegacyBoss50、NativeCharacterRoster644、ChapterMapBackdrop75，共809检查，实际exit0/唯一正PASS/无错误泄漏。Roster包括普通/区域/Boss、实际Wave增援与分裂后代，衬底测试走六实际地图。1679记录源末SHA及PCK末SHA一致。没有跑实际Main入口/普通战斗或完整六关链，不能把本专项当最终候选验收。

canonical `docs/art/previews/campaign/retired-deps-v1/`17份逐SHA副本：独立包报告/导出/四测试日志6份，工作区八测试日志、导入、策略RED/GREEN11份；额外manifest不计入17份。PCK原件留在ignored build，不作为正式发布物。

独立只读五轴复核：无Critical/Required；复核者现场核对PCK哈希/大小、实际604目录、1679源SHA、四日志和fixture副本一致。Optional明确：Python只扫描可导出GD的完整路径字面量，不单独覆盖tscn/tres/UID/拼接加载；本次实际独立包与生产Roster补足现场范围，不能把该静态测试宣传为永久完整依赖闭包。复核未重新运行引擎，不冒称第二次独立执行。

## 尚留的资源

包内仍有旧scrapper、玩家图集/武器及mint_farm地面/道具导入项，MP3来源也尚未核清；本次明确没有宣称“所有旧资源已清除”或“全部许可已批准”。要继续区分实际兼容玩法依赖与all_resources无引用遗留，按同样的精确退役流程处理。F4其他文字/音频来源/密集性能/当前full及最终同源本地候选/六关链仍待验收；不做中间Git、完成邮件或公开发布。
