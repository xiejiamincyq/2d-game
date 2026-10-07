# 当前源码本机冻结包 v7

2026-10-07，基线c5987af。网页已取消；只重建并验证本机Windows候选，不新增素材/玩法，不提升许可状态，不公开发布。

- fresh独立源码目录：`build/diagnostics/local-delivery/export-current-v7/source`；新包：`build/playtest/5分钟超载-current-v7/`。所有输出拒绝覆盖，旧v6与更旧包保留。
- 复制当前project/export及assets/scenes/scripts/themes，不复制.godot缓存。记录全部复制项及preset过滤的190生产输入；相对v6只允许Enemy修复差异，副本/当前工作树前后逐hash核对。含原有未提交资源，不称干净HEAD。
- 现行完整源码回归已于上一片实际退出0：73Godot173366断言、34Python250测试。复核代码/测试输入未变后复用，不为相同源码再跑同一全门；本片另验fresh import/export实际退出码与engine/stdout/stderr、无错误/泄漏。
- 实际保留的release EXE使用正常Main，无--script/--path/MovieMaker/秘籍/修改PCK；只为子进程覆盖APPDATA、1280×720、日志路径，音频默认，不修改正式存档。预登记两次运行：`exe-c5987af-pause-v1`开局/移动或冲刺/Space暂停/正常关窗；`exe-c5987af-death-v1`正常开局/自然死亡/R回标题/正常关窗。自动普通窗口输入，不代签人类手感或声音听感。
- 游戏窗口操作仅使用已配置Computer Use的窗口绑定API，并实际观察唯一属于新包的窗口，不控制其他应用。每次输入后重新观察；平台限制/锁屏/权限提示立即停止，不能用自制输入协议绕过。
- 所有会写存档的测试/原生局串行；检查六正式存档与原20脏文件前后不变、包二进制前后hash不变。无效测量/超时/日志错误保留，不更换有利结果或冒称整个EXE通关。
- 核验后更新直接运行路径、v7交接/已知限制/摘要与精选本地证据；独立只读审查、聚焦提交推送当前分支、Gmail一次。不将本片当S3—S5整体或全项目完成；完整EXE胜利/退出续存等仍按实际证据分列。
