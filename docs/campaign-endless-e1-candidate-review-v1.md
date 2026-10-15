# E1 内部候选：包资源检查，不是最终验收

工作树`5分钟超载`，HEAD仍125a67cd0ef1d71eb5812b04bc24cea42867d8ae，整轮改动未提交。只处理六关射击游戏；没有发布、推送或完成邮件。

## 身份

目录：`build/playtest/native-campaign-endless-e1-v1/`，必须保持这两个文件成对，不与F12或其他候选混用。

| 文件 | 字节 | SHA256 |
| --- | ---: | --- |
| five-minute-overdrive.exe | 109019648 | b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0 |
| five-minute-overdrive.pck | 4659396 | 1c234af3277379dd0c2d4a2c872de287b357f4b4a850e1edd1158c556df773ea |

外部夹具`VerifyEndlessPackedResources.gd` SHA256：`d51919e9dcb37f6152dcbde7d43b637a9276dbfb676887cc4bd2890cc4ce0b51`。夹具位于作者源码，不进入成品。

## 已执行

- `endless-e1-export-v1.log`：Godot4.7 Windows Desktop release导出实际exit0；未发现错误或作者路径进入保存清单。
- `endless-pack-workspace-negative-v1.log`：同一夹具在工作树运行实际exit1，9个资源存在性断言失败，拒绝将源码环境当作正式PCK。该负对照在创建任何世界或读用户进度之前退出。
- `endless-e1-engine-packed-resources-v1.log`：从候选目录使用Godot4.7控制台引擎`--main-pack five-minute-overdrive.pck --script <外部夹具绝对路径>`，没有`--path`，actualexit0/唯一PASS224、无错误泄漏。
- PCK检查包含五个旧模式夹具、旧WaveDirector/RunSnapshotStore路径、测试/作者/文档/未溯源音效资源均不可加载；实际Main无旧世界/入口，只保留三页帐篷。
- 六个实际地图的每个实体建筑均有正HP、与敌人名册分离；六个实际导演使用公共战斗底座、可配置第二轮；十种异区角色骨骼和血条可加载；正式压板为80HP、0.5秒预警、20伤害、1.5秒冷却且非敌人。只读帐篷使用唯一缺失文件路径，退出后主/备/tmp均未创建。

## 不算通过的内容与剩余门槛

- EXE本身`--headless --quit-after 1200`短启动外层实际exit0，但其外部脚本参数没有产生专项PASS；`endless-e1-packed-resources-v1.log`只有引擎头。只登记启动观察，不把它充作224项验证或成品玩法证明。
- 原版导出EXE的完整输入/自然转场、完整两轮实际战斗链、密集异区混编性能、最终同源冻结全量仍待；当前PCK资源可加载不代表这些已经完成。
- 没有真人全通关、OS输入或长时间性能结论。旧F11真人操作反馈仍仅适用于当时候选。
