# 雾苔苗圃首关实际入口与通关闭环审查

2026-10-09，M2.2c 工程检查点。目标仍 active；这不是全新玩家/六 Boss 骨骼齐备或六关完成。历史检查点的“尚未接 Main”由本次结果取代。

## 实际入口与职责

真实 Main → 六区档案 → 第1关 → 独立 `nursery_chapter.tscn`。新协调器 `NurseryChapter` 复用真实 Player、UpgradeSystem、战斗反馈和已有演员，使用独立雾苔地图与 NurseryEncounterDirector；不把旧试玩六波改名为六章节。章节专用 UI 继承 GameUI 保留构筑/HUD，采用已锁定原创纸面主题，使用新遭遇、岔路、首领、暂停和通关文案。继续/返回键鼠可达，返回结束本局并保留永久解锁与音量偏好；重玩生成新地图种子。

内容就绪与永久解锁分离：Main 就绪列表为 `[1]`。通关后 2 永久解锁，但其内容未制作，仍不可进入；3–6 仍锁定。旧试玩与旧局内快照保留，不拿快照章节/波次数值开锁。

`save_clear(chapter) -> bool` 仅接受本章节调度器已确认的真实 Boss 死亡、CLEARED 状态及合法章节1。先克隆永久状态并保存，再更新内存和通关 UI；文件失败保留原进度、显示失败/重试，不伪装永久解锁。章节重玩保存幂等。Main 与章节仅允许 MISSING/LOADED 存档启动；损坏/未来版本/恢复候选不静默覆盖，也不继续战斗写盘。场景退出具有重入门与 2 秒音频 drain 边界，超时非零退出。

工程取舍：保留旧 GameUI/战斗系统以小步打通章节循环，暂时不做整体 HUD 替换，不改演员伤害、碰撞或 Boss 攻击。新 Player、射手和首领资源仍待 M3/M4，不把过渡深渊监工称为藤冠守卫完成。

## RED、修复与验证边界

- 缺章节场景/真实 Main 路由先 RED；专项先测非法启动和伪造通关，再实现。
- 暂停空格不能继续、暂停清除玩家超载而章节状态仍激活，均有 RED→GREEN；恢复时同步冻结的超载状态。
- 实际弹丸命中产生 physics query flush 错误：停止该 GPU 运行。将 Director 放于章节协调器下，通过 WaveDirector 原有 deferred drop 回调生成真实掉落，删除即时击杀回调里的物理对象创建。专项正确 RED 虽有 TEST PASS/引擎退出0仍因 ERROR 被拒绝；修复后通过。
- 普通输入 GPU v2 的作者脚本类型/输入问题、v3 的真实玩家死亡均保留为失败，不降 Boss 血量、不改玩家生命/无敌、不写死亡结果。v4 仅优化合法普通按键的可见危险规避，随后实际通关。
- 原生 Window 中轮询鼠标位置的探针确认仅注入事件不足，作者脚本采用官方 [Input.warp_mouse](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-warp-mouse) 移动实际窗口光标，再执行普通射击输入；没有写演员朝向/伤害/血量。

专项结果：CampaignChapterLaunchTest 12、NurseryChapterTest 43、NurseryProjectileDropTest 1 断言，均退出0且无错误/泄漏。LaunchTest 从实际 Main 进入章节，等自然入场与真实敌群，再战斗暂停返回真实 Main，核对无虚假存档、音量/静音保留；不是仅打开空场景。ChapterTest 为失败/重试等边界使用测试加速和真实 take_damage，不称普通输入通关。DropTest 通过真实弹丸物理命中检查掉落，伤害仅测试设置。

最终全量 `nursery-chapter-full-v3.log`：退出0，106 Godot 套件/181897断言，35 Python 套件/270测试。保留严格正向标记、引擎错误/泄漏拒绝、帧数和墙钟 watchdog；章节专项预算等待自然入场，不跳过它。

## 实际原生完整关卡证据

[v4 原始报告](art/previews/campaign/nursery-chapter-flow-v1.json) 与 [路线](art/previews/campaign/nursery-chapter-route-v1.png)、[通关](art/previews/campaign/nursery-chapter-clear-v1.png) 来自真实 Main / Window / 章节，不是离屏伪 UI。普通鼠标按钮完成进入、免费奖励/购买、供给路线及迎战首领；普通移动/瞄准/射击/冲刺完成全链。

v4 退出0、8689检查、17原生帧、8501次相邻位置变化、1959次真实发射、62击杀，最终生命19，种子2156691711。没有改玩家生命/无敌、演员输出/碰撞、Boss血量10800、门户/遭遇时钟、生成/死亡状态；所列生产源码 SHA256 前后不变。该记录证明供给路线工程闭环，风险分支另有核心事务测试，不虚称两条路线均普通输入完整通关或真人体验验收。

独立新引擎进程102556通过 [永久进度恢复报告](art/previews/campaign/nursery-chapter-restore-v1.json)：实际 Main 加载1通关/2解锁、1可重玩、2制作中禁入，进度文件哈希不变。所有诊断使用明确隔离 build 存档，没有访问用户真实永久存档。

实际 PCK 3,143,908字节，SHA256 `c18d4f6c861832391292cc6eebd5f4dd2dac88eb4eddeea47302bc62069d8e00`。无项目路径的独立包目录加载实际菜单/章节，生成真实敌人，普通移动并战斗暂停返回，退出0、无错误/泄漏；包排除作者脚本、测试和文档。标准 release gate 与 Main120帧通过。包检查是 headless 功能证据，不是独立 EXE 原生完整 Boss 通关或公开发布；旧 v15 包未替换。

## 尚未完成 / 下一步

通关截图 HUD 冻结于最后一次刷新显示61，而真实已接受击杀为62：终态暂停前有一帧统计刷新滞后，不能据此声称精确终态 HUD 已验收；后续统一 HUD 终态刷新需回归。

M2.2 首关工程闭环完成，M3/M4 全新资源仍未完成，六关整体目标不缩减。下一步优先 M3.1 原创新玩家四朝向原生骨骼、握枪挂点及全部新动作；再逐敌族、大型非攻击资源。全部角色骨骼门通过前不制作大型/Boss新攻击动画，后续替换过渡演员并重新验证。第2–6关地图/敌族/Boss/奖励、密集性能、完整六关链和真人试玩仍待完成。不公开发布。
