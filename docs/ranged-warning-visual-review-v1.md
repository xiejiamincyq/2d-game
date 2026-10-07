# 远程危险提示视觉小片 v1

沿用已批准的纯2D Q版、薄荷实验农场、C加粗轮廓，不重选风格，不改位图、许可证或final状态。Pixabay候选音效来源仍按[音效记录](audio/overdrive-bone-breaking-source-v1.md)保留needs_review。

## 改动与边界

- 普通敌方Projectile采用深青圆形轮廓、实体色与小奶油高光；只有target_group为player进入此绘制分支。狙击/旧Enemy.OVERSEER改珊瑚，喷吐保留酸绿语义、换用批准色值。
- 共享友方默认、普通矩形绘制和超载拖尾代码原样保留；独立BossProjectile自己的菱形绘制覆盖不变。旧Enemy.OVERSEER不是当前最终Boss。
- LOB蓄力提示移除中心填色，瞄准线止于72px落点边界，不穿玩家中心；边界采用5px深青/3px珊瑚与48段抗锯齿。飞行/爆炸沿用上一片。
- 不改半径3/5、物理形状、伤害、速度、射程、锁点、时序、冷却、命中或存档逻辑。视觉轮廓多1.5px不扩大碰撞箱。没有新玩法、外部模型监督或公开发布。

## 验证

配色回归先真实失败：Marksman旧亮青色，退出1；生产改动后HostileEffectPaletteTest实际32断言、退出0，验证三个真实生产者及友方默认。已有EnemyProjectileRadiusTest继续验证碰撞/28弹/变换父出生点。第一次完整门禁终端记录69 Godot套件170079断言、31 Python套件235测试；最终全流保存日志为69 Godot套件170078断言、31 Python套件235测试，均实际退出0。逐套件pass标记齐全，两次计数分别记录，不由旧计数相加或覆盖成同一数值。

原生Vulkan固定组件前后v2，实际Enemy/Player/Floor和三个弹体生产者，1280×720，四个独立640×360子世界、原尺寸显示。四向玩家32×32中心区域：旧idle→windup每向1024像素改变，新每向0；友方21×21弹体ROI逐像素一致，三个敌方ROI改变；记录的固定位置/目标/蓄力剩余/时长/HP与1、1、1、12发射数前后相同。这只是所列固定姿态的像素证据，不证明全部像素、持续动画、密集场景或人工可读性验收。

before来自3b7cf19的实际工作树runtime复制，1203文件116268368字节，含原有用户未提交资源，不是clean HEAD；采集helper随后复制入副本，不改变生产Enemy/Projectile。首版before/after helper均因无类型数组取元素的kind推断错误而解析失败，日志保留，不计通过；v2明确int后均退出0、无错误/泄漏。工具Pillow getdata弃用警告保留，未导致像素检查失败。

第一次完整门禁实际通过且终端输出保留，但PowerShell Write-Host未进入原Tee-Object文件：封包因此在ZIP创建前以FileNotFoundError停止，未提交空或伪造日志。交接文档修改后，改用全流重定向保存最终门禁原日志再封包；旧终端通过与新日志计数分开记录。

启动包装进程/引擎PID须区分：before native launcher17108、report engine35244；after launcher39720、engine22712。WinGet入口下不假定两者相同。原launcher五项选定源SHA不含新Palette；本片证据包另收录实际Palette源码及后续导出输入清单，不能将补录说成原先已观测hash。

独立审查实际跑32断言、查看前后四张PNG、重算四向core与友方ROI、核对固定状态和选定源/日志/六存档，Critical0/Required0。其当时证据范围不包括自然整局、完整门禁独立复跑或独立EXE。

## 仍未验收

S2—S5整体、全部效果与密集视觉、人类手感、实际声音、所有作品派生链/许可证、最低目标硬件、独立EXE从开始至Boss/胜败/恢复的完整实际操作均不自动勾选。自然流程与更新本地包的实际结果补列于本片末节；旧包与失败原始记录保留。

## 自然流程与本地交付

`ranged-natural-v1-20261007-09`沿用原随机Input驾驶与避障、真实Main/UI/首结算C/商店/六波/Boss/胜败R流程，单09种子8835战斗步自然胜利、119随机换向/6脱困尝试；引擎PID19008、实际退出0，报告checker通过，17选定源SHA与六真实存档前后不变。观察器精确get_script==Projectile排除Boss派生，不改变演员状态；17个被观察的普通敌弹实例，颜色与配置物理半径不一致观察0。不称所有发射弹或所有敌人家族均覆盖。

观察器在符合实体/视窗状态时选择acid/coral/lob-windup三张原生PNG，最多三张RAM回读，流程终止后编码；实际看过原图。只用于自然战斗场景留档：没有记录选中弹体屏幕坐标或独立逐弹像素身份，因此不将截图名称当作该弹体已清晰可见的证明，也不证明完整运动/动画、全部遮挡或可读性通过。观测开销存在，不计为性能基线。

更新Windows包见[交接v4](local-playtest-handoff-v4.md)：190过滤输入hash匹配、隔离副本import/export退出0，新保留目录EXE标题headless/native两次实际退出0/六存档不变，1280×720标题原图已看。是本机交付，不是EXE整局或公开发布。

## 证据归档

[技术证据ZIP](ranged-warning-visual-evidence-v1.zip)：49成员（48数据+index），5045367字节，SHA256 `1422d7f7bb1f2df487ec57fbbd782cb0dcfe9c77ac6c404e6e741f3d2eeaff9d`。包含实际生产源码、before源码与输入manifest、组件前后6PNG/状态/launcher、首版失败日志、红绿/最终完整门禁日志、自然原始报告/观察/3PNG、新包输入清单/标题日志/1PNG和交接receipt；不含EXE/PCK或完整素材目录。CRC、成员闭合、逐项字节数/hash已检查。不是整局EXE或所有资产验收包。
