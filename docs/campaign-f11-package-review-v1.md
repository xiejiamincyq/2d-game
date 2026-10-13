# F11 Boss公平性候选包（2026-10-12）

这是本轮同源导出与验包记录，不代表完整回归、真人操作、长期Goal或公开发布。旧F9/F10不是当前Boss公平性版本。

## 真实发行入口

`build/playtest/native-campaign-f11-boss-fairness-v1/five-minute-overdrive.exe` 与同目录PCK实际导出成功，真实发行EXE运行Main300帧后actualexit0，无错误/泄漏。持有Process.Handle并WaitForExit取得真实退出码，不用GUI启动命令的空LASTEXITCODE猜测。EXE SHA `b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0`；PCK SHA `b812ea8b0c7bc1b39332672ab3c0b66f1f51251f55f56b90d649211997cb58c6`，4630868字节。引擎壳与旧版相同，游戏变化在PCK，不能混配。

## 隔离PCK验证

没有workspace `--path`，由已配置引擎加载该PCK和逐SHA相同的canonical夹具。未修改发行EXE禁止外置脚本的保护。

- v1：BossEscapeGate8、BossWarningHitch111、BossReleasePreview20、VineSeedCancellation25、VineRootReentry34、NurserySupplyPolicy56，各实际exit0/唯一PASS/无错误。随后NurserySupplyRuntime缺少相对基础夹具，actualexit1；该失败保留，不称v1全部通过。
- v2：复制未改字节的NurseryChapterTest/TestSupport依赖，仅执行未完成的6项：NurserySupplyRuntime18、VineRootFairness14、FoundryHeatField4424、FoundryEncounter614、CampaignMenuMotion303、CampaignPrimaryEntry62，各实际exit0/唯一PASS/无错误。前6项不重复计数；共12项5689检查实际通过同一SHA包。
- 同包GPU `VerifyNativePlayerRuntimePack` 实际exit0/12检查：Main到首关、原生Player、自然入场、普通引擎输入移动/射击、返回菜单。真实鼠标输入/真人手感未因此验收。

## 实际目录而非导出配置推测

按[Godot4.7读取实现](https://raw.githubusercontent.com/godotengine/godot/4.7/core/io/file_access_pack.cpp)读取v4实际目录，591条，flags2为相对filebase；目录/各条目范围合法，作者工具、测试、docs、tasks、外部图像/ctex/音频/字体匹配0。当前23个敌/Boss消费者加Player，共24身体/27库的实际remap均存在。目录总数为33身体/36动作库，含此前原生版本；24/27是当前消费者依赖，不是声称目录总数。

最初只读解析误要求flags0、以及带res前缀/把总数要求为24/27的校验各失败；修正读取规则后确认实际依赖。它们是检查器假设错误，不是导出丢资源，也不隐去失败记录。

22张受控警示/主动图另见[本轮GPU银行](art/previews/campaign/boss-fairness-v2/report.json)。当前全量和真实六关链仍待终态，未提交推送。
