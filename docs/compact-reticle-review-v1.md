# 小型空心准星：减少敌人遮挡

2026-10-04，`5分钟超载`，基线`8bd73d09c59cfd81f4af1a45ecb81e34342390a6`。用户已取消网页端；由工作区自行判断，不发布。沿用纯2D Q版B清爽玩具/薄荷农场/C明显轮廓，无新位图、无素材许可证状态提升。

## 问题和改动边界

旧准星是56×56px控制区，两圈青蓝/品红环、四根长臂和中心实心点。真实战斗会把普通敌人几乎完全盖住，也盖住Boss脸部；旧UITest要求至少48px，保护了这种有问题的表现。

仅改`AimReticle.gd`的绘制：24×24px控制区，四根从距中心5px到9px的短臂，4px深青轮廓`#123b3b`、2px奶油色`#f3eddc`；取消大环、中心点和装饰脉动。原生实际可见边界20×20px。不是把系统鼠标或射击目标改到别处。

仍逐帧读取同一viewport鼠标坐标、以控制区一半居中；`MOUSE_FILTER_IGNORE`、无键盘焦点、active显隐/处理启停、GameUI系统指针显隐、Main状态机和所有武器/移动/伤害/碰撞完全不改。美术管线用于配色和实际尺寸检查，未以换图为由修改机制。

## 测试与真正渲染

- 先修订UITest的旧大尺寸要求为20—24px并保留鼠标穿透；旧生产代码真实失败，`red.log`退出1，原因是准星遮挡尺寸，不是资源导入或解析错误。修后`green.log`通过88断言，新增无焦点、hidden不处理和五个屏幕点居中检查。
- StateTest通过42断言，新增真实Main的START、PLAYING、Boss入场、清场、商店、暂停、恢复和结果画面显隐/处理检查。它明确调用正式状态入口，是组件状态测试，不冒称自然人类操作。
- 复用VerifyUIArt的原生采集；修前/后各24原PNG，四个原生viewport：960×540、1280×720、1920×1080、2560×1080；每个viewport以实际冻结Scrapper/Boss和空地为目标，分别hidden/visible，全部PNG与各JSON SHA相符。Boss显式推进1.41秒入场，无Main、存档或自然战斗。两次Vulkan Forward+ / RTX5060 Laptop GPU进程退出0、原日志零错误/泄漏、orphan0。
- 外部Pillow逐像素比较每个visible和同底图hidden：旧准星改变1796—1804个像素、半径3px中心圆全部29像素被盖住；新准星改变144像素、中心0像素改变，可见bbox20×20。约减少92%的绘制覆盖，不是“角色可见率提升92%”。12组修前/后hidden底图逐像素完全相同，变化不是角色、地板或HUD重绘造成。原图未进行后期编辑。
- Pixel检查要求新准星中心29像素全部不变、32—160个改变像素、bbox限于鼠标点±12px，并核对全部48PNG及当前after绑定源码SHA。原始结果在`build/diagnostics/aim-reticle/pixel-check.log`；这是本次外部核验，不是headless UITest能检测中心空心的声明。
- 根代理实际看1280×720修前/后Scrapper、修后Boss和960×540空地原帧：角色主体显露，空地准星仍有明暗双层对比。其他尺寸由像素/尺寸检查覆盖，不代签用户手感。

## 自然整局、完整回归与独立审查

`compact-reticle-natural-09-v1`已自然六波/Boss胜利，9707有效战斗步、585击杀、最低HP86、最终HP100；初始RNG20260909、实际地图种子2573397633。原生Vulkan/max-fps60，无fixed-fps或MovieMaker，正式pilot输入/攻击、首结算C恢复与最终R重开，六个真实存档路径哈希不变、orphan0，原日志零错误/泄漏。

只有opening/crowd/dash/boss/shop各30帧、共150原PNG；`missing=[overlap]`。外部严格检查原日志、源SHA、采集图像、时间/起始条件：partial检查退出0，`--require-six`真实退出1且保留拒绝日志。不能称六景通过；同初始RNG与上次Boss修复运行的战斗轨迹不同，也不称自然逐帧前后配对。

根代理实际看opening/crowd/dash的015、shop的000及Boss的015/029共六张原帧，确认小准星在战斗显示、商店首帧不显示、主体不再被大圈覆盖。Boss仍部分藏在顶部HUD下面，玩家激光/技能/战斗爆裂仍用旧霓虹语汇；这些不在本片生产改动中，不勾选整体验收。商店30帧会随正常流程转入第二波，不是持续商店停留。五条MP4各30帧、1280×720，名义15fps有损预览，实际采样时间以manifest为准，未声称完整连续影片已人工观看或性能通过。

完整回归进程退出0：60 Godot套件166700断言、28 Python套件178测试；原日志保留。独立只读五轴审查已核对生产绘制、输入未改、组件图/哈希、自然五景及最终文档边界，结论Approve本片、无Required/Critical，不冒称独立重新运行Godot。可选建议是静态线形日后评估取消每帧queue_redraw；本片不在采集后回改源码。

采集器新增实际准星屏幕坐标/visible记录，并把AimReticle/GameUI源码SHA纳入manifest和自然报告；只有补录后的新记录受该绑定保护，不回填旧证据。

## 证据和复现

证据包[compact-reticle-evidence-v1.zip](compact-reticle-evidence-v1.zip)：53671967字节、138条目，SHA256 `f2b6fdb87202d3243ddadf44eba9768b3aa6dc58d4708ec1a1a69c83e5207c3d`。包含全部48组件原PNG/两JSON、修前/后绑定源与测试、红绿/渲染/像素/完整门/自然及六景拒绝原日志、完整自然报告与manifest、15张自然精选原图、覆盖150采样帧的五条有损MP4。关闭归档后重新核对122项绑定原图/源SHA，全部一致；另135自然原PNG保留本地build，不能只凭Git包重做全部150张原PNG哈希检查。没有删除任何旧证据。

原生24+24组件PNG保存在`build/diagnostics/ui-art-v3/reticle-{before,after}-v1-*`；每次输出启动前预检全部24PNG及JSON，拒绝覆盖残留文件。

```powershell
godot_console --headless --audio-driver Dummy --path . --script res://scripts/tests/UITest.gd --quit-after 120
godot_console --headless --audio-driver Dummy --path . --script res://scripts/tests/StateTest.gd --quit-after 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1 -Group all
godot_console --path . --audio-driver Dummy --max-fps 60 --resolution 1280x720 --script res://scripts/art/VerifyUIArt.gd -- --run=reticle-after-v1
```

已有采集ID不可再次使用；当前源码不会自动回退旧准星或覆盖旧图。重拍组件需在确认新的未用输出ID后扩展受控ID列表，不能把当前帧冒称修前。自然采集可直接用新的`--run=fresh-id`，照原严格check_natural_render调用验证，不忽略缺景。

此片不修改或验收落点预警、SpikeTrap、FlameTrail、ArcPulseVisual等仍沿用霓虹表现的技能。源码确认地上十二根品红放射线/青蓝端点来自玩家SpikeTrap，不是敌人Lobber落点；后续应分别表示友方技能和敌方危险。S2—S5整体、四向/连续/前后六景、最低硬件、人类手感和素材许可证依然待验。
