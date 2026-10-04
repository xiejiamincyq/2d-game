# 独立Windows包轮廓依赖修复

实际导出的旧EXE虽然退出0，`Main.gd`却因轮廓脚本被排除而加载失败。现已把运行组件移到 `scripts/effects`，保持脚本和UID逐字节不变；重新导出的EXE通过无源码目录的启动和原生标题检查。同一PCK另通过原生开局输入观测。这是本地启动技术子项，不是全项目或完整EXE通关验收。

## 实际失败与最小修复

- 基线来自 `e6226f0fb1163450adec6cd3122fb1fa0a9b2972` 对应当前工作树的逐文件校验副本；包含已有未提交运行文件，不称纯HEAD构建。1197输入文件116180363字节，逐项SHA见证据内 `export-baseline-v1/input-manifest.json`。
- 基线导出成功，但独立EXE的日志出现 `Preload file "res://scripts/art/PlayerOcclusionOutline.gd" does not exist` 和 `Failed to load script "res://scripts/Main.gd"`。门禁实际拒绝退出2，EXE自身退出0不能作为成功依据。
- `export_presets.cfg` 排除整个美术工具目录，生产Main却依赖其中的脚本。保留该排除，只搬迁 `PlayerOcclusionOutline.gd` 与UID，更新Main、三项测试及三个美术诊断的路径。
- 新旧Git blob分别完全一致：脚本 `7d70421920eb0cc049ecd34251dd65d0403a5016`，UID `12c067b13150a87c95505bf0d5ef88a8fef36618`；未改shader、角色、碰撞、伤害或玩法。
- Python策略门新增字面量runtime preload排除检查：旧源码5测试1失败，修后5测试通过。它不覆盖动态load、全部场景依赖或Godot所有导出语义；实际导出/日志检查仍不可省略。
- 完整门实际退出0：66 Godot套件169799断言、31 Python套件233测试。20个既有无关脏文件逐哈希复核未变，未纳入本片Git提交。构建副本包含当前运行目录文件，输入清单如实登记，不能声称独立包完全来自已提交HEAD。

## 修后真实包与两个不同验证层

修后输入副本1197文件116181433字节；导出前输入哈希见 `export-fixed-v1/input-manifest.json`，后续Godot导入可生成或改写副本内导入状态，不冒称该清单是导入后的完整目录哈希。首次导出因目标目录不存在失败，日志保留；建目录后真正导出退出0。

本地包位置：`build/diagnostics/local-delivery/export-fixed-v1/package/`，只需同目录的 `five-minute-overdrive.exe` 和 `five-minute-overdrive.pck`。没有发布或把可执行文件提交到Git。

| 内容/层 | 实际结果 | 边界 |
| --- | --- | --- |
| EXE | 109019648字节；SHA256 `b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0` | 官方模板，不含源码回退 |
| PCK | 6848612字节；SHA256 `88588bf0629413b6fd12b55dc887060470ac978107133a2b04b358568e2740d8` | 低于30MiB现有预算；不是精简已完成 |
| 独立EXE/headless | 从包目录启动，不带`--path`，120迭代退出0、无错误/泄漏标记 | 标题启动，不是玩法/图像 |
| 独立EXE/native | 不带外部脚本，3次固定movie迭代退出0、3张1280×720标题原PNG，无错误/泄漏 | 实际看首图：标题、按钮完整。固定录制不是实时时钟/性能/物理音频证明 |
| 同PCK原生开局 | 编辑器引擎`godot.exe --main-pack`，无项目源码路径；472个PLAYING输入观测、17击杀、6次随机换向、3次脱困尝试，10秒后仍PLAYING；4张原PNG | 外部脚本和输入策略为诊断，正式Main/角色/地形从PCK加载。不是导出EXE游戏内自动输入，不是完整通关 |
| 包内资源 | 新轮廓资源存在，旧路径不存在；虚拟目录扫描无`scripts/art`及`scripts/tests` | 旧M2三套贴图仍在包内，后续独立清理打包范围，不删除源资产 |

所有成功运行各自六个真实存档（默认/测试×本体/tmp/bak）前后均不存在且未变化；原生开局重定向到专用诊断存档。没有复制真实存档内容到证据。所有本轮拥有的运行进程已退出；既有23712录制进程保留，不称干净机器性能验收。

## 外部脚本尝试失败与证据限制

最初用导出EXE的`--script`注入诊断，两次分别50/150秒超时，均无诊断完成标记；所属进程清理。native-v1仅保存启动输出/空日志，没有完整launcher JSON；native-v2结构化结果明确`valid=false`。另一次headless `--script`探针也未完成，核对准确PID/路径后仅清理该所属进程，未把PowerShell对GUI程序的立即返回称作实际退出。

[Godot官方命令行说明](https://docs.godotengine.org/en/latest/tutorials/editor/command_line_tutorial.html)把`--script`列为extended，仅编辑器及允许路径覆盖的模板可用，未知参数也可能被忽略。因此停止在官方导出模板中尝试注入，改用编辑器加载同PCK做只读资源/原生开局探针。前两次不作为Vulkan或正式游戏卡死证明，不通过关闭保护/改模板绕过限制。

精选证据：[ZIP](standalone-outline-evidence-v1.zip)、[逐成员索引](standalone-outline-evidence-index-v1.json)。49成员2123605字节，ZIP SHA256 `85dc728bd1f4406ee623d13e677f558a2953ee56a66c853d5dee52ce8b044db6`；CRC/成员/原路径与SHA逐项核对。保存失败日志、红绿/fullgate、输入清单、选定源、两层原图/报告及诊断脚本；不包含EXE/PCK、全量源副本或真实存档，不能称可移植完整交付包。

已实际看导出EXE标题和同PCK第9秒开局图：界面完整、玩家轮廓在密集怪群可辨，但不能由这两张批准拥挤运动、四向、完整LOB飞行或所有特效透明度。S2/S3/S5整体、性能、素材来源/许可证和人工手感仍未完成。独立代码、运行绑定及49成员封包最终审查均无Critical/Required，可聚焦提交本片；下一片先精简旧M2导出范围，再处理剩余交付/视觉缺项，不新增玩法、不使用网页ChatGPT、不发布。
