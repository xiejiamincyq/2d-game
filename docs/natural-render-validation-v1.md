# 原生自然整局图像采集：五景有效，六景未验收

2026-10-04。分支`5分钟超载`；完全取消网页端使用，Codex依据实际代码与画面自行判断。不发布。

## 实测与失败保留

| 原生运行 | 终点/战斗步 | 原始图像 | 严格结论 |
| --- | --- | --- | --- |
| natural-render-08-v1，修前 | 自然胜利/9362 | 六景180张 | 3221条SCRIPT ERROR，外部检查拒绝；不是绿色基线 |
| natural-render-08-v2，生命周期修后 | 自然胜利/8351 | 五景150张 | 日志、存档、时间/图像/源绑定通过；缺重叠预警，六景检查拒绝 |

初始全局RNG20260908，实际地图种子由报告记录，不声称重复轨迹或同条件前后对照。正常输入pilot、生产六波/Boss/真实伤害和顿帧、首结算C继续、最终R重开；不锁血、不改敌人/伤害、不跳波。实际Windows Vulkan Forward+，RTX5060 Laptop GPU，1280×720，60物理Hz，max-fps60，无fixed-fps/MovieMaker；此GPU读回工具有诊断内存和时序开销，不用作性能或最低硬件结论。

原始帧在frame_post_draw后读回，每至少4物理帧取样，记录实际wall/process_frame/physics_frame。最多180张RGBA图像缓存在运行结束后才PNG压缩，约633MiB上限；生产游戏无此开销。早期同步PNG冒烟只采到19帧，失败范围保留；改为延迟编码后的冒烟才有30帧开场，未冒称六景。

## 实际看图发现的问题（不批准视觉完成）

根代理已实际查看v2五景的015原帧，以及商店000/001、Boss000/029；另看v1围堵/重叠/Boss015，只作失败场景诊断，不计有效验收。

- 正常开场可见实体玩家、枪与手附近连接、Q版敌人、农场障碍和明显轮廓；不是回到45°3D或独立旋转枪方案。
- 继续游戏后商店000/001被标题弹窗遮挡。源代码确认：恢复settlement分支没有隐藏标题，SETTLEMENT转换也未隐藏。键盘pilot仍能操作背后的商店，所以此前状态/存档测试不足以证明可见界面正确。下一片增加真实恢复UI回归后最小修复。
- Boss000/015/029均近乎全白，持续激光受击反馈掩盖了Q版角色细节；需单独验证持续受击的闪白覆盖，不以单帧命中白闪当正常常驻表现。
- 瞄准环、脚下条、护盾/技能和落点线仍混有旧青蓝/品红霓虹语汇；与当前薄荷奶油、深青轮廓、珊瑚危险色未完全统一。
- 商店触发后30帧包含正常继续到第二波的变化，并非30帧商店停留。当前工具不能作为商店连续可读性验收，后续仅调整诊断输入的正常等待时长，不冻结生产状态或改卡牌/玩法。

角色四向、完整连续运动、危险重叠、修复前后严格同条件六景和人工手感均仍待验。没有声称新独立代理复跑；本轮逐项自审不替代最终独立审查。

## 自动门与复现

Godot条件选择先红后绿5断言；Python元数据检查先红后绿8测试，包含真假覆盖、六景起始条件、实际预警圆相交、单调时间/帧、安全路径、真实渲染和静态重复帧拒绝。原生外部检查不只相信工具valid，还检查原始日志、自然过程报告、真实存档哈希不变、PNG尺寸/非平面/哈希和当前源SHA。

完整当前门59 Godot套件166432断言、28 Python套件178测试通过；自然六景仍失败，不能靠单元回归替代。

```powershell
godot_console --path . --audio-driver Dummy --max-fps 60 --resolution 1280x720 --script res://scripts/art/VerifyNaturalRunRendered.gd -- --seed=20260908 --run=fresh-id --steps=36000 --clock=realtime
python -B scripts/art/check_natural_render.py build/diagnostics/natural-run/captures-fresh-id.json --report build/diagnostics/natural-run/fresh-id.json --log fresh-id.log --require-six
```

必须保留终端原始输出到fresh-id.log；每次使用未存在ID，原工具拒绝覆盖。检查不带require-six只能核验如实部分覆盖，不能称六景批准。检查绑定采集时源码；后续Main/视觉修复自然会使旧记录的当前源检查失效，不回填原报告，依据归档的源快照/对应Git版本审阅或重新录制。

证据包：[natural-render-evidence-v1.zip](natural-render-evidence-v1.zip)，13906132字节、78条目，SHA256 `ff91c2cd9077676fccc5c97538ec1135c5ae6f2fec6b4f8d6c12c016d1eb3bda`。包含v2每景000/015/029共15张未编辑原PNG，五条覆盖全部150帧的有损MP4预览，完整manifest/自然报告/原日志、v1失败日志与报告/manifest、录制红绿和门日志、v2绑定源码/资源快照。MP4统一名义15fps、每条30帧约2秒，仅用于浏览；真实节奏以manifest逐帧时间为准，不当作恒定15fps采样证据。

全部330张原PNG仍保留本地build；另保留v2完整150张原PNG归档`build/diagnostics/natural-render/full-capture-v2.zip`，84975915字节、SHA256 `171fb3da9af7ba3cf878caa8d362a4ef02c86f89f0359e5e5dc569b8c3515330`，不把85MB完整诊断包写入Git。较小证据包并不包含全部原PNG，不能声称仅凭Git包可重做150张逐图哈希检查；该检查已针对原本地文件执行。S2—S5整体均未完成。
