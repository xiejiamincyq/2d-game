# 自然败局与跨进程继续验证（2026-10-04）

用户取消网页端，Codex工作区自行判断。本片只增加隔离诊断和验证，不改正式游戏、存档格式、平衡或美术，不发布。此前[三次自然整局](natural-run-validation-v1.md)保留为其提交版本的历史证据。

## 实际运行

| 运行 | 实际进程PID | 有效战斗步 | 结果 |
| --- | --- | --- | --- |
| os-checkpoint-v3 | 51480 | 1435 | 第一波自然结算保存后退出进程；非胜利 |
| os-resume-v3 | 33976 | 1800 | 新进程按C继续、状态完整恢复、正常商店交易、第二波清场并进入第三波；步数预算结束，非整局胜利 |
| idle-death-v1 | 9320 | 692 | 不移动、不射击；自然敌人伤害使HP到0，正式败局页、R重开回标题、无Continue、隔离存档清空 |

地图实际派生种子均为426363786；20260908是初始全局RNG种子，不冒充地图种子。固定60物理Hz、max-fps60、真实顿帧，无fixed-fps。恢复前要求源文件SHA一致、原检查点报告SHA绑定、隔离存档SHA未变、相同存档路径和不同PID。恢复瞬间记录实际玩家和商店状态，外部Python再次与检查点逐字段比较，不只相信verified标记。

自然败局实际击杀0、游戏统计11.548秒，逐步fire均false，输入均(0,0)，首至末采样墙钟11.502秒。没有直接扣血/调用结束游戏；结果由正式Main产生。所有正式记录原日志退出0、无错误/泄漏，外部报告/日志检查通过；真实默认与测试存档含tmp/bak六路径哈希前后不变，owned-tree orphan最终0。

## 失败与根因（原始记录均保留）

- os-checkpoint-v1通过，但os-resume-v1实际走到胜利9278步后仍valid=false、退出2，**不算通过**。原始Dictionary比较把JSON读取后整数/浮点标签变化、Vector2十进制舍入当成恢复损坏。
- 只读恢复探针确认玩家/商店恢复函数均成功：玩家position显示相同但原值严格比较不等；商店generation/wave读入浮点而运行态为整数。按同一JSON序列化再解析后的持久化表示比较，没有设置坐标或数值容差。
- 新NaturalRunSnapshotCheckTest实际红测拒绝忠实round-trip、退出1；修后7断言通过，包含真实0.001px坐标变化、金币、卡牌等级、布尔类型、缺失/额外字段均拒绝。测试只调用静态比较函数，不启动第二个游戏SceneTree。
- os-resume-v2恢复事件verified=true、1800步工具valid=true，但最终resume_reference.verified仍false；外部检查拒绝。根因为Dictionary.merge默认不覆盖已存在的false；只给诊断合并显式overwrite=true。原报告没有回填为绿色，使用全新v3检查点与进程重跑。
- Python检查器新增恢复实际状态校验的红测发现仅相信verified=true会漏掉health变化；修后11测试通过。检查点/跨进程识别最初2失败及上述单失败日志都保留。

## 复现

以下名称必须每次改为从未使用的run，按顺序等待每个进程退出，保存各自原输出；不能在两个进程之间修改绑定源文件。

```powershell
godot_console --headless --path . --audio-driver Dummy --max-fps 60 --script res://scripts/art/VerifyNaturalRun.gd -- --seed=20260908 --run=fresh-checkpoint --steps=3600 --mode=checkpoint --clock=realtime
godot_console --headless --path . --audio-driver Dummy --max-fps 60 --script res://scripts/art/VerifyNaturalRun.gd -- --seed=20260908 --run=fresh-resume --resume=fresh-checkpoint --steps=1800 --mode=flow --clock=realtime
python -B scripts/art/check_natural_run_report.py build/diagnostics/natural-run/fresh-resume.json --log fresh-resume.log --checkpoint build/diagnostics/natural-run/fresh-checkpoint.json
godot_console --headless --path . --audio-driver Dummy --max-fps 60 --script res://scripts/art/VerifyNaturalRun.gd -- --seed=20260908 --run=fresh-death --steps=3600 --mode=idle --clock=realtime
python -B scripts/art/check_natural_run_report.py build/diagnostics/natural-run/fresh-death.json --log fresh-death.log
```

## 自审与剩余范围

相关代码不到150新增行，无新依赖；诊断仍在导出排除目录，初始化前绑定安全ID隔离保存路径，拒绝覆盖现有证据和保存文件。只检查、暂停和清理本工具拥有的场景；没有结束其他用户Godot进程。真实完整胜利与此处短恢复/败局证据分列。

这是根代理自审，不冒充新的独立最终复跑。S4整体仍未完成：还需20个实际地图安全/可达性、真实连续渲染/六景与暂停控制等证据。S2后期拥挤、S3视觉、S5来源/性能/本地冻结交接继续推进，人工手感和最低硬件保持human_pending。

## 回归与归档

完整预推送实际退出0：57个Godot套件166427断言、27个Python套件170测试；资源导入、空白、暂停所有权和变更密钥扫描均通过。生产游戏源文件未修改；无关历史截图、音频.import及原始环境资产仍留在工作树，未混入提交。

[原始证据ZIP](natural-run-flow-evidence-v1.zip)为966084字节、24项，SHA256为`b53e465d475fef7f408c628e467b3c817ef83a4d5d4fbcb0f0259e3bb7506405`。已只读核验三份正式原JSON与本地原文件逐字节一致、原日志及完整回归实际在包内。ZIP包括失败/红测，不可声称包内全部绿色；不含真实用户存档、凭据或发行包。

正式原JSON SHA256：检查点`87547970e08faf5fcc267891a092fc4d24e28c950560c48f721cd40897157766`；续存档`ee0bbd5733862762132a42c1f9ab702f27e12f4345605978a21a83aeaa60313c`；败局`6e1ef917361882fc595c2a11cf4beb19ea9a676484b23e16014c1cb91533b65e`。
