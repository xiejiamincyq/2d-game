# 超载击杀声：原创合成替代与资源退役

2026-10-12，5分钟超载。当前运行声音由 `scripts/systems/OriginalOverdriveCue.gd` 确定性合成，不再加载来源未确认的 MP3。没有下载、复制第三方音效，未安装工具、购买、联系作者或公开发布。

## 决策与声音设计

此前候选 Pixabay 页面不能证明本地裁剪文件的精确来源，因此选择[复核方案](overdrive-source-recheck-2026-10-12.md)已有的项目原创出口，不把“同作者”当文件对应证据。新声是短促的下行低频撞击与两次轻碎裂噪声，固定种子；非原 MP3 的裁剪、模仿采样或未知素材混合。不是 Pixabay 作品，不冒认 DRAGON-STUDIO 作者。源码与合成参数是本项目原创来源记录；不等于整个项目版权/法律结论。

0.18 秒、22050 Hz、3969 样本、16-bit 单声道、无循环。仅 AudioManager 初始化时生成，仍走原有 16 声部、-8 dB 声部增益和普通/超载共享 0.045 秒冷却。没有改伤害、攻击、玩家移动、存档或背景音乐。

[试听文件](../art/previews/campaign/native-retired-audio-v1/original-overdrive-preview-v1.wav)，SHA256 `a84c78f98ff53c46a564bebebd33e17e9fd6b11997100f6fa323416916dd4bbe`。自动生成预览拒绝覆盖同名文件。程序检测峰值 0.528703、RMS 0.063027、DC 0.000085，末 5 毫秒量化后静音、未削波；这些是数据指标，主代理未据此宣称主观听感通过。

## 原件与运行范围

旧 `assets/audio/overdrive_bone_breaking.mp3` 原件仍在，44347 字节，SHA256 `cdeae6778c84761b7a0d634c5036c3366b997f5351ef055f007e45b80592e5ef` 不变；来源状态继续 needs_review/unknown，不改为 approved。AudioManager 移除其 preload，导出逐文件排除，测试不再把路径匹配称为“approved Bone Breaking”。历史审计、用户提供的候选链接和原导入文件均保留。

另精确退役五张旧 PNG：scrapper、玩家身体图集、武器图集、单武器图及未打包道具图。Player 仅移除两条无消费者路径常量；保留兼容接口、回退函数及全部原件。地面、已打包道具、命中特效位图仍有真实运行依赖，未排除它们。[此前八张旧敌图退役](../native-retired-enemy-dependencies-v1.md)是历史前一切片，不覆盖本轮新包。

## 验证与局限

- 原创音频语义 RED：旧运行返回 MP3，实际退出 1；不是解析错误。导出 MP3 排除策略也先实际 RED。五 PNG 策略先 RED5 后 GREEN10，新音频规则加入后策略 GREEN11。
- 工作区实际导入成功；OriginalOverdriveAudio34、CombatFeedback49、AudioLifecycle651、NativePlayerResource3430、PlayerNativeIntegration699、NativeCharacterRoster644、ChibiRuntimeArt51，共 5558 检查，均实际退出0、唯一正 PASS、无错误或泄漏。错误拼写的 NativePlayerIntegrationTest 缺文件那次保留，不算通过；正确名字已补跑。
- 34 项覆盖 PCM/确定性/能量/边界、64 次密集播放不增节点、共享冷却恢复和播放释放。CombatFeedback 新用例调用真实反馈组件并注入 killed=true，证明超载状态路由，不冒称真实敌人致死或 Main 的端到端击杀。
- 独立 `native-retired-audio-pack-v1/game.pck` 实际 6,074,540 字节，SHA256 `07964613f2db5463f23c57c9d70cc3e4e31d5adb636f2d836257201d9a52cbec`。实际读取594目录项，13旧PNG及MP3的源、导入/缓存名称匹配0，作者目录匹配0。不是仅看导出日志推断。原创合成脚本入包。
- 独立目录仅当前PCK与7份原测试/辅助源码SHA副本，六项实际执行34+651+49+3430+699+644=5507，实际退出0、唯一正PASS、无错误泄漏；1680条源末SHA和两份PCK SHA一致。未借工作区导入缓存加载旧图。
- 独立五轴只读审查无 Critical/Required，并现场复核实际包哈希、目录、六日志、1680源与7夹具SHA；审查者没有重新运行引擎。静态位图策略不能单独证明 UID/动态加载完整闭包，以实际包与原生名册补证。27份canonical逐SHA副本及manifest在 `docs/art/previews/campaign/native-retired-audio-v1/`；PCK原件在ignored build，不是正式发布。

本切片音频来源和指定资源退役闭合，不签人类听感、全部剩余资源许可、Main启动、真实普通六关链、硬件性能或整个goal。整体F4/最终full/同源候选及新六关链继续；不做中间Git提交推送、完成邮件或公开发布。
