# 第五关正式流程：阶段验收完成

2026-10-11，`5分钟超载`。第五真实流程E5阶段验收已完成，Ready1–5，第六仍制作中禁入。资源draft/整体goal active；本阶段不是整个六关目标完成。进展/失败详情见[集成记录](../echo-fifth-integration-progress-v1.md)。

## 交互与技术底层

EchoChapter只继承公共ChapterRun并绑定实际EchoField，原生钟祭实例由实际第五遭遇导演持有；Main无第五特例。两必经混合战、实际奖励/构筑、补给或四钟风险、真实首领、成功写保存后才提示解锁6。尚未制作6不能启动；活Boss伪死、场景退出、重复/错误通关均不能保存。保存失败保持旧SHA、显示重试，真正重试后才显示通关；重玩改种子/重置局内但保留永久进度，死亡/战中返回帐篷不写假通关。

受控EchoBossEncounterTest122、EchoChapterTest144、EchoChapterLaunchTest19与旧Echo328/317/2196已退出0通过；原未绑定Boss、缺场景、未开放入口三个语义RED保留。这些加速致死夹具只证明归属和保存，不能冒称实际游玩通关。UID来自正常Godot导入，没有手工捏造。

## 普通输入胜利与恢复

修后实际GPU v2两局都从真实Main点击第五入口，正常UI选奖励和路线、指针瞄准、WASD/开火/冲刺，真实Boss血量10800→0。仅在开始前创建隔离前四关先决存档；不改玩家速度、无敌、血量或武器伤害，不直接扣Boss血、不注入局中金币或奖励。共用驱动的击杀下限是实际种子敌人债务+真实Boss，不沿用其他关硬定30的错误假设，其他关默认不变。

| v2路线 | 实际检查 | 位移 | 射击 | 实际击杀 | 玩家生命/保存 |
|---|---:|---:|---:|---:|---|
| 补给 | 15989 | 7898 | 2635 | 28 | 100；真正5通关保存 |
| 风险 | 15420 | 7603 | 2897 | 54 | 100→85→67→拾取恢复87；真正5通关保存 |

两报告各47生产/驱动源SHA，随后又起各自新引擎进程，实际Main只读恢复各11检查：1–5已清、6已解锁未清/仍不可启动，没有7或六关完成；SHA未重写。不是OS桌面输入或人类试玩，不证明长期难度。两局实际观察Health阶段I–III、双坠和冠钟，没有观察钟槌，钟槌由E4b独立正常位移/站立对照覆盖，不夸大整局三招覆盖。

## 视觉问题、修复与交付

v1虽然两路线程序胜利/恢复通过，看实际补给frame014却发现BOSS方向牌遮脸，未作为最终当前证据。受控复现首次夹具未等入场，null/SCRIPT ERROR不算RED；修夹具后red-v2真实147个身体相交失败。修复在HUD安全边缘固定21候选中避开投影身体+8px留白，从新位置指向真实Boss。可选第三参数保持原二参接口，根/碰撞/相机缩放/玩家数值均未改；BossCameraFramingTest1862仍绿。

方向牌GPU v1几何绿但尚是入场骨骼，视觉拒收；修夹具刷新真实Motion并断言idle后v2实际2290/752可见样本/12源SHA。逐一看完九张三分辨率/三距离图，低分辨率远Boss不强制全身同框，但提示仍在安全区且不挡身体。只证明受控取景，不替代实际路线。

本轮实际查看补给11张：三个intro与frame003/005/011/012/013/014/015/016；风险九张：三个intro与frame013/015/016/018/019/020；加九方向牌共29张。可见两族不同轮廓/常驻血条、较密的风险队伍、实际免费构筑/金币和风险文字、PhaseII/III、完整通关/制作中提示。方向牌在风险frame018已避开Boss头部。只签已看范围，不声称每帧混战、零所有遮挡或真人满意。

交付[补给](previews/campaign/echo-chapter-flow-v2/supply/report.json)22文件、[风险](previews/campaign/echo-chapter-flow-v2/risk/report.json)26文件、[方向牌](previews/campaign/echo-indicator-occlusion-v2/report.json)10文件，共53PNG与五JSON、58文件逐SHA一致。PNG/源/存档SHA实际核对，Godot生成的PNG.import不当作制作交付；旧图/失败日志/旧A5候选保留。素材为项目原创原生资源与实际画面，不新增收费/下载/位图生成。

## 最终工程验收与自审

59源checkpoint为`build/diagnostics/campaign-goal/echo-chapter-source-checkpoint-v1.json`，只是源冻结，不是完成结果。独立PCK实际退出0：53专项/32168断言、Main120；包6817476字节，SHA256 `3b95b30b411398737ce824039662cf609e9697ec9bf57141fd1062f0a6b0f4d7`。不带--path的包外规范夹具加载真实包，55规范GD/支持文件逐SHA一致，56实际日志无错误/泄漏；另外315权重/骨骼/挂点/资源隔离检查通过，同包前后SHA不变。release实际退出0，Windows PCK6817476字节/Main120，不是公开发布。六个冻结名册/旧A5候选/Bell v1哈希保持。所有本项目引擎操作串行，未动真实用户保存。

最终全量`echo-chapter-final-full-v1.log`唯一PASS：281 Godot套件261848断言、36 Python套件272测试。恢复实际命令记录exec-f1ac912d-d97d-4cf6-8211-d5c56bb5970e，completed/实际退出0，明确FULL_ACTUAL_TERMINAL_EXIT=0和POST_FULL_SOURCE_PASS=59；不是仅见日志就假定退出。日志SHA256 `3c742afb86a6ab3094fc26531d31a0790ee654bdc61efbb1db3bb25624899cc3`，随后再核59源全部未变。

新本机候选为`build/playtest/5分钟超载-native-e5-v1/five-minute-overdrive.exe`，EXE109019648字节、PCK6817476。首次重新导出的整包哈希与独立包不同，保留失败记录与`export-original.pck`；574条目录逐内容MD5比较，仅Godot生成的global_script_class_cache.cfg与uid_cache.bin不同，其余572条一致。没有改资源以迎合哈希；精确复制已通过53专项的game.pck为候选相邻five-minute-overdrive.pck，SHA与上述3b95包一致。实际从候选目录执行EXE，不带--path/--main-pack，Main120帧退出0，无错误/泄漏。旧A5未覆盖；不是GUI试玩或人类手感验收。

阶段完成结果`build/diagnostics/campaign-goal/echo-chapter-complete-v1.json`记录59源、58交付SHA、六冻结项、实际进程回执和各门。导入/导出均串行，未触碰真实存档。

底层：用公共协调/所有权与两薄关卡文件，少量区域策略，不复制Main和持久化实现。视觉：真实看图发现后修，原生骨骼解释招式、短头标和有限小投射物；构筑玩家子弹数量多属于最终高密度表现另验。性能：方向牌每帧21固定候选，漂移/群体AI等最终性能门仍未签。安全/许可：无新依赖、凭证、安装、外部作品、公开发布，旧未核定音效许可不因原创角色而转为已批准。全目标未完成，不做中间提交/推送。

仅勾E5阶段，完成通知一次Gmail另记下方；随后按[第六关规格](../rift-sixth-chapter-spec-v1.md)推进。六关连续解锁、长期构筑与重玩激励、密集性能、菜单/全文字、许可与人类手感是独立总门。

E5完成邮件已通过连接Gmail发给`me`，实际message id `1a12a02908194be3`。只通知第五阶段，不是整体完成邮件，不重复发送旧阶段邮件。
