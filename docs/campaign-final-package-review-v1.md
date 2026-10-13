# 当前源全量与独立候选（2026-10-12）

> F8历史快照：后续原生菜单轻动效改变了源码，本页数字仍是真实旧记录，不证明当前F9整版本。最新状态见[tasks](../tasks/campaign-final-live-state-v1.md)；不重写旧证据为新通过。

分支`5分钟超载`，HEAD`713dde5f75dd0827b7c56ab195d55eed5826c5a4`。本地验证节点，不是完整Goal/真人试玩/全部许可签收；未提交、推送或发布。

## 当前实际通过

- full65821已actualexit0：347 Godot/330300断言、37 Python/285；唯一最终PASS，无错误/泄漏。1726 canonical源+两themes+三显式验证helper前后SHA无差异。日志SHA`c8457b1ad4cf5606953b69e3e2ff7d8be33a362abefbb6d1ad27eaad249d9790`，冻结SHA`d156f591c90fcfae51cdc8a1c1d3702a54db9f93f13544f63a3966a32f369ff6`。默认三个真实保存开始和结束均absent；这不是已有非空用户档迁移证明。
- fresh入口GPU252检查，960/1280/1920各四页及实际关卡入口共15图已查看，18源码/15图SHA一致。0/5/6进度是受控前置，不是六胜利。
- `f8-final-native-pack-v1/game.pck`实际20规范夹具/6781断言、Main120，1755条源/证据SHA无漂移；每项实际退出0、唯一正PASS、无错误。包含新命中/地形纯运行断言、窄叶片几何、实际兼容Boss/第五第六Boss、玩家/身体名册、声音/层级、Main正式入口与真实存储边界，不把作者manifest塞进PCK。
- 实际读取新PCK的587目录项，制作目录与外部PNG/SVG/ctex/音频/字体文件匹配0；24实际身体和27动作库的资源/remap均在。包4611676字节，SHA`a8b2e96408be3b7e438a09a683121a7ca0266bb8b9d9c3667c2d8f5fcb1a8ea6`。不是只看exclude或export日志。
- 配置的Godot引擎直接使用这个独立PCK，按原canonical外置夹具运行真实Main/首章：自然入场、普通移动/射击、返回，12检查actualexit0；GPU126帧，六采样图已查看。UI进入/返回用受控pressed信号，不冒称OS鼠标或真人。Movie fixed60是录制时间步，不是性能测量。
- 新本地候选`build/playtest/native-campaign-f8-v1/five-minute-overdrive.exe`已真正导出并保留，109019648字节；EXE SHA`b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0`，PCK与上述已验证包逐字节SHA相同。实际EXE/Main120 headless启动退出0。

## 正式EXE脚本试玩未通过，不改写结果

试图在上述正式EXE执行外置canonical试玩脚本，实际进程退出0，但1800帧始终是Main菜单、没有预期的正PASS。外层验证实际exit1，`runtime-gpu-v1/verification-failed-report.json`明确标`SCRIPTED_GAMEPLAY_NOT_RUN`，不能用引擎退出0宣称普通输入通过。

最后菜单PNG与已实际查看的独立PCK返回菜单PNG的字节SHA完全相同（`df54936e8b74ab1a07c175613fd0b6bc34a7de375b2bffaebe8b8fd85e86315f`），因此仅核对了正式EXE菜单渲染。[Godot官方CLI源码](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/main/main.cpp)将script覆盖置于OVERRIDE_PATH_ENABLED及disable_project_settings_override机制之下；实测此发行实例未执行覆盖，不进一步猜是宏还是配置。保持发行保护，不启用unsafe override、不补生产测试后门。正式EXE的真正普通操作/OS瞄准仍单列未验证。

## 六关链与下一步

新的同源新档链`campaign_f8_fresh_v1`已六段真实终态退出0，各关独立实际进程退出、正PASS、文件/保存/父报告SHA后才能进入下一关，不预填前关胜利。风险第六关也已14445/退出0，两全通档新的只读恢复各76/退出0，见[六关记录](campaign-final-six-chain-review-v1.md)。三尺寸首关性能已真实终态并独立复算，见[限定性能报告](performance/campaign-final-f8-v1.md)。最终完整资产美术/权利核对仍待签收。

同一个已验PCK补充两份规范外置夹具：`RiftChapterTest`145、`RiftChapterLaunchTest`23，均actualexit0、唯一正PASS、无错误/泄漏。五份外置测试/支持源逐SHA复制，工作目录只有独立证据，不用源码`--path`；两个真实六关通关/恢复报告作前置，1739项源与前置证据不变，PCK SHA不变。记录在 `f8-final-chapter-pack-supplement-v1/report.json`。这是受控伤害/保存失败夹具的语义验证，不重复称作正常输入胜利；与原20夹具合计22项/6949检查，不宣称又做一次导出或EXE鼠标试玩。

PID不能机械要求“launcher==engine”：现场已核对配置的console.exe是198152字节的包装器，真正GUI引擎是178485256字节。第四段CIM现场为runner42964→console66716→真正engine23436，命令和当前第四段脚本/id一致。receipt两字段分别记录wrapper与engine，区别正常；不补造早先段的进程现场，也不把无等号当伪造失败。

旧失败full、旧候选、23身体冻结rig门、原PNG/MP3与其未核定来源状态全部保留。最终许可与美术评审针对当前实际消费者另列，不批量改写历史manifest。完整Goal保持active。
