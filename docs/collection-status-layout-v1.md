# 底部收集状态布局修复（2026-10-04）

分支 `5分钟超载`，生产基线 `39dfb0783d12f8eac901982171cdec91a28d164d`。用户取消网页端，由工作区自行判断，不发布。本片只修改 HUD 布局与诊断工具；保留已批准的 2D 薄荷奶油色、深青轮廓、字体、收集时序、透明淡出和战斗规则。

## 根因与最小修复

实际字体将收集卡片撑到60px，旧固定坐标仅预留58px。1280×720实际收集框 `(450,602,380,60)` 与超载条 `(485,658,310,44)` 重叠4px。真实 GameUI 新红测在旧 HUD 上退出1，不是缺API或解析错误。

HUD 将原两个控件挂入同一个 VBox，按实际最小尺寸排布，间隔8px；仍居中，超载条保持距视口底边18px。修后收集框 `(450,590,380,60)`，超载条完全不移。最小尺寸变更更新容器上沿，不逐帧轮询；状态、进度条、隐藏/恢复仍由原 HUD 管理。

## 验证与独立审查

- 最终 `CombatStatusLayoutTest` 1092断言，五尺寸（原四种+800×600两列）、十二状态，覆盖所有实际可见面板/字体、位置稳定、完整消息、收集3秒参数及0.2秒淡出值、标题同步隐藏/恢复。
- 最终完整门 `build/diagnostics/collection-layout/full-gate-collection-v2.log`：62 Godot套件168937断言、28 Python套件178测试，退出0。之前v1也是通过，但最终引用v2；不将断言数量当作确定性轨迹证明。
- 原生 Vulkan Forward+，四尺寸1280×720/960×540/1920×1080/2560×1080，各四固定状态、首绘制/稳定各一张。修前 `collection-before-v1` 32PNG、最终修后 `collection-after-v2` 32PNG；各采集前冻结13项选定来源并绑定SHA。只读外部检查核对全部64PNG尺寸/非单色/SHA、冻结来源、修后当前来源、字体最小尺寸、倒计时/淡出、居中/底边距及所有面板两两AABB：修前32对重叠，修后0对，间隔-4→8px。
- 审查发现公共采集器误设60%充能，改变旧四状态夹具；已恢复公共工具0%，60%只在收集子工具。另跑 `status-collection-compat-v1` 四旧状态32PNG，12项来源绑定/几何检查通过，全部保留“超载 0%”。`collection-after-v1` 留作审查前历史来源，不冒称最终来源。
- 外部检查初次误写活动文本为“超载就绪”，真实生产文本是“超载运行”；按实际既有合同纠正检查器后通过，未改生产文案。独立审查只读代码/图/证据，不代签另一台机器Godot复跑或人工手感。

修前/修后底部固定状态语义一致，但公共/子工具与测试来源有上述后续修订，各保留自己的精确快照。背景随机纹理未像素配对，不宣称整图零差异。实际看过960×540收集修前/修后，以及最终全部提示并存首帧，底部留有间隔；几何核验不等于逐帧人工视认。

## 范围限制与证据包

组件没有Main、自然输入、真实存档、性能测量；“Boss+模块+收集并存”是故意构造状态，不冒称自然流程。3秒/0.2秒只是固定状态合同，尚未验证自然清波后的完整3秒连续动画。本片没有新增自然整局，旧 `combat-status-natural-09-v1` 是39dfb07时的历史证据，不能冒称这次最终源码。S3整体、友方技能语义、后期拥挤对照、20实际随机地图、来源/本地交付仍待完成。

[紧凑证据包](collection-status-layout-evidence-v1.zip)：63项、9,185,806字节；SHA256 `1e8998723c5e8072ab840aa24af7ec83f50d95baf0c2f48e19f653bce701c107`。创建后CRC、唯一项及每项与本地来源字节全部一致。

包含三份完整组件manifest和各13/13/12项冻结来源、原红测/最终完整门/原生日志/外部结果与检查打包脚本，以及每尺寸一张修前/修后收集稳定图（共8张）。64张收集图和32张兼容图均保留本地，包仅选8张，不可离线对全部96PNG直接复验；来源内另有地板PNG，不算捕获图。不是可运行游戏或发行包。所有原生采集与全量门串行退出后再开始下一次，不作帧率改善结论。

本地复核（必须保留未打包的原图；从项目根运行）：

```powershell
python -B -X utf8 build/diagnostics/collection-layout/check_collection_evidence.py build/diagnostics/collection-layout/collection-before-v1 before
python -B -X utf8 build/diagnostics/collection-layout/check_collection_evidence.py build/diagnostics/collection-layout/collection-after-v2 after
python -B -X utf8 build/diagnostics/combat-status/check_status_evidence.py build/diagnostics/combat-status/status-collection-compat-v1 after
```

原生重放需设置全新 `COMBAT_STATUS_RUN_ID`，执行 `godot_console --path . --audio-driver Dummy --max-fps 60 --script scripts/art/VerifyCollectionStatusLayout.gd`。不得覆盖既有目录；60FPS是上限，不是性能保证。
