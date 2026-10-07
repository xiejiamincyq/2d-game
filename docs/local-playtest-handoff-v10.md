# v10-r2 试玩交接（本机，不发布）

2026-10-07，分支`5分钟超载`，最终生产提交`57ba76388df06f2735f06a2cf0759c097d6b6715`。直接双击`build/playtest/5分钟超载-current-v10-r2/five-minute-overdrive.exe`，同目录PCK必须保留。不需要Godot编辑器，可复制整个目录。旧v9保留；初版v10拒绝交付，不能混用其PCK。EXE/PCK不随Git下载，也未公开发布。

## 用户五项要求

- 全部敌人现有基础伤害×3，包括Boss、敌弹、范围攻击；友方伤害与通用Player接收器不变。
- 准心奶白内芯加纯黑外描边，端点和两侧都保留黑边，瞄准中心不变。
- 追击者新增锁向扇形爪击与短程扑击，保留普通近战和群体绕行；无伤预警、单次命中、侧移可躲、实体碰撞不穿墙。
- 雷网矩阵电弧间隔×1.50，普通电弧不变；升级和连杀超载继续正常组合，恢复存档不会累乘。
- 当前卡牌、开始/暂停提示、旧存档展示与[完整玩法说明](gameplay-guide-v10.md)同步；旧证据保留，不篡改历史。

[机制与失败修复记录](combat-feedback-review-v2.md)、[准心局部验收](aim-reticle-outline-review-v1.md)记录红绿测试和独立审查。交付前真实Player测试发现初稿扑击在16.9px玩家碰撞体外停住而不扣血：已读取实际半径，命中/预警共用接触范围；真实100→76且不穿玩家。不是只测试没有碰撞的假目标。最终复审Critical0/Required0。

## 最终源验证

最终完整严格门`full-v5`退出0：83 Godot套件174036断言、35 Python套件269测试。原有20项脏资源hash不变，未混入本轮提交；正式六存档仍为原状态。

最终预注册自然运行`gameplay-feedback-20261007-v10-v3`，seed20260909、map_seed2573397633。Windows/Vulkan/RTX5060原生、真实Input、正常生命/升级/地图规则，最终退出0、胜利、621击杀、HP116.06（本局购买了生命升级）、游戏计时164.63秒，含截图保存和验证的总墙钟238.03秒。正常结果R重开验证通过；不是跨OS继续或普通EXE整局证明。原生v1/v2保留，只因文案纠错及真实碰撞修补重新登记源，不筛选有利seed或隐藏死亡结果。

10512个运动样本，10511对相邻位置中10491对实际位移超过0.001px；145次随机换向、5次脱困是策略计数，不当作运动证据。原生运行绑定196生产输入，运行中无源改变、三路无脚本/引擎错误或泄漏、报告/画面/收集检查均退出0、正式存档不变。

开场、怪群、冲刺、Boss、结算各连续采集30帧，收集窗口62帧。实际查看最终源怪群中扑击预警、Boss画面及最终EXE标题；它们不是人工逐帧验收。最终自然流程未满足overlap捕捉条件，**不称六景齐全**，也不以此证明全部随机拥挤组合。使用Dummy音频，不能代签听感或无读回性能。

## 最终包验证

Fresh副本与最终自然登记/当前工作树的196生产输入逐hash一致。原有export preset不变，诊断和测试资源仍排除；复制本机已安装4.7 Windows x64两份模板到隔离APPDATA，不下载、不复制设置/凭据/存档。import/export/native-title均退出0，无错误或泄漏。

实际release EXE原生标题以Movie Maker三帧启动退出，1280×720图非空并已查看；这只验证EXE启动，不是EXE整局或实时帧率验收。随后以`--main-pack`实际加载新PCK，外部测试夹具驱动包内生产资源：

| 实际PCK套件 | 断言 |
| --- | ---: |
| EnemyDamageMultiplier | 63 |
| ThunderMatrixInterval | 112 |
| ScrapperAttack（含真实玩家） | 21 |
| AimReticleOutline | 8 |
| GameplayDescriptions | 36 |
| GrenadeVelocity | 73 |
| EnemyFlock | 33 |
| 合计 | 346 |

七套均退出0、无错误/泄漏。原有榴弹30%移动继承与基础飞速+20%、群体协作保留；不是把工作树测试误当包内测试。

| 文件 | 字节 | SHA256 |
| --- | ---: | --- |
| five-minute-overdrive.exe | 109019648 | b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0 |
| five-minute-overdrive.pck | 3018608 | 203d60696476b48765e61f6526bc8190477129811f71d737a4b527aa2d6476af |

EXE引擎和v9同hash正常，玩法更新在PCK。构建含原有未提交资源，不称干净HEAD克隆可复现。[机器摘要](local-playtest-handoff-v10.json)含196源hash、实际终态、门与包信息。原始日志/图在本机ignored `build/diagnostics/gameplay-feedback-v2` 和 `build/diagnostics/natural-run/captures-gameplay-feedback-20261007-v10-v3`。

GitHub最初两次500，第三次推送已成功；最终提交与远程同步另以Git检查。环境draft、声音精确来源/许可、人工平衡与听感、最低硬件及普通EXE整局仍分别待验；本次不启动旧18/36/20恢复/压力/地图矩阵，不继承旧数值作当前证明。
