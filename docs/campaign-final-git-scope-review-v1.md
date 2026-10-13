# 最终Git范围审查与干净候选依赖修复

未暂存/提交/推送/发布；这不是最终提交门通过。原OS桌面鼠标/瞄准门仍待用户解锁，整个Goal仍active。

## 独立只读审查

当前差异实际为75文本+2张旧PNG，不是77份文本。复审按用途核对66个代码/测试/工具差异、精确导出排除和入口/来源/任务说明；没有发现无关功能混入。兼容模式、Dash恢复、旧Boss原生化、声音/环境退役均对应原Goal或其真实失败修复。长历史文档和数千个新资源/证据不宣称逐字重审。

原22项排除继续保留：两张旧预览、退役import及19个早于Goal的本地资源/诊断。`VerifyPairedSixScenes.gd.uid`因对应已改脚本为明确必要例外。5份隔离链campaign.json.bak是保存证据，不是默认玩家档；build、EXE/PCK、缓存和下载原包不提交。

## Required 1：不依赖未提交旧素材

原导出策略对所有退役图片强制is_file，但`mint_farm_props_b_v1.png`是未跟踪且被排除的本地旧源。因此本机GREEN不能保证检出后可测试；没有通过提交旧图来掩盖问题。

先加回归，仅对这张图模拟不存在，实际RED退出1，命中原存在性断言。修复只有一个明确LOCAL_ONLY例外：它不要求clone存在，但所有精确exclude/无运行引用检查依旧无条件执行，所有已跟踪历史原件仍要求存在。当前15项实际退出0；独立复审确认无新增Critical/Required，关闭此缺陷。

首个GREEN外层包装器误把预期测试数写为12，而内部日志为15/OK；该外层失败记录保留，不当作成功。修正观察包装器后v2记录真实Python退出0/15、当前源码/日志SHA，并检查测试方法数相符。没有跳测试或改原日志。

## 真实隔离filesystem候选

在ignored build下从当前HEAD的git archive展开，再覆盖2761个拟提交相关路径，严格排除22项。旧图实际不存在，不是仅靠mock。实际普通资源import及`run_tests.ps1 -Group python`退出0，37套286测试；复制输入前后2761份SHA无漂移。没有新建Git分支/worktree、没有改索引或移动玩家文件。它是HEAD+overlay候选，不是尚不存在的最终commit干净检出，也不是Godot游戏全量/OS试玩。

本轮只改`test_release_pack_policy.py`验证代码；F9冻结的1732 canonical、2 themes及另2验证helper全部未变。新的完整冻结v2 SHA `1b6b8ea59e492ce550468cff4b4bbd1f9280d6c6fda7072e92ea4bb5df29cbbf`仅更新该Python helper。既有F9 348 Godot、实际PCK/GPU/六链是相同canonical运行源的证据，37Python285是旧历史结果；当前Python部分为这次37/286，不伪造一次新的whole-all汇总，不重做未改游戏包或矩阵。

## Required 2：最终暂存使用新清单

旧v2清单比后来工作区少96份证据/文档，另有4份原列文档SHA变化；它不能直接用于暂存。本轮文档收口后生成新的逐路径/当前SHA/用途/保留排除清单。清单仍只是拟提交范围：OS门通过后还必须实际暂存、查看真实staged diff、做秘密与范围检查，然后才能聚焦提交/推送并核对远端SHA。

旧任务顶部只补统一最新状态指针，下方历史数字与失败不重写。旧`VerifyBossArt/VerifyBossFraming`局部来源表不当作当前全源证明；当前证据采用完整银行、实际包目录及当前独立Boss专项，不为一个旧诊断标签重开已过矩阵。
