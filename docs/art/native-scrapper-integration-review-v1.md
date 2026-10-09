# 普通怪原生骨骼真实接入 v1

2026-10-09；第一个普通怪完成基础接入，不代表全敌族/所有动画/六关或真人验收。

## 现在实际发生的变化

`EnemyKind.SCRAPPER`默认实例化可编辑`rootling_paper_v3.tscn`，移除该类型的旧PNG依赖，其他敌族暂时保留过渡贴图。真实Main/WaveDirector/传送门正常生成的普通怪已使用十二骨/原生加权皮肤，不是只在技术样板里展示。

`NativeScrapperMotion`只读取现有Enemy和ScrapperAttack状态，动画手动采样，不增加第二个攻击时钟。待机/走路连续取样，短预警按实际0.22/0.30秒归一化，主动攻击和恢复分别映射到新attack动作的70%/30%；近身普通攻击也跟随现有attack_timer。受击新骨骼反作用在非攻击状态播放，密集命中不会每帧重新启动；攻击状态以可辨攻击姿态优先，仍有原来的轻量颜色闪白，不允许纯视觉去取消或重复命中。

取消/隐身/无目标/出生冲量不留下攻击姿态，资源内部实验用“!”隐藏，只显示Enemy自己的短头顶提示。叶冠比旧贴图更高：血条顶-66、底-60，预警另在血条上方；不改变14px碰撞或攻击范围。原生身体在父绘制后方，血条/预警在身体上方，地面招式仍走独立z=-1层。

死亡仍立即结算、发一次died和queue_free战斗实体；只把纯视觉骨骼保留在原父节点，原位置开始0.42秒死亡动作后释放。残影不在enemies组、不带碰撞/血条/伤害，明确PAUSABLE，不在暂停菜单中偷偷完成。

## 本轮发现并修复

- 原玩家遮挡轮廓组件只识别Sprite2D，新骨骼小怪在前方时丢失轮廓。先补RED测试，再统一`get_visual_node/get_visual_rect`接口：原生rest网格边界一次计算、加4px保守动作余量；Sprite2D继续用原get_rect。范围不是逐像素遮挡证据，也不是物理碰撞。相关实际渲染诊断一起更新，避免伪造空Sprite2D或旧接口看似通过。
- 受击闪白只在部分物理分支消退，隐身/无目标提前返回会卡住。专项RED复现后，将同一80ms视觉计时更新移到共同入口；不改伤害、AI、运动和碰撞。
- 初轮脚本类型/名称错误修复后再测试，不记作首次即成功。第一轮全量运行时增加了验证脚本，UID尚未重新导入，严格门捕获缺失侧车；保留失败日志，停止添加脚本后重新导入并跑第二轮全量。

## 权威证据

- EnemyNativeIntegrationTest：40断言，真实Enemy资源、权威claw/pounce阶段映射、取消、受击、隐身、暂停、死亡清理、血条/挂点和原平衡；PlayerOcclusionOutlineTest：20断言；旧ScrapperAttack命中专项和其他角色测试仍保留。旧贴图测试仅将已迁移Scrapper交给新专项，并未删除伤害/碰撞要求。
- [实际Main截图](previews/campaign/native-scrapper-main-v1.png)、[连续画面](previews/campaign/native-scrapper-main-v1.mp4)、[逐帧资源/状态报告](previews/campaign/native-scrapper-main-v1.json)：正常输入pilot600物理步，玩家相邻位置变化599次，击杀15只；60张GPU帧、59次相邻像素变化，实际骨骼姿态记录walk1062/idle18/hit32。没有自定义生成敌人、无敌、直接摆姿态、缩短关卡或穿墙通关；使用隔离诊断存档，真实存档哈希未变、退出时孤儿节点1→0。
- 上述短测结束于step_budget，不是胜利；只得到opening/crowd片段，没有dash/overlap/Boss/shop全流程。视频以每4物理帧采样的名义15fps编码；不是PresentMon/性能测量或真人手感确认。
- [GPU实际身体着色器透明报告](previews/campaign/native-scrapper-opacity-v1.json)：从真实Enemy创建并保留其Skin材质，六动作各0/0.5/1相位×正常/0.35闪白，共36采样，均>1000完全不透明像素、0半透明、无触边裁切。不是每一连续姿态的全面证明。
- 第二轮完整回归退出0：97 Godot套件176340断言、35 Python套件270测试；实际PCK检查3,086,316字节、Main120帧退出0无错误/泄漏。日志`build/diagnostics/campaign-goal/native-scrapper-full-green-v2.log`及`native-scrapper-release-v1.log`；首轮UID失败保留于`native-scrapper-full-v1.log`。
- 基础接入提交`a47dc72`已推送；本地新增`build/playtest/v14-native-rootling-v1/five-minute-overdrive.exe`（109,019,648字节）及配套PCK（3,086,316字节）。实际EXE无头启动120帧退出0，无错误/泄漏，日志`native-scrapper-exe-smoke-v14-v1.log`。EXE启动检查只证明启动，不把它冒充EXE内正常输入试玩；上述正常输入/GPU证据来自同源Main。旧v13未覆盖，候选未发布。

## 审查与下一步

本轮只推进一个普通怪，未新做大型/Boss攻击、未改变血量/攻击伤害/鱼群AI/地形碰撞，也没有动真实保存系统。五轴自审：视觉映射独立小组件而非继续塞进大Enemy；无第三方库/外部资源/凭据；诊断采样有60帧/16演员上限，视觉边界不每帧重建。高密度全Main性能、普通怪专属招式美术打磨、玩家/其他敌族及大型全部骨骼继续属于后续验收，不能拿以前技术样板256只计时给本轮完整游戏签性能结论。

自主营造方向已通过，原生资源状态保持style-approved，不提升final或全游戏gameplay-approved。下一步开始页/关卡选择和首关闭环；动作质量与密集预算继续随M3扩族升级。仍没有六独立Boss、永久解锁UI或新菜单，旧v13试玩保留、不公开发布。
