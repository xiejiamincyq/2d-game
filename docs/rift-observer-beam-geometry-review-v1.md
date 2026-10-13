# R4b1锁定窄束几何：专项通过，时钟与普通输入躲避未完成

按[实施前契约](rift-observer-beam-contract-v1.md)增加RiftObserverBeam RefCounted，未改祭司攻击或接入第六入口。实际360px胶囊/半径8/基础12×3=36；与绘制读取同一origin/tip/radius，没有独立timer/process、追踪或动画伤害事件。

## 真实执行

缺primitive语义RED actualexit1（058239）。首版74专项actualexit0（ecc3ef）；随后增加端帽、隐身与大有限方向边界，其中超大方向Vector2(1e30,0)实际语义RED exit1（ce60a1），定位为length溢出导致normalized归零。仅入口方向先除最大分量再规范化，不放宽断言或改玩家。最终86断言/唯一TEST PASS、无错误/泄漏actualexit0（a0b8d7）；正常import actualexit0并生成两UID（d802dc）。测试已注册正式runner。

受控Emitter是实际CharacterBody2D/Health组件而非可玩的BossActor；使用真实生产Player和16.9px身体，圆体侧界24.8命中/25.0不命中、前后圆端帽、水平/镜像/竖直/斜向以及两帧高速穿越。Player正常maxHP100，站立扣到64；单轮最多一次尝试，无敌拒绝不补扣。live Health回调中人为取消无敌并重入resolve仍只能扣一次；terminal死亡重入会取消authority，不能要求死亡取消后attempted仍true——制作前分开两个回调用例，避免互相冲突的测试契约。

实际物理默认layer1和QUERY_LAYER的2px薄墙均阻挡；后插墙取消，普通动态角色不冒充地形，标记动态地形阻挡，32触点饱和拒绝。未入场/OwnerHP0/死亡、目标隐身/死亡、暂停、越界、无效方向/origin/sweep、重复cancel、释放Owner的authority检查通过。invalid从/to取消而非保持旧伤害权限。几何每次调用重验context，尚未做导演即时Owner信号清理，不能据此签所有生命周期已完整接入。

## 尚未通过的门

这不是自然攻击时钟、正常输入躲避、原生挂点发射GPU、完整观测者AI/阶段、真实Boss胜利或第六进度。没有给测试玩家加速/增大血量/无敌来获得普通试玩通过，也没有任何通关存档。下一R4b2唯一导演时钟与正常235/16.9玩家反应0.15秒、30/60/120Hz站立受伤/横移躲避对照；随后b3真实骨挂点/墙边/受控GPU及包。

R4a资源包是加入本primitive以前的历史资源证明，不声称包含新beam代码。本切片未跑新的整Boss全量/独立PCK；整R4仍未完成，Ready1–5不变，F1–F4未完成，整体goal active。无中间commit/push/发布，也未发送R4阶段完成邮件。
