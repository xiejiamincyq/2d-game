# 本地 Windows 试玩交接 v1

历史记录：本包不含后续投弹视觉升级。当前试玩目录已转到[交接v2](local-playtest-handoff-v2.md)，本记录和旧目录保留不改写原核验事实。

本机已经有可直接双击启动的两文件试玩目录，不需要安装Godot、打开编辑器或重新导出。本片只整理现有包与说明，不换风格、不增加玩法、不发布、不代签完整项目验收。

## 最短启动方式

打开本分支工作树下的 `build/playtest/5分钟超载-c5c5710/`，双击 `five-minute-overdrive.exe`。两文件必须保持同目录；复制整个目录即可在已支持的Windows环境试跑。目录名标记本次核对的HEAD，不意味着重新从纯HEAD导出。

本机完整路径：`C:\Users\21604\Documents\2D game\.worktrees\5分钟超载\build\playtest\5分钟超载-c5c5710\five-minute-overdrive.exe`。EXE/PCK未提交Git、未上传分发；Git克隆不会自动得到这个目录。遇系统拦截或启动失败，应保留提示与日志，不关闭系统安全保护，也不将软件签名/最低配置视为通过。

## 操作与存档

- WASD移动，鼠标瞄准，左键射击，右键冲刺；Space暂停/继续。
- 结算页1—6选卡；开始页有有效存档时C继续；胜败页R重开。
- 每局随机障碍地图。冲刺/隐身地形已按已批准合同处理，但不承诺全部随机地图/构筑/硬件都没有问题。
- 人工正常启动使用正式存档，与隔离诊断不同。主动新游戏、胜败或R重开可能清理旧进度；如需保留上一局，先选择继续，不要把试玩当作只读诊断。

## 本轮核验

核对基线HEAD `c5c571099c5a7ce63eca3fa1a8d44b02084c5d61`。当前 `project.godot`、`export_presets.cfg`及assets/scenes/scripts/themes，按现行preset排除项过滤后的**188个输入文件完整路径集合与SHA**，全部等于既有实际导出的前置输入清单。无需为仅文档变化重新导出；这证明有限输入清单一致，不证明全部Godot importer/cache语义或任意未来修改后的包仍适用。

原导出输入记录HEAD `6bf13905f8d8c342c334c232755cb71c0e4495cc`，且输入包含原有未提交文件。本包明确不是clean HEAD构建，未把这些用户文件提交Git或改写。两文件复制后与原导出包逐字节哈希一致。

| 文件 | 字节 | SHA256 |
| --- | ---: | --- |
| five-minute-overdrive.exe | 109019648 | b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0 |
| five-minute-overdrive.pck | 3000912 | 7ead85380dde3ea1505d4e8904171eb9747411094731fe7e3bc17d910e116d8c |

新目录中实际启动独立EXE：headless、Dummy音频、120迭代，PID25128、退出0，启动日志无脚本/引擎/泄漏错误，六真实存档前后不变；没有`--path`、外部`--script`或源码目录。**仅是标题启动检查，不是完整EXE玩法/图像/音频证据。** 先前正式EXE标题原图、同PCK的编辑器开局、包资源排除及短测纠偏见[旧M2精简记录](m2-package-review-v1.md)，范围仍分别保留。

[交接核验清单](local-playtest-handoff-v1.json)保留188输入哈希、两文件哈希、实际命令/PID/日志哈希和存档核对；本地启动原日志在 `build/playtest/handoff-c5c5710-startup.log`。文件哈希只能证明这些文件的身份，不能替代可信签名或安全审查。[本机性能基线](performance/native-natural-baseline-v1.md)是编辑器引擎中的一次诊断，不当作这个独立EXE的性能验收。

## 尚未签收的验收

正式EXE完整开始/移动/射击/冲刺/暂停、自然商店与C继续、胜败/R重开，以及Boss全过程，需要独立EXE实际操作证据；不能以编辑器自然胜利替代。实际声音、拥挤运动中的玩家轮廓/敌我提示、完整LOB飞行、四向动画与连续手感也未代签。素材许可证、最低硬件和S2—S5整体保持未完成，见[现行任务](../tasks/supervised-completion-todo.md)及[来源记录](audio/overdrive-bone-breaking-source-v1.md)。

不支持正式模板的外部脚本注入，旧超时尝试不重试，不关闭模板保护或修改生产输入来制造通过。自动化可继续补充尚缺的技术/视觉证据；只有需要实际人工操作或新权限的部分留给用户，不把“已经给出试玩目录”定义成项目完成。
