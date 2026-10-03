# 薄荷农场界面统一：本片实测

日期：2026-10-04。工作分支 `5分钟超载`，基线 `26d86af`。按用户最新指令由工作区判断，未使用网页端。延续已选 B 清爽玩具/B 薄荷农场/C 明显轮廓，不改变玩法。

## 改动与自审

- `MintFarmTheme.tres` 统一奶油不透明面板、薄荷按钮、3px 深青描边、圆角和独立键盘焦点圈；保留中文系统字体回退。旧 `CyberTheme.tres` 留存，不清理历史资源。
- HUD、标题/继续、暂停、结算卡、结果页、波次提示、Boss 血条/入场提示换色。超载从青色充能切至珊瑚色运行，有文字及描边状态，不只靠颜色。动态面板为局部资源，不修改共享主题。
- 按钮信号、焦点链、暂停归属、交易状态、布局安全尺寸、Boss 阈值和时间未改。标题副文案去掉与当前六波不符的“五个阶段”，改为“清剿所有波次”；游戏名不变。
- 自审生产 diff 仅样式、颜色和这一处文案；没有改移动、碰撞、AI、生命、伤害、存档。未进行额外独立最终审查，不冒称独立验收。

## 红绿与完整回归

先修改 `UITest` 的既定新色合同：真实红测退出1，旧超载紫色不满足珊瑚色合同。首轮主题通过78断言后，新增 Boss 数字对比度测试真实失败：深青 `#123b3b` 在珊瑚 `#f27a4b` 上约4.468:1。数字单独加深至 `#102f2f` 后约5.213:1；**没有降低4.5:1阈值**。

最终 `UITest` 82断言通过；覆盖实际面板底色、默认/悬停/按下/禁用文字、升级分类标题、Boss数字两种底色、焦点圈、超载复位与共享资源隔离。`SettlementUITest` 39断言通过，仍验证六卡、快捷键、免费/付费状态与焦点。

完整预推送：55 Godot套件166287断言，26 Python套件158测试通过；资源导入、暂停所有权、秘密扫描、工作区/暂存区空白检查通过。数字是该次运行结果，不承诺实时套件每次断言总数相同。

## 原样渲染

独立工具 `scripts/art/VerifyUIArt.gd` 使用真正 `GameUI + FloorGrid`，1280×720、960×540，分别显示标题、HUD、超载、六卡结算、暂停、结果、Boss七种状态。修前/最终修后各14张原始PNG及源码SHA JSON；Vulkan Forward+ / RTX5060 Laptop GPU，退出0，拥有节点释放、孤儿节点0。

本地已看图：小窗口六卡/禁用卡文字、暂停、结果均在画面内；新面板与农场地面同色系，焦点双圈不遮字。Boss数字仍沿用原11px/34px布局，音乐滑块沿用默认浅色抓手；这些不是“全界面可访问性认证”，后续仍可精修。

- [修前960结算](mint-ui-before-shop-v1.png)
- [最终960结算](mint-ui-after-shop-v1.png)
- [当前真实战斗HUD](mint-ui-natural-wave1-v1.png)
- [全部原图/JSON/红绿日志/短测证据](mint-ui-evidence-v1.zip)

证据包 SHA256：`21d69718285d6f930c9af9f7adac3a7291c61efd4a28c8447ed58d277fa253de`，8708038字节。

边界：组件状态由夹具显式提供，商品可购标记并非真实经济计算，不是自然商店/存档流程验收。最初 `ui-art` 夹具误用 family 字段，六卡未显示，发现后补id与六卡断言并重新采修前；首批图不纳入证据。有效修前来自 `ui-art-v2/before`，最终修后来自 `ui-art-v3/after`，夹具仅输出目录不同；中间 Boss 对比度失败的 `v2/after` 不冒称最终。before/after标签不自动重建旧生产版本，JSON绑定当时源码。

## 当前真实运行短测

复用已校验的输入采样器：`ui-mint-natural-smoke-v1`，种子20260908，R轨/普通步行，独立进程自然Enter、未跳过入场、600物理步、正常伤害，600步预算结束（不是死亡或清场）。墙钟10.065123秒，模拟9.8416667秒；结束生命57、9击杀/32存活/0待生成，41总量守恒。第360步原样截图35存活、6击杀、86生命。

60/180/360步有实时PNG；600步只留终点冻结后截图，不能冒称实时600步图。离线检查 `valid=true`；源文件SHA前后不变，6个真实存档/备份/临时路径前后均absent且相同，诊断写入独立子目录。拥有树释放，孤儿1→0，退出日志无错误/泄漏。墙钟比例是算术证据，不是最低硬件帧时或平衡验收。

```powershell
godot_console --path . --audio-driver Dummy --script res://scripts/art/VerifyUIArt.gd -- --run=after
powershell -ExecutionPolicy Bypass -File scripts/tests/prepush.ps1
C:\ProgramData\miniconda3\python.exe scripts/art/run_movement_repeatability_matrix.py --godot C:\Users\21604\AppData\Local\Microsoft\WinGet\Links\godot_console.exe --batch ui-mint-natural-smoke-v1 --smoke --scenario natural_wave1 --smoke-track R --smoke-mode walk --steps 600
```

现有证据名不可覆盖，重跑需新批次/输出目录。诊断PNG/ZIP无图像后期修改。本片没有生成或改动角色位图，没有改变任何素材许可状态。

S3仅此子项完成：仍缺弹幕/触手配色、同条件六景与连续运动证据；S2后期自然窗口/LOBber、S4完整局/地图/继续、S5来源/性能/冻结交付未完成。人工手感、最低硬件、许可证缺口仍单列，不发布。
