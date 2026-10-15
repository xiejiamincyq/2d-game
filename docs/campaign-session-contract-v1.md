# 公共旅程会话契约

六关唯一会话，旧CampaignProgress文件只读迁移。新Journey是金币、能力、通关序号的唯一写入档，永久解锁由其前六次通关派生，不做两文件双写。已有旧永久解锁但无Journey时，迁移已有通关序号，不赠送过去能力，不删除/覆盖旧档。未知版本、损坏/恢复状态仍明确阻止开局，不静默降级。

## 待领取通关与关闭恢复

真实Director接受Boss健康归零后，先原子保存pending_clear，包含本轮/章节、实际金币余额和已获得卡等级。仍未发出新继承等级，导航禁用；下拉选择后一次原子提交继承等级+通关序号，才显示保存成功并允许导航。没有可选普通卡时自动提交空奖励。重玩已领取章节只保存余额，不再次领取。

pending存档允许关掉窗口后继续领取上次真实通关奖励，不必再次打Boss；不能当作新Boss战证据。待领取时余额冻结，不能用别的关卡覆盖该奖励。pending字段可选以读取本轮尚未发布的四字段Journey v1候选；序号/金币/卡片/前置严格验证，未来版本仍拒绝。

## API与验证顺序

- `CampaignJourney.begin_pending_clear(loop, chapter, balance, earned_counts) -> bool`：只有下一未领取章节可登记，失败不变。
- `get_pending_clear() -> Dictionary`：隔离副本。`finalize_pending_clear(choice) -> bool`：已获得普通卡或无选项空领取；重复不能再发。
- `CampaignSession.load() -> bool`：只读旧解锁+新旅程、检测异常，建立保存CAS基线。入口轮次/章号由旅程计算，pending优先。
- `record_defeat(...) -> bool`：生产协调器先核验Director真实cleared/defeated_boss_instance；会话负责候选保存，成功才替换活模型。
- `claim_pending(choice) -> bool`：写入失败不替换已提交模型，可重试同一选项。
- `checkpoint_coins(balance) -> bool`：余额实际覆盖而非相加；pending不能被无关活动改钱。

先纯pending RED→GREEN，再隔离磁盘会话/迁移/失败，最后六关真实Actor/结算/帐篷/重玩/新进程。损坏档保留，不删除用户存档；仅测试唯一目录中的夹具可清理。保存实现支持单游戏进程串行写入，不宣称跨进程锁。

## 提交与故障边界

“原子提交”指金币、继承卡、通关序号及待领奖励在同一个已验证状态文件中一起生效，不是两档部分成功；不是任意断电点自动恢复承诺。磁盘提交会写入并验证tmp，再将主档移至备份、提升tmp。两次重命名之间进程被中断，可能留下主档缺失但备份存在的RECOVERED状态；CampaignSession明确拒绝开局，不把备份或未知tmp自动提升覆盖原文件。

正常退出及再次启动已用三个独立Godot进程验证：准备待领奖励、读取并领取普通能力、再次读取核对只发一次。该验证不涵盖随机杀进程/磁盘断电/跨进程同时写入。当前同进程重试只接受该Store实例刚准备且SHA未变化的tmp，未知或被替换的tmp一律保留并拒绝写入。
