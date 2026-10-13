# 独立监工：实际攻击时钟接入

2026-10-12，5分钟超载。接续[资源审查](legacy-overseer-actions-resource-review-v1.md)与[实施契约](legacy-overseer-actions-contract-v1.md)。本次已接入实际兼容 Actor，不再只是资源；整个长期目标仍未完成，最终全量/独立候选/新六关链仍待所有生产收尾之后执行。

## 改动与边界

`OverseerBoss` 实际选择独立 `root_overseer_paper_v1` 23骨/21片段和 `NativeOverseerMotion`。原 `NativeBossMotion`、六关子类及冻结基础场景/库保持不变。新适配器只读取触手 kind/stage/elapsed、弹幕的只读真实计划快照、Director真实转阶段时间；不推进攻击时钟或生成战斗事件。

触手成功结束先保存攻击身份、重置状态，再发完成通知；取消单独通知，连已完成的视觉尾段也清掉，不把 idle 猜成成功出手。砸地仍在同一次物理调用中结算结束，完成后0.14秒身体冲击和0.34秒收势纯属视觉，绝不扩大伤害窗口。横扫主动0.22秒取真实 elapsed；弹幕warning/attack按本次种子计划首发/末发时刻映射，末发后身体收势不删除飞行弹丸。原 `cancel(false)` 保留飞弹语义不变。

新攻击、取消、隐身、转阶段、死亡令旧尾段失效。用户暂停通过原PAUSABLE树冻结，恢复继续；不加ALWAYS时钟。攻击/转阶段中的伤害保留0.35皮肤闪光，但不打断成hit或结束后延迟补播hit。非攻击受击/步行/待机/登场/脱离碰撞死亡仍走原基类。兼容先add Actor再setup的原调用顺序保留。

HP10800、物理半径56、移速63.8、所有伤害、预警时长、攻击间隔、计划/弹数上限、转阶段增援、导航与碰撞未修改。`TentacleAttack`与`BossProjectilePattern`只添加观察接口；六关战斗系统不借此更换动作适配器。

## 验证

- 新实际Actor测试真实RED退出1：未使用独立场景、缺观察接口。实现后最初82、补新攻击替换/弹幕通知语义后95检查均实际退出0/唯一PASS/无错误或泄漏。[最新测试](previews/campaign/legacy-overseer-actor-v1/f5-LegacyOverseerMotionIntegrationTest-v3.log)。覆盖五攻击实际阶段、采样不发弹/不改时钟、瞬时砸地、完成身份/先重置/幂等、警告与已结束尾段取消、保留飞弹、新攻击替换、真树暂停、隐藏、真实HP转阶段与死亡。
- 现有专项实际退出0：Legacy51、Tentacle79、Pattern265、ChibiRuntime51、Roster693、VineGuard43；Director38、RuntimeClock9、Readability244、CameraFraming1862、冻结RootCommander112；六关Boss对应专项28/31/53/13/15/23、RigCheckpoint44、ArtValidator36。UID策略3项通过。不是当前全量通过。
- `BossTest`第一轮因旧五片段场景名称断言而退出1；只将实际场景预期改成独立监工场景后31检查退出0，[失败历史](previews/campaign/legacy-overseer-actor-v1/f5-BossTest-v3.log)保留。历史RootCommander资源测试继续检查原v1，不删旧断言掩盖新资源差异。
- 新GPU诊断 `RenderLegacyOverseerActions` 实际退出0/无错误泄漏，3888检查、252关键姿态（21×3时刻×左右×无闪/0.35闪）、16动作阶段×左右×30共960连续帧。每组29次相邻像素变化，关键与**全部连续活体采样**partial-alpha、边裁、镜像视觉范围外像素均0。死亡允许原有视觉范围偏移，不计活体取景。[报告](previews/campaign/legacy-overseer-actor-v1/report.json)。六张动作组图均实际查看，哑光不透明，出手/收势可见，保持纸偶比例。
- GPU使用实际Actor及真实controller的显式时钟夹具；只测身体，刻意隐藏地面预警、飞弹、目标和状态标记以隔离像素。它不是完整攻击效果、自然输入、Main UI、正常通关或性能证据，也不证明所有未采样时刻。
- GPU开始/结束的固定根源银行1706项由 canonical `CampaignChainEvidence`构建，结束后独立SHA再核对0差异，包含本次实际Actor/适配器/控制器/测试资源。它是该固定范围的版本绑定，不是全部外部资源权利清单。随后仅新增测试覆盖、BossTest场景预期和六PNG导出策略，故不再将该银行冒称最终当前全源；最终冻结后集中重做整门。
- 20份原始GPU/首轮测试证据与18份追加专项/策略日志，共38份复制SHA逐项一致，[清单](previews/campaign/legacy-overseer-actor-v1/copy-manifest.json)。冻结基础场景SHA仍 `6c48a483e32445741aa7916d2159b9ffe64db161730f2c68d724ab5ad15f64ac`、基础库 `331c8b3d37f892107550ed032a4af6541d7c973ab72f696a39fae4e084bf2cfd`。

manifest仍draft，不将局部夹具当整个游戏签收。不提交/推送中间切片，不发完成邮件，不公开发布。

独立只读五轴复审未发现Critical/Required，确认瞬时slam/完成先重置/取消/暂停/飞弹保留、生产边界及GPU/最新专项范围。Optional提醒GPU后测试断言也改变、不能宣称完整银行仍当前；上文已明确记录这一点。复审未运行引擎、写文件或操作Git。

## 六张旧基础位图：只完成精确策略

既有[快照](reviews/native-completion-gap-snapshot-v1.json)对enemy_bruiser/lobber/marksman/overseer/scrapper/spitter.png在生产脚本/场景/native资源查无字面消费；旧594项PCK仍有每张ctex/import。已在导出预设逐文件精确排除，保留六个源文件和历史许可/预览。不是删除目录或批准历史素材。

策略真实RED11套/6失败→GREEN11套，全套退出0；扫描扩大到生产scripts/scenes/native文本，继续保证所有实际preload不被排除。未为配置小切片导出新的PCK，因此**最终包内零条目尚待最终候选核验**。三张真实pending位图仍在使用，未盲目排除，下一必须原创重绘受击星芒、低对比地面与四类障碍后再精确退役。
