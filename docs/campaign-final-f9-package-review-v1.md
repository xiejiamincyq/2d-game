# F9当前独立包与本机候选

限定验收：不代表整个Goal、Windows鼠标、真人试玩或公开发行。没有提交/推送/发布。

当前包 `build/diagnostics/campaign-goal/f9-final-native-pack-v1/game.pck`：4613072字节，SHA `fadb72a55170976544c1ed3b2887eb3be6c266043cc59e04ac8e7453375838c7`。21份规范夹具7075检查，每项实际退出0、唯一正PASS、无错误/泄漏；Main120退出0。1761条源/证据登记前后SHA无漂移。新菜单行为303项在独立PCK中真正执行，不把源码运行冒称验包。

与F8断言总数不硬凑：新增菜单303项，但ArenaRuntimeTest这次55项、旧包64项。该测试每个随机障碍执行3个断言，障碍数量不同使总数变9；本次55真实通过，不伪造旧次数或重复跑直到旧数出现。

实际读取PCK4目录：589项、作者路径/外部PNG/SVG/ctex/音频/字体匹配0；24当前身体/27库remap齐备、新CampaignAnimatedBackdrop.gd依赖在。头部/目录/条目范围检查按[Godot4.7官方读取实现](https://raw.githubusercontent.com/godotengine/godot/4.7/core/io/file_access_pack.cpp)执行，不靠exclude文本或导出日志推断内容。

原canonical `VerifyNativePlayerRuntimePack.gd`逐SHA复制到隔离目录，由配置引擎加载同PCK且不带workspace路径。实际Main→首章、自然入场、普通移动射击→返回，12检查/126原生GPU录制帧实际退出0；6采样SHA核对，5种不同图像实看（frame20与60字节相同），面板暗化属于modal覆盖，不是身体半透明。UI进入/返回使用受控信号，不是OS；固定60fps录制不当作性能测量。

当前本机候选 `build/playtest/native-campaign-f9-v1/five-minute-overdrive.exe`真实导出、Main120退出0；同目录PCK与上述独立包完全同SHA。EXE SHA `b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0`与F8相同是正常的独立引擎壳，新内容在外置PCK，不能混配。旧候选均保留。

三尺寸实际Main入口252检查/15截图已查看，真实保存前后相同，见[原始证据](art/reviews/f9-primary-entry-evidence-v1/report.json)。当前1732 canonical+2 themes+3 helper冻结；全量348/330557及37Python285、新档六链、真实第六风险和两份恢复均已实际退出0，同包章专项145+23也通过，合计23夹具7243。见[终态与边界](campaign-final-f9-terminal-review-v1.md)。桌面输入仍受锁屏阻断，不能宣告整Goal完成。
