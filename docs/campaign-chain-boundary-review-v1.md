# 连续六关证据边界实施记录

2026-10-12。goal active；分支5分钟超载；本文件只记录实施边界，六关实际结果另见[阶段验收](campaign-fresh-chain-acceptance-v1.md)。不公开发布，不提交未完成整体目标。

## 为什么单独建设这层

原各关自动试玩会在隔离存档写入前关夹具，证明单关可玩，但不能证明新玩家连续解锁。新模式为显式最后参数`chain=FRESH`或`chain=<父证据ID>`。默认旧模式仍原样运行；不为已有历史结果改名或补写证据。

首关准备必须没有存档或临时/备份文件且不写入任何进度。后关只接受固定build证据目录中上关实际报告、存档、唯一正PASS日志和实际0退出账本；真实Progress严格读取、独立进程、普通移动/射击/击杀、真实Boss终态、返回Main、完整同源银行均检查。只复制已核对的原始存档字节，不调用`record_boss_defeat`补齐。

正式Store会在第二关以后的实际新提交中保留上一档`.bak`：必须正好是继承来的存档SHA和前置状态。拒绝未完成`.tmp`与异常备份，不通过删除备份来规避检查。JSON数组数值类型与真实类型数组不同；通过真实Progress严格验证并归一化后比较，不能放宽格式规则。

胜利后先记录实际Boss实例、计数和保存状态，再普通点击Return，等待真正Main，不再读取已释放Chapter。核对真实存档恢复、默认主入口、菜单模型，拍`returned_main.png`并正常排空音频退出。每关新进程；第三方库、真实用户存档、玩家/敌人数值和奖励系统均未修改。

串行启动器只在实际退出后写生成账本，独立Python检查当前源SHA、普通通关元数据、真实存档/备份/返回截图SHA和父链。任一失败保留现场并停止本条链。改代码必须从新ID空档重跑，禁止跨源码拼接前后半链。

## 实际验证

- `CampaignChainEvidenceTest-chain-ready-v1.log`：197。
- `CampaignChainFileTest-chain-ready-v1.log`：66。
- `CampaignChainFlowTest-chain-ready-v1.log`：16。
- `CampaignFlowCompletionTest-chain-ready-v1.log`：37。
- `NativeChapterPilotThreatTest-chain-ready-v1.log`：8。
- `CampaignPrimaryEntryTest-chain-ready-v1.log`：62。

上述日志均在`build/diagnostics/campaign-goal/`，实际0、唯一正PASS、无脚本/测试错误或泄漏，共386项。它们是契约/受控集成测试，不是六场普通获胜。

`chain-report-validator-green-v1.log`：Python5测试真实通过，覆盖六章元数据、退出/错误/重复PASS、错误计数、虚假前置、同进程与不完整Boss终态、错误源/SHA/下一入口及输入不变。合成单元报告不记录实际获胜。两个PowerShell脚本语法解析通过；`chain-uid-import-v1.log`实际正常导入0且无错误，新GD/UID实际存在。

保留语义RED、异常类型误报PASS、继承常量重名、合法备份被拒及JSON数组直接比较失败的原日志；成功只认最新完整退出，不覆盖失败现场。

## 审查范围

正确性：旧独立路线和末关无第7关规则未删除；新链只能读取真实保存链。第一关导航补足现有可见藤鞭/根刺/种子弹，预警响应延迟0.15秒；没有为了通过而减伤或补血。

架构：证据边界留在作者工具层，生产菜单/保存/战斗无需为这条链增设测试通道。导出仍排除作者和测试。完整源银行只遍历固定项目源码/原生资源根及指定启动器、检查器、项目配置/音效，不读取密钥或用户目录。完整哈希不在战斗热循环中计算。

F2d后来已真实从空档串行1→6通过，详见独立阶段验收。尚未签收：F3多种子/构筑/重玩；F4地图外黑边、通关暂停死亡表现、说明/性能/许可；全部当前源full和同源本地候选。旧R4/R5 full不是新F2代码的全量验证，自动驾驶也不是真人手感结论。

只读预审另确认正式关卡最多三结算、终极进化仍要求旧第4波，属于自然不可达的规则缺陷；待F2冻结运行终态后按`tasks/campaign-build-balance-plan-v1.md`修复，不在本链后台给进化或金币。真实首关Boss截图也确认地图黑边，见`tasks/campaign-final-visual-plan-v1.md`。
