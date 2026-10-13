# R4a：观测者原生动作资源已验证，真实Boss战未完成

只验收资源和薄播放适配器，不勾整阶段R4，不开放第六，不把受控采样当AI/伤害/通关或真人试玩。整体goal active。资源manifest仍draft；无新位图、下载、购买、安装或付费作品提取。

## 实际产出与动作

独立原创v2场景、外置库、授权checkpoint、Bake作者脚本、NativeRiftObserverMotion及三规范测试。30 Bone2D；保留已原创原生v1五个基础片段，新增beam/probes/refract各warning/attack/recovery共九个。不是沿用改造前贴图。旧v1场景08fe69c6543d1e691256b800cc3b5a8560e84fa751d02d40852456099be6cbe8及库0525621d5092253b121f524e74982267c77227af6ef908a3bc2b303e286ac4ba未覆盖。旧名册覆盖/审查银行不变，Gate只增observer一项。

beam有虹膜合/张、瞳孔/镜片回弹与三足缓冲；probes双臂、肘与探针独立且先左后右；refract六环片交错三次有限峰值，固定环轴而非整身360旋转。片段只是视觉候选，不能据此签真实攻击可躲避。适配器只读combat时间，不推进另一攻击时钟，不发伤害，不移动物理根；入场、普通步行/受击、取消与死亡不复活。

## RED、修复和真实终态

缺新资源、缺授权、缺适配器的语义RED保留。资源初次1387 GREEN；原稿同时在25%时点检查双探针与“先左后右”规格不符，制作前改成左18%/右46%，保留各伸出>12px与独立肘限制，不在GREEN后降低条件。

实际GPU首轮exit1（a4ac30）发现probes超出声明视觉框：原16px余量之外最远7.30px。保留失败日志/图/报告。新增框回归实际RED exit1（092063），按实测23.30+1.70余量设25px，Bake和新v2一致；不改skin/rest/模型scale/轨道/碰撞半径，不影响旧v1。修复后资源1388 actualexit0（a3f58e）。死亡姿态不用于活体视觉包围框，但仍检查无视口边缘裁切。

正常import actualexit0并生成七GD UID。规范专项实际17授权、17旧祭司授权、44共有Gate、1388资源、33适配器均exit0（f66887），三新测试已注册runner。

实际NVIDIA OpenGL GPU673检查/168姿态 actualexit0（47d7cb），非死亡框外0、主体半透明0、视口边缘0；三活动各30连续帧，均27/29邻帧像素变化。真实骨挂点跨度：AimOrigin14.43px、双SensorOrigin39.31/43.34px、PhaseOrigin10.17px。1280×720同帧以Player生产scale1.3/Boss scale1渲染，不偷偷放大模型；三个动作小尺度主体无半透明/边缘裁切。

双镜像姿态、连续关键帧、小尺度四张GPU PNG均已逐张实际查看。明确是无地图/伤害的受控原生模型采样，不是Boss战视频。四PNG及report五件从原输出逐SHA复制：[右姿态](previews/campaign/rift-observer-actions-v1/action-poses.png)、[左姿态](previews/campaign/rift-observer-actions-v1/action-poses-left.png)、[连续关键帧](previews/campaign/rift-observer-actions-v1/action-keyframes.png)、[原尺度](previews/campaign/rift-observer-actions-v1/gameplay-scale.png)、[机器报告](previews/campaign/rift-observer-actions-v1/report.json)。report e33bb482e9971bc4097086f9d9882e63f002b074329127e913753bf505c3ee1e。

## 独立包边界

当前PCK7,074,376字节/SHA256493e5c49aa08397b1c9f4c126d5f32300724ab33a76cfea9d4979ea31e34ffe9。无--path外部规范资源夹具359、适配器33、已有生产名册644共1036断言，加Main120 actualexit0（89b48b）。三复制夹具逐SHA一致，作者脚本与docs不可从包加载；26受测源前后不变。release actualexit0（503862），同字节预算合格/Main120。不是所有Boss专项或当前全量回归，不能把R3历史292套件结果冒称本轮新资源全量；R4e整阶段完成才full、综合包和一次邮件。

未创建真实观测者Actor/三招伤害/阶段/第六保存，不修改Ready列表、真实用户存档或现有试玩候选。R4b下一步只做锁定窄光束和实际物理，R4c双落点/R4d分批碎片后R4e才组装真实Boss。F1–F4仍未完成。无中间提交/推送/发布，本切片不发整阶段完成邮件。
