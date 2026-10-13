# 最终包前置修复与当前GPU（2026-10-12）

不是最终独立包或六关整体完成。旧全量57700实际exit1，328 Godot通过、16失败、37 Python/282通过。16项失败均为窄种植箱左叶片自交造成`Invalid polygon data, triangulation failed`；不是资源泄漏，也不是潜行碰撞逻辑失效。

## 已完成并验证

- 只把左叶内点限制为`-minf(3,w*.04)`；宽度≥75时仍是旧3px，正常地图外形不变，未改碰撞、地图种子、导航、玩家或战斗参数。实际`_draw`捕获的多边形测试覆盖20×2000、280×20及四常规尺寸/四角色，真实RED→486 GREEN。旧16个失败专项30/60/120Hz矩阵全部actualexit0、唯一正PASS、无错误。
- 两份native Art测试保留作者manifest校验，相对继承不读docs的Runtime测试；命中136/135、地形136/135分别通过。CombatFeedback与ArenaRuntime支持改相对TestSupport，包门逐SHA复制，49/58通过（后者断言数随真实随机障碍数变化）。
- 包门不再硬编码旧Rift GPU。明确接收当前报告、日志、实际退出receipt、源冻结。168关键姿态、90连续样本、3实际尺度、四图片SHA、报告/日志/脚本SHA均受校验。canonical四根/五扩展/六显式文件完整键集重新枚举比较；themes精确两个路径，包门自身另列SHA。数字/布尔/缺字段的类型误收已修。
- Python精确包策略14项通过；PowerShell语法0错误。独立只读复审无剩余代码Required；实际导出/纯包运行尚未完成。

## 实际前置门测试与失败记录边界

`FinalPackPreflightTest.ps1`执行真实包门的原前导，只补充内存ScriptBlock缺少的脚本路径自动变量，并在export边界前截断，绝不启动引擎或导出。正常输入通过；boolean/string/missing exit、string passed、缺失TerrainSweep源码key、错误theme key六项均被正确拒绝，最后唯一PASS7；GREEN v2独立pwsh进程actualexit0。

保留`f7-preflight-behavior-red-v1.log`（测试OrderedDictionary.Clone错误，非有效业务RED）、v2（ScriptBlock路径错误，非有效业务RED），以及v3。**v3磁盘日志为0字节**，不能把它当成记录了拒绝失败的日志。业务RED实际在工具终端返回，chunk `2700a3`、shell exit1：`Preflight contract failed: boolean-exit rejected=False`。这是修类型前门误收布尔退出的终端证据，而非后来补写的旧日志。GREEN v1虽然测试打印PASS，外层误把未定义LASTEXITCODE当失败，因此未计作通过；修正显式exit并用独立pwsh的GREEN v2才计通过。

## 当前GPU（兼容后端、实际退出0）

- `f7_final_rift_resource_gpu_v1`：673检查、168姿态/90连续/3尺度；真实receipt绑定退出0与日志/报告/脚本；四图已实看。仍是资源姿态而非真实Boss胜利。
- `f7_final_arena_gpu_v3`：149检查，36道具/3地板/两个真实Main入口，1726固定根源银行；种子511076251与4235981783，障碍10/12。六图已实看，真实玩家behind温室时仅装饰淡至0.32，根与玩家alpha1，solid footprint不淡。仍非六关普通流程或全部地图像素/性能验证。
- `f7_final_impact_gpu_v4`：37检查，12孤立效果，实际玩家/小怪/监工原不透明身体像素2468/1995/11357均零改动，真实头顶预警96像素零改动；组合及孤立图已实看。效果自身淡出是正常行为，不把受控图当全部战斗体验。

下一冻结当前源，重新全量，再独立候选/实际包目录与许可/新同源六关链。旧失败、旧来源pending、原PNG、旧候选与用户保存均保留；无中间提交推送、无公开发布、无整阶段完成邮件。
