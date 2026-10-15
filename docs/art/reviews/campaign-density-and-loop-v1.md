# 地图密度与轮次界面定向审查

沿用已选纸片/玩具风格，仅调整原生地图实体排布、界面文字；没有新栅格资源、付费素材或风格锁定，没有修改资产注册表审批。完整开发进度见`docs/campaign-endless-upgrade-progress-v1.md`，本记录不是最终成品验收。

- 密度GPU：`build/diagnostics/campaign-goal/density-gpu-v2`，默认Vulkan Forward+，actualexit0/PASS56。seed521前后总览为1280×1440拼图，另有四张1280×720原比例视野。当前四图建筑26–28/26–28/22/32；第一/二/三关分别增加植床、工位遮挡、堤道侧闸，第四关书架贴墙角，避免浮动窄缝。第五布局不改。总览只看结构层次，不冒充真实游戏相机比例；正常输入绕行另有独立测试。
- 第二轮UI：`build/diagnostics/campaign-goal/loop-gpu-v3`，actualexit0/PASS73；真实隔离ChapterRun的第1/4关介绍，以及显式第6关结算组件状态，960×540和1280×720六张均已查看。轮次、生命倍率和下一轮/重玩说明可读，所需按钮未出屏。结算预览不冒称击杀Boss或完成两轮。
- 历史失败保留：loop-gpu-v1传入未类型化空数组导致SCRIPT ERROR，虽有exit0/PASS也明确不合格；v2布局检查73通过，但第四关部分字形未完整显示。采样改为等待16个真实draw帧，v3两尺寸字形完整，未改生产字体或用文案删减掩盖。该观察支持采样时机问题，不证明最终EXE自然首帧没有问题，终验需检查真实转场。
- 两组报告记录源码与像素SHA、渲染参数，并在运行内保护默认Campaign/Journey主/备/tmp。loop-v3生成后已逐一匹配SHA；随后仅把碎体/孵化HP初始化前移到入树之前，未改变本审查的介绍/结算调用路径与图形。最终冻结同源包仍需重新建立完整适用证据。
- v1遗留两份明确归属该进程的84字节GPU测试旅程，在读取内容、解析绝对目标并核对stage11/coins37/空继承后删除；正式存档、失败图和日志保留。它们仅是可重建测试夹具，不是用户进度。

## 第五、六关踩踏压板接入后的自然混战

- `build/diagnostics/campaign-goal/echo_step_runtime_gpu_v1`（actualexit0/PASS1881）与`rift_step_runtime_gpu_v1`（actualexit0/PASS2048），默认Vulkan Forward+/RTX5060Laptop、1280×720。来源银行已包含正式ReusableStepTrap/ReusableTrapField，不再把旧周期EchoBeat/RiftFault误列作本次陷阱来源。
- 16张图已逐张查看：压板橙色细圈在紫/蓝地面上可辨；奶油色小感叹号有暗色描边，普通怪血条不依赖受伤才显示；身体不整层透明，锁定切线和碎片收敛，没有大面积闪光遮住移动区。诊断标题不是正式HUD。本次不改风格、贴图、碰撞或注册表。
- 实际普通移动/瞄准/射击及自然攻击时钟；暂停保持现有压板阶段、计时、HP和归属，恢复继续而非重置。两份报告的全部source/capture SHA均重新匹配。它们不证明完整清场、Boss胜利、完整两轮、最终EXE、OS/真人输入或密集性能。
