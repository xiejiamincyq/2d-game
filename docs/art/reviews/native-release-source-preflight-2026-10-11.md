# 原生重制的包内来源预审（只读事实）

2026-10-11，R1全量回归仍在运行；未改变冻结运行代码/导出规则，也未批准许可或发布。当前独立PCK57专项/60475断言已实际退出0，包SHA256 `7ac1105013a7761605d256259dd99011cacc29cabe7cb8c8fde91bd465cf72c4`，6829008字节。下列由该实际PCK目录586条目与工作区源读取，不是由“未引用”推断没有随包资源。

- 当前实际包不含player_m2_*或player_turnaround命名的目录条目；与既有精确排除M2的规则一致，但不能由此宣称排除了所有历史图像。
- 当前包仍含旧`enemy_dasher_a_actions_runtime_v1`及`enemy_dasher_b_actions_runtime_v1`的各*.ctex和*.png.import，共四项。当前Enemy._ready对DASHER创建NATIVE_DASHER/cinder_runner_paper_v2，而非旧图集；全scripts/scenes文本搜索未找到这两个旧动作图集名。当前export_presets的精确排除只列enemy_dasher_a.png与enemy_dasher_b.png，没有排除旧runtime图集。因而“制作了新骨骼”不代表“包内旧动作已经替换完毕”。F4应在先RED/完整依赖核验后精确排除这两张无生产引用的旧动作图集，保留历史源文件，不删素材、不宽泛排除整个enemy目录。直接运行/动态拼名依赖仍需最终独立包验证，不能仅凭本次搜索签通过。
- 旧chibi静态敌人纹理仍被Enemy常量preload，属于真正代码依赖，不能在未去除依赖时一起排除。它们不等于当前实际原生动画，但最终“无旧资源依赖”声明必须区分运行引用与包内遗留。是否撤除这些静态兼容资源在F4分片实做并验证，不在地图回归期间夹带清理。
- 运行仍预加载`assets/audio/overdrive_bone_breaking.mp3`，44347字节/SHA256 `cdeae6778c84761b7a0d634c5036c3366b997f5351ef055f007e45b80592e5ef`与已有来源记录一致。它在当前包有import条目，不能因为没有裸MP3条目就宣称未随包。用户曾提供候选作品页但未确认对应，确切下载链仍unknown；不改变[既有审查](../../audio/overdrive-bone-breaking-source-v1.md)的needs_review，不根据同作者/同名自动批准。其他AudioManager音色由原代码合成；F4可根据最终范围继续核验或制作原创替代，未在本轮实施音效替换。
- 实际PCK没有*.ttf/*.otf/*.ttc字体文件名条目；MintFarmTheme声明SystemFont和本机字体候选，而非随包字体二进制，主题SHA256 `193b66171b7f4e8f7b341d2058082f7c867fa576b9485c35b1ac1f5cbd5e7f63`。这是当前打包事实，不是对任何字体许可的法律结论，跨机器中文可读性仍需最终运行验收。

完整只读目录结果记录在ignored `build/diagnostics/campaign-goal/rift-map-package-inventory-v1.json`。来源审查是整体目标的独立最终门，不把程序化原创角色、页上免费声明、技术GREEN或本机能播放当成全部资产可发行的证据。不联系作者、下载新音频、安装字体、提取本机字体、购买资源、改真实存档或公开发布。
